// Testes das Firestore Security Rules do Planly (T-012).
// Fonte: docs/specs/security-rules.md Â§8 (seed fixo, 50 negacoes N01..N50, 15 positivos P01..P15)
// e docs/specs/data-model.md Â§8. Rode via `firebase emulators:exec` (ver README da task T-012).
import { test, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  doc,
  collection,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  limit,
  writeBatch,
  serverTimestamp,
  Timestamp,
  arrayUnion,
} from 'firebase/firestore';

const HOST = '127.0.0.1';
const PORT = Number(process.env.FIRESTORE_EMULATOR_HOST?.split(':')[1] ?? 8181);

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-planly-rules',
    firestore: {
      host: HOST,
      port: PORT,
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------
const H1 = 'families/F1/households/H1';
const H2 = 'families/F1/households/H2';
const H3 = 'families/F2/households/H3';
const H4 = 'families/F2/households/H4'; // extra (nao esta no spec): casa de F2 sem acesso p/ U1 (N09/N10)

// ---------------------------------------------------------------------------
// Builders de documentos (c = clock: serverTimestamp() no cliente, Timestamp.now() no seed)
// ---------------------------------------------------------------------------
const ts = () => serverTimestamp();

const taskDoc = (by, o = {}, c = ts) => ({
  title: 'Tarefa',
  description: '',
  createdBy: by,
  assignedTo: by,
  status: 'pending',
  schedule: null,
  recurrence: null,
  notification: { enabled: false, offsetMinutes: 0 },
  completedAt: null,
  completedBy: null,
  deletedAt: null,
  createdAt: c(),
  updatedAt: c(),
  schemaVersion: 1,
  ...o,
});

const listDoc = (by, o = {}, c = ts) => ({
  name: 'Lista',
  type: 'shopping',
  createdBy: by,
  deletedAt: null,
  createdAt: c(),
  updatedAt: c(),
  schemaVersion: 1,
  ...o,
});

const itemDoc = (by, o = {}, c = ts) => ({
  name: 'Item',
  completed: false,
  completedBy: null,
  completedAt: null,
  createdBy: by,
  order: 1,
  deletedAt: null,
  createdAt: c(),
  updatedAt: c(),
  schemaVersion: 1,
  ...o,
});

const activityDoc = (actor, o = {}, c = ts) => ({
  type: 'task_created',
  actorId: actor,
  actorName: 'Fulano',
  targetType: 'task',
  targetId: 'tX',
  targetTitle: 'Tarefa',
  createdAt: c(),
  schemaVersion: 1,
  ...o,
});

const userDoc = (name, c) => ({
  displayName: name,
  email: `${name.toLowerCase()}@example.test`,
  photoUrl: null,
  locale: 'pt-BR',
  timezone: 'America/Sao_Paulo',
  freeFamilyId: null,
  deletedAt: null,
  createdAt: c(),
  updatedAt: c(),
  schemaVersion: 1,
});

const familyDoc = (owner, status, c) => ({
  name: 'Familia',
  ownerId: owner,
  status,
  plan: 'family',
  memberCount: 3,
  householdCount: 2,
  frozenAt: null,
  deleteAfter: null,
  pendingTransfer: null,
  deletedAt: null,
  createdAt: c(),
  updatedAt: c(),
  schemaVersion: 1,
});

const memberDoc = (role, status, c) => ({
  role,
  status,
  displayName: 'Membro',
  photoUrl: null,
  joinedAt: c(),
  invitedBy: null,
  createdAt: c(),
  updatedAt: c(),
});

const householdDocSeed = (name, access, c) => ({
  name,
  access,
  accessUids: Object.keys(access),
  createdBy: 'U1',
  deletedAt: null,
  createdAt: c(),
  updatedAt: c(),
  schemaVersion: 1,
});

// ---------------------------------------------------------------------------
// Seed (spec Â§8): F1 (owner U1; U2, U3), F2 (owner U4; U1 member), H1 {U2:member,U3:admin},
// H2 {}, H3 {U1:member}, U9 sem vinculo. H4 (F2, access {}) e extra.
// ---------------------------------------------------------------------------
async function seed(familyStatus = 'active') {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const c = () => Timestamp.now();
    const S = (path, data) => setDoc(doc(db, path), data);

    for (const n of ['U1', 'U2', 'U3', 'U4', 'U9']) await S(`users/${n}`, userDoc(n, c));
    await S('users/U1/memberships/F1', { familyName: 'Familia', role: 'owner' });
    await S('users/U1/memberships/F2', { familyName: 'Familia', role: 'member' });
    await S('users/U2/memberships/F1', { familyName: 'Familia', role: 'member' });
    await S('users/U2/devices/dev1', {
      fcmToken: 'tok',
      platform: 'android',
      lastSeenAt: c(),
      createdAt: c(),
    });
    await S('users/U3/devices/dev3', {
      fcmToken: 'tok',
      platform: 'android',
      lastSeenAt: c(),
      createdAt: c(),
    });

    await S('families/F1', familyDoc('U1', familyStatus, c));
    await S('families/F1/members/U1', memberDoc('owner', 'active', c));
    await S('families/F1/members/U2', memberDoc('member', 'active', c));
    await S('families/F1/members/U3', memberDoc('member', 'active', c));
    await S('families/F1/billing/subscription', { provider: 'google_play', state: 'active' });
    await S('families/F1/billing/entitlement', { plan: 'family', maxMembers: 4 });
    await S('families/F2', familyDoc('U4', 'active', c));
    await S('families/F2/members/U4', memberDoc('owner', 'active', c));
    await S('families/F2/members/U1', memberDoc('member', 'active', c));
    await S('families/F2/billing/entitlement', { plan: 'family', maxMembers: 4 });

    await S(H1, householdDocSeed('Casa 1', { U2: 'member', U3: 'admin' }, c));
    await S(H2, householdDocSeed('Casa 2', {}, c));
    await S(H3, householdDocSeed('Casa 3', { U1: 'member' }, c));
    await S(H4, householdDocSeed('Casa 4', {}, c));

    // H1 conteudo
    await S(`${H1}/tasks/tU2`, taskDoc('U2', {}, c));
    await S(`${H1}/tasks/tU2b`, taskDoc('U2', {}, c));
    await S(`${H1}/tasks/tU3`, taskDoc('U3', {}, c));
    await S(`${H1}/tasks/tNull`, taskDoc('U3', { assignedTo: null }, c));
    await S(`${H1}/tasks/tDel`, taskDoc('U2', { deletedAt: Timestamp.now() }, c));
    await S(`${H1}/lists/lU3`, listDoc('U3', {}, c));
    await S(`${H1}/lists/lU2`, listDoc('U2', {}, c));
    await S(`${H1}/lists/lU3/items/iU3`, itemDoc('U3', {}, c));
    await S(`${H1}/lists/lU3/items/iDel`, itemDoc('U2', { deletedAt: Timestamp.now() }, c));
    await S(`${H1}/activity/a1`, activityDoc('U2', {}, c));
    // H2
    await S(`${H2}/tasks/t2`, taskDoc('U1', {}, c));
    await S(`${H2}/lists/l2`, listDoc('U1', {}, c));
    await S(`${H2}/lists/l2/items/i2`, itemDoc('U1', {}, c));
    await S(`${H2}/activity/a2`, activityDoc('U1', {}, c));
    // F2
    await S(`${H3}/tasks/tH3`, taskDoc('U4', { assignedTo: null }, c));
    await S(`${H4}/tasks/tH4`, taskDoc('U4', {}, c));

    await S('invitations/INV1', { familyId: 'F1', createdBy: 'U1', status: 'pending' });
    await S('invitations/INV2', { familyId: 'F2', createdBy: 'U4', status: 'pending' });
  });
}

// Altera o status da familia F1 fora das Rules (simula a Function).
async function setFamily1Status(status) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'families/F1'), { status });
  });
}

beforeEach(async () => {
  await seed('active');
});

const as = (u) => env.authenticatedContext(u).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const D = (db, path) => doc(db, path);
const col = (db, path) => collection(db, path);
const lim = (db, path, n = 10) => query(collection(db, path), limit(n));
const ts0 = () => Timestamp.fromDate(new Date('2020-01-01T00:00:00Z'));
const tsFuture = () => Timestamp.fromDate(new Date('2099-01-01T00:00:00Z'));

// ===========================================================================
// 8.1 NEGACOES
// ===========================================================================

// --- Autenticacao / vinculo ---
test('N01 nao autenticado nao le users, families, tasks, invitations', async () => {
  const db = anon();
  await assertFails(getDoc(D(db, 'users/U1')));
  await assertFails(getDoc(D(db, 'families/F1')));
  await assertFails(getDoc(D(db, `${H1}/tasks/tU2`)));
  await assertFails(getDocs(lim(db, `${H1}/tasks`)));
  await assertFails(getDoc(D(db, 'invitations/INV1')));
  await assertFails(getDocs(query(col(db, 'invitations'), where('createdBy', '==', 'U1'))));
});

test('N02 nao autenticado nao cria/edita nenhum doc', async () => {
  const db = anon();
  await assertFails(setDoc(D(db, `${H1}/tasks/new`), taskDoc('U2')));
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU2`), { title: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(db, 'users/U1'), { displayName: 'x', updatedAt: ts() }));
  await assertFails(setDoc(D(db, 'users/U1/devices/d'), { fcmToken: 't', platform: 'android' }));
  await assertFails(updateDoc(D(db, 'families/F1'), { name: 'x', updatedAt: ts() }));
});

test('N03 U9 (sem vinculo) nao le families/F1, members, entitlement, households/H1', async () => {
  const db = as('U9');
  await assertFails(getDoc(D(db, 'families/F1')));
  await assertFails(getDoc(D(db, 'families/F1/members/U2')));
  await assertFails(getDocs(col(db, 'families/F1/members')));
  await assertFails(getDoc(D(db, 'families/F1/billing/entitlement')));
  await assertFails(getDoc(D(db, 'families/F1/billing/subscription')));
  await assertFails(getDoc(D(db, H1)));
});

test('N04 U9 nao le/escreve tasks, lists, items, activity de H1', async () => {
  const db = as('U9');
  await assertFails(getDoc(D(db, `${H1}/tasks/tU2`)));
  await assertFails(getDoc(D(db, `${H1}/lists/lU3`)));
  await assertFails(getDoc(D(db, `${H1}/lists/lU3/items/iU3`)));
  await assertFails(getDoc(D(db, `${H1}/activity/a1`)));
  await assertFails(setDoc(D(db, `${H1}/tasks/n`), taskDoc('U9')));
  await assertFails(setDoc(D(db, `${H1}/lists/n`), listDoc('U9')));
  await assertFails(setDoc(D(db, `${H1}/lists/lU3/items/n`), itemDoc('U9')));
  await assertFails(setDoc(D(db, `${H1}/activity/n`), activityDoc('U9')));
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU2`), { title: 'x', updatedAt: ts() }));
});

test('N05 U9 query sem filtro em tasks de H1 falha', async () => {
  const db = as('U9');
  await assertFails(getDocs(col(db, `${H1}/tasks`)));
  await assertFails(getDocs(lim(db, `${H1}/tasks`)));
});

test('N06 usuario nao le/escreve users/U2 (perfil de outro)', async () => {
  const db = as('U1');
  await assertFails(getDoc(D(db, 'users/U2')));
  await assertFails(updateDoc(D(db, 'users/U2'), { displayName: 'x', updatedAt: ts() }));
  await assertFails(setDoc(D(db, 'users/U2'), userDoc('U2', ts)));
});

test('N07 nao le memberships/devices de outro uid; nao escreve devices de outro', async () => {
  const db = as('U1');
  await assertFails(getDocs(col(db, 'users/U2/memberships')));
  await assertFails(getDoc(D(db, 'users/U2/memberships/F1')));
  await assertFails(getDocs(col(db, 'users/U2/devices')));
  await assertFails(getDoc(D(db, 'users/U2/devices/dev1')));
  await assertFails(
    setDoc(D(db, 'users/U2/devices/devX'), {
      fcmToken: 't',
      platform: 'android',
      lastSeenAt: ts(),
      createdAt: ts(),
    }),
  );
  await assertFails(deleteDoc(D(db, 'users/U2/devices/dev1')));
});

// --- Acesso cruzado ---
test('N08 U2 (member F1) nao le families/F2, members de F2, households/H3', async () => {
  const db = as('U2');
  await assertFails(getDoc(D(db, 'families/F2')));
  await assertFails(getDoc(D(db, 'families/F2/members/U4')));
  await assertFails(getDoc(D(db, H3)));
  await assertFails(getDoc(D(db, `${H3}/tasks/tH3`)));
});

test('N09 U1 (owner F1, member F2 so de H3) nao le outra casa de F2 nem edita F2', async () => {
  const db = as('U1');
  await assertFails(getDoc(D(db, `${H4}/tasks/tH4`)));
  await assertFails(getDocs(lim(db, `${H4}/tasks`)));
  await assertFails(getDoc(D(db, H4)));
  await assertFails(updateDoc(D(db, 'families/F2'), { name: 'x', updatedAt: ts() }));
});

test('N10 papel de owner de F1 nao vaza para F2/H3 (sem admin em H3)', async () => {
  const db = as('U1'); // U1 tem acesso `member` em H3 (seed): leitura OK, poderes de admin/owner negados
  await assertFails(updateDoc(D(db, H3), { name: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(db, `${H3}/tasks/tH3`), { title: 'editado', updatedAt: ts() })); // tarefa de U4, assignedTo null: nao pode editar titulo
  await assertFails(
    updateDoc(D(db, `${H3}/tasks/tH3`), { deletedAt: ts(), updatedAt: ts() }), // soft delete de tarefa alheia
  );
  await assertFails(getDocs(query(col(db, 'families/F2/households'))));
});

test('N11 path e vinculo devem casar ao criar task', async () => {
  // U4 (owner de F2) cria em F1/H1 (sem vinculo a F1)
  await assertFails(setDoc(D(as('U4'), `${H1}/tasks/n`), taskDoc('U4')));
  // U2 (F1) cria em F2/H3 (sem vinculo a F2)
  await assertFails(setDoc(D(as('U2'), `${H3}/tasks/n`), taskDoc('U2')));
  // U1 eh membro de H3 em F2; nao pode criar em casa inexistente/sem acesso de F2
  await assertFails(setDoc(D(as('U1'), `${H4}/tasks/n`), taskDoc('U1')));
});

test('N12 criar task com assignedTo fora de accessUids (U9)', async () => {
  const db = as('U2');
  await assertFails(setDoc(D(db, `${H1}/tasks/n`), taskDoc('U2', { assignedTo: 'U9' })));
  await assertFails(setDoc(D(db, `${H1}/tasks/n`), taskDoc('U2', { assignedTo: 'U4' })));
  // update mudando assignedTo para U9 (autor edita)
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU2`), { assignedTo: 'U9', updatedAt: ts() }));
});

// --- Membro sem acesso a casa ---
test('N13 U2 (C em H2) nao le households/H2 nem queries de conteudo de H2', async () => {
  const db = as('U2');
  await assertFails(getDoc(D(db, H2)));
  await assertFails(getDocs(lim(db, `${H2}/tasks`)));
  await assertFails(getDocs(lim(db, `${H2}/lists`)));
  await assertFails(getDocs(lim(db, `${H2}/lists/l2/items`)));
  await assertFails(getDocs(lim(db, `${H2}/activity`)));
  await assertFails(getDoc(D(db, `${H2}/tasks/t2`)));
});

test('N14 U2 nao cria/edita/soft-deleta task em H2', async () => {
  const db = as('U2');
  await assertFails(setDoc(D(db, `${H2}/tasks/n`), taskDoc('U2')));
  await assertFails(updateDoc(D(db, `${H2}/tasks/t2`), { title: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(db, `${H2}/tasks/t2`), { deletedAt: ts(), updatedAt: ts() }));
});

test('N15 query de households: sem array-contains falha; com array-contains U2 retorna so H1', async () => {
  const db = as('U2');
  await assertFails(getDocs(col(db, 'families/F1/households')));
  const snap = await assertSucceeds(
    getDocs(query(col(db, 'families/F1/households'), where('accessUids', 'array-contains', 'U2'))),
  );
  assert.deepEqual(snap.docs.map((d) => d.id), ['H1']);
});

test('N16 membro removido ainda em accessUids: comportamento documentado (gap conhecido)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'families/F1/members/U3'), { status: 'removed' });
  });
  const db = as('U3');
  // Perde acesso a familia/membros/entitlement (dependem de members.status == 'active')...
  await assertFails(getDoc(D(db, 'families/F1')));
  await assertFails(getDocs(col(db, 'families/F1/members')));
  await assertFails(getDoc(D(db, 'families/F1/billing/entitlement')));
  // ...mas, como as Rules de conteudo checam so accessUids, o acesso ao conteudo persiste
  // ate a Function limpar access/accessUids (data-model Â§8 #3: removeMember atomico).
  await assertSucceeds(getDoc(D(db, `${H1}/tasks/tU2`)));
});

// --- Escalada de papel ---
test('N17 U2 (member) nao vira admin nem se adiciona a accessUids', async () => {
  const db = as('U2');
  await assertFails(updateDoc(D(db, H1), { 'access.U2': 'admin', updatedAt: ts() }));
  await assertFails(updateDoc(D(db, H1), { accessUids: arrayUnion('U9'), updatedAt: ts() }));
  await assertFails(updateDoc(D(db, H1), { access: { U2: 'admin' }, updatedAt: ts() }));
});

test('N18 U2 (member) nao renomeia a casa', async () => {
  await assertFails(updateDoc(D(as('U2'), H1), { name: 'Hack', updatedAt: ts() }));
});

test('N19 U3 (admin da casa) nao edita access/accessUids, nem cria/exclui casa', async () => {
  const db = as('U3');
  await assertFails(updateDoc(D(db, H1), { 'access.U9': 'member', updatedAt: ts() }));
  await assertFails(updateDoc(D(db, H1), { accessUids: arrayUnion('U9'), updatedAt: ts() }));
  await assertFails(
    setDoc(D(db, 'families/F1/households/H9'), householdDocSeed('Nova', { U3: 'admin' }, ts)),
  );
  await assertFails(deleteDoc(D(db, H1)));
  await assertFails(updateDoc(D(db, H1), { deletedAt: ts(), updatedAt: ts() }));
});

test('N20 U2 nao altera members/U2.role nem families/F1.ownerId', async () => {
  const db = as('U2');
  await assertFails(updateDoc(D(db, 'families/F1/members/U2'), { role: 'owner' }));
  await assertFails(updateDoc(D(db, 'families/F1'), { ownerId: 'U2', updatedAt: ts() }));
});

test('N21 U2/U3 nao criam members/{uid} nem memberships', async () => {
  await assertFails(setDoc(D(as('U2'), 'families/F1/members/U9'), memberDoc('member', 'active', ts)));
  await assertFails(setDoc(D(as('U3'), 'families/F1/members/U3x'), memberDoc('owner', 'active', ts)));
  await assertFails(setDoc(D(as('U9'), 'families/F1/members/U9'), memberDoc('member', 'active', ts)));
  await assertFails(setDoc(D(as('U2'), 'users/U2/memberships/F3'), { role: 'owner' }));
  await assertFails(updateDoc(D(as('U2'), 'users/U2/memberships/F1'), { role: 'owner' }));
});

test('N22 nao-owner (U2, U3) nao edita families/F1.name', async () => {
  await assertFails(updateDoc(D(as('U2'), 'families/F1'), { name: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U3'), 'families/F1'), { name: 'x', updatedAt: ts() }));
});

// --- Campos protegidos ---
test('N23 owner nao altera campos protegidos de families/F1', async () => {
  const db = as('U1');
  const bad = {
    status: 'frozen', // 'active' seria no-op (valor igual ao atual nao entra em affectedKeys)
    plan: 'family_plus',
    memberCount: 99,
    householdCount: 99,
    pendingTransfer: { toUid: 'U2' },
    frozenAt: ts(),
    deleteAfter: ts(),
    ownerId: 'U2',
    deletedAt: ts(),
    createdAt: ts(),
    schemaVersion: 2,
  };
  for (const [k, v] of Object.entries(bad)) {
    await assertFails(updateDoc(D(db, 'families/F1'), { [k]: v, updatedAt: ts() }));
    await assertFails(updateDoc(D(db, 'families/F1'), { name: 'ok', [k]: v, updatedAt: ts() }));
  }
});

test('N24 owner nao escreve billing/entitlement nem billing/subscription', async () => {
  const db = as('U1');
  await assertFails(updateDoc(D(db, 'families/F1/billing/entitlement'), { maxMembers: 99 }));
  await assertFails(setDoc(D(db, 'families/F1/billing/entitlement'), { maxMembers: 99 }));
  await assertFails(updateDoc(D(db, 'families/F1/billing/subscription'), { state: 'active' }));
  await assertFails(setDoc(D(db, 'families/F1/billing/subscription'), { state: 'active' }));
  await assertFails(deleteDoc(D(db, 'families/F1/billing/subscription')));
});

test('N25 U1 nao altera users/U1 freeFamilyId, email, createdAt (nem schemaVersion/deletedAt)', async () => {
  const db = as('U1');
  for (const [k, v] of Object.entries({
    freeFamilyId: 'F2',
    email: 'x@y.test',
    createdAt: ts(),
    schemaVersion: 2,
    deletedAt: ts(),
  })) {
    await assertFails(updateDoc(D(db, 'users/U1'), { [k]: v, updatedAt: ts() }));
    await assertFails(updateDoc(D(db, 'users/U1'), { displayName: 'ok', [k]: v, updatedAt: ts() }));
  }
});

test('N26 update de task com createdBy alheio, createdAt alterado ou campo inexistente', async () => {
  const db = as('U2');
  const ref = D(db, `${H1}/tasks/tU2`);
  await assertFails(updateDoc(ref, { createdBy: 'U3', updatedAt: ts() }));
  await assertFails(updateDoc(ref, { createdAt: ts(), updatedAt: ts() }));
  await assertFails(updateDoc(ref, { foo: 'bar', updatedAt: ts() }));
  await assertFails(updateDoc(ref, { schemaVersion: 2, updatedAt: ts() }));
});

test('N27 criar task com createdBy != auth, done pre-preenchido, completedBy alheio, recurrence, schemaVersion 2', async () => {
  const db = as('U2');
  const c = (id, o) => setDoc(D(db, `${H1}/tasks/${id}`), taskDoc('U2', o));
  await assertFails(c('a', { createdBy: 'U3' }));
  await assertFails(c('b', { status: 'done' }));
  await assertFails(c('c', { status: 'done', completedBy: 'U3', completedAt: ts() }));
  await assertFails(c('d', { completedBy: 'U3' }));
  await assertFails(c('e', { recurrence: { type: 'daily' } }));
  await assertFails(c('f', { schemaVersion: 2 }));
  await assertFails(c('g', { deletedAt: ts() }));
  await assertFails(c('h', { extra: 1 }));
});

test('N28 title vazio/201, offsetMinutes string, status archived', async () => {
  const db = as('U2');
  const c = (id, o) => setDoc(D(db, `${H1}/tasks/${id}`), taskDoc('U2', o));
  await assertFails(c('a', { title: '' }));
  await assertFails(c('b', { title: 'x'.repeat(201) }));
  await assertFails(c('c', { notification: { enabled: true, offsetMinutes: '10' } }));
  await assertFails(c('d', { notification: { enabled: true, offsetMinutes: 10081 } }));
  await assertFails(c('e', { status: 'archived' }));
  // updates
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU2`), { title: '', updatedAt: ts() }));
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU2`), { status: 'archived', updatedAt: ts() }));
});

test('N29 update com updatedAt arbitrario (!= request.time)', async () => {
  const db = as('U2');
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU2`), { title: 'x', updatedAt: ts0() }));
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU2`), { title: 'x', updatedAt: tsFuture() }));
  await assertFails(updateDoc(D(as('U1'), 'families/F1'), { name: 'x', updatedAt: ts0() }));
  await assertFails(updateDoc(D(db, 'users/U2'), { displayName: 'x', updatedAt: ts0() }));
});

// --- Congelamento ---
async function assertContentWritesDenied(u) {
  const db = as(u);
  await assertFails(setDoc(D(db, `${H1}/tasks/n_${u}`), taskDoc(u)));
  await assertFails(setDoc(D(db, `${H1}/lists/n_${u}`), listDoc(u)));
  await assertFails(setDoc(D(db, `${H1}/lists/lU3/items/n_${u}`), itemDoc(u)));
}

test('N30 F1 frozen: U2 e U3 nao criam/editam/soft-deletam task, lista, item', async () => {
  await setFamily1Status('frozen');
  await assertContentWritesDenied('U2');
  await assertContentWritesDenied('U3');
  await assertFails(updateDoc(D(as('U2'), `${H1}/tasks/tU2`), { title: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U2'), `${H1}/tasks/tU2`), { deletedAt: ts(), updatedAt: ts() }));
  await assertFails(
    updateDoc(D(as('U2'), `${H1}/tasks/tU2`), {
      status: 'done',
      completedBy: 'U2',
      completedAt: ts(),
      updatedAt: ts(),
    }),
  );
  await assertFails(updateDoc(D(as('U3'), `${H1}/tasks/tU2`), { title: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U3'), `${H1}/tasks/tU2`), { deletedAt: ts(), updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U2'), `${H1}/lists/lU2`), { name: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U3'), `${H1}/lists/lU2`), { deletedAt: ts(), updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U2'), `${H1}/lists/lU3/items/iU3`), { name: 'x', updatedAt: ts() }));
  await assertFails(
    updateDoc(D(as('U3'), `${H1}/lists/lU3/items/iU3`), { deletedAt: ts(), updatedAt: ts() }),
  );
});

test('N31 F1 frozen: owner nao cria/edita task nem renomeia a familia', async () => {
  await setFamily1Status('frozen');
  const db = as('U1');
  await assertFails(setDoc(D(db, `${H1}/tasks/n`), taskDoc('U1')));
  await assertFails(setDoc(D(db, `${H2}/tasks/n`), taskDoc('U1')));
  await assertFails(updateDoc(D(db, `${H2}/tasks/t2`), { title: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(db, 'families/F1'), { name: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(db, H2), { name: 'x', updatedAt: ts() }));
});

test('N32 F1 frozen: nenhum membro cria activity', async () => {
  await setFamily1Status('frozen');
  for (const u of ['U1', 'U2', 'U3']) {
    await assertFails(setDoc(D(as(u), `${H1}/activity/n_${u}`), activityDoc(u)));
  }
});

test('N33 F1 deleting: mesmas escritas negadas', async () => {
  await setFamily1Status('deleting');
  await assertContentWritesDenied('U2');
  await assertContentWritesDenied('U1');
  await assertFails(setDoc(D(as('U2'), `${H1}/activity/n`), activityDoc('U2')));
  await assertFails(updateDoc(D(as('U1'), 'families/F1'), { name: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U2'), `${H1}/tasks/tU2`), { title: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U3'), `${H1}/tasks/tU2`), { deletedAt: ts(), updatedAt: ts() }));
});

// --- Activity ---
test('N34 forjar actorId', async () => {
  await assertFails(setDoc(D(as('U2'), `${H1}/activity/n`), activityDoc('U3')));
});

test('N35 createdAt client-side (passado/futuro)', async () => {
  const db = as('U2');
  await assertFails(setDoc(D(db, `${H1}/activity/n1`), activityDoc('U2', { createdAt: ts0() })));
  await assertFails(setDoc(D(db, `${H1}/activity/n2`), activityDoc('U2', { createdAt: tsFuture() })));
  // tambem em task
  await assertFails(setDoc(D(db, `${H1}/tasks/n3`), taskDoc('U2', { createdAt: ts0() })));
});

test('N36 type invalido, member_joined/left, targetType incoerente', async () => {
  const db = as('U2');
  const a = (id, o) => setDoc(D(db, `${H1}/activity/${id}`), activityDoc('U2', o));
  await assertFails(a('a', { type: 'banana' }));
  await assertFails(a('b', { type: 'member_joined', targetType: 'member' }));
  await assertFails(a('c', { type: 'member_left', targetType: 'member' }));
  await assertFails(a('c2', { type: 'household_created', targetType: 'task' }));
  await assertFails(a('d', { type: 'task_created', targetType: 'list' }));
  await assertFails(a('e', { type: 'item_added', targetType: 'task' }));
  await assertFails(a('f', { type: 'list_created', targetType: 'item' }));
});

test('N37 update e delete de activity negados (inclusive owner e autor)', async () => {
  for (const u of ['U2', 'U3', 'U1']) {
    const db = as(u);
    await assertFails(updateDoc(D(db, `${H1}/activity/a1`), { targetTitle: 'x' }));
    await assertFails(deleteDoc(D(db, `${H1}/activity/a1`)));
  }
});

test('N38 activity com campo extra ou actorName > 200', async () => {
  const db = as('U2');
  await assertFails(setDoc(D(db, `${H1}/activity/n1`), activityDoc('U2', { extra: 1 })));
  await assertFails(setDoc(D(db, `${H1}/activity/n2`), activityDoc('U2', { actorName: 'x'.repeat(201) })));
  await assertFails(setDoc(D(db, `${H1}/activity/n3`), activityDoc('U2', { targetTitle: 'x'.repeat(201) })));
  await assertFails(setDoc(D(db, `${H1}/activity/n4`), activityDoc('U2', { schemaVersion: 2 })));
});

// --- Soft delete ---
test('N39 hard delete de task/lista/item/casa por autor, admin e owner', async () => {
  for (const u of ['U2', 'U3', 'U1']) {
    const db = as(u);
    await assertFails(deleteDoc(D(db, `${H1}/tasks/tU2`)));
    await assertFails(deleteDoc(D(db, `${H1}/lists/lU2`)));
    await assertFails(deleteDoc(D(db, `${H1}/lists/lU3/items/iDel`)));
    await assertFails(deleteDoc(D(db, H1)));
  }
});

test('N40 soft delete invalido: task alheia por member, deletedAt != request.time, com outro campo', async () => {
  const db = as('U2');
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU3`), { deletedAt: ts(), updatedAt: ts() }));
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU2`), { deletedAt: ts0(), updatedAt: ts() }));
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU2`), { deletedAt: tsFuture(), updatedAt: ts() }));
  await assertFails(
    updateDoc(D(db, `${H1}/tasks/tU2`), { deletedAt: ts(), title: 'x', updatedAt: ts() }),
  );
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU2`), { deletedAt: ts() })); // sem updatedAt
});

test('N41 member restaura item soft-deletado (so admin/owner restauram)', async () => {
  // iDel foi criado por U2 (autor), mas restaurar e so para admin da casa/owner
  await assertFails(
    updateDoc(D(as('U2'), `${H1}/lists/lU3/items/iDel`), { deletedAt: null, updatedAt: ts() }),
  );
  await assertFails(updateDoc(D(as('U2'), `${H1}/tasks/tDel`), { deletedAt: null, updatedAt: ts() }));
});

test('N42 update de doc soft-deletado que nao e restauracao', async () => {
  await assertFails(updateDoc(D(as('U2'), `${H1}/tasks/tDel`), { title: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U3'), `${H1}/tasks/tDel`), { title: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U1'), `${H1}/tasks/tDel`), { title: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(as('U3'), `${H1}/lists/lU3/items/iDel`), { name: 'x', updatedAt: ts() }));
  // soft delete duplo (ja deletado)
  await assertFails(updateDoc(D(as('U3'), `${H1}/tasks/tDel`), { deletedAt: ts(), updatedAt: ts() }));
});

// --- Billing / convites / devices ---
test('N43 member (U2) nao le billing/subscription', async () => {
  await assertFails(getDoc(D(as('U2'), 'families/F1/billing/subscription')));
  await assertFails(getDoc(D(as('U3'), 'families/F1/billing/subscription')));
});

test('N44 U9 nao le billing/entitlement', async () => {
  await assertFails(getDoc(D(as('U9'), 'families/F1/billing/entitlement')));
});

test('N45 convites: U2 nao le convite de U1; list sem where falha; owner de F2 nao le convite de F1', async () => {
  await assertFails(getDoc(D(as('U2'), 'invitations/INV1')));
  await assertFails(getDoc(D(as('U1'), 'invitations/INV1'))); // get nunca permitido (so list por createdBy)
  await assertFails(getDocs(col(as('U1'), 'invitations')));
  await assertFails(getDocs(query(col(as('U2'), 'invitations'), where('createdBy', '==', 'U1'))));
  await assertFails(getDocs(query(col(as('U4'), 'invitations'), where('createdBy', '==', 'U1'))));
  await assertFails(getDocs(query(col(as('U4'), 'invitations'), where('familyId', '==', 'F1'))));
});

test('N46 nenhum cliente cria/edita/revoga invitations', async () => {
  for (const u of ['U1', 'U2', 'U4']) {
    const db = as(u);
    await assertFails(
      setDoc(D(db, `invitations/NEW_${u}`), { familyId: 'F1', createdBy: u, status: 'pending' }),
    );
    await assertFails(updateDoc(D(db, 'invitations/INV1'), { status: 'revoked' }));
    await assertFails(deleteDoc(D(db, 'invitations/INV1')));
  }
});

test('N47 devices com platform invalido ou fcmToken gigante', async () => {
  const db = as('U2');
  const base = { fcmToken: 't', platform: 'android', lastSeenAt: ts(), createdAt: ts() };
  await assertFails(setDoc(D(db, 'users/U2/devices/d1'), { ...base, platform: 'ios' }));
  await assertFails(setDoc(D(db, 'users/U2/devices/d2'), { ...base, fcmToken: 'x'.repeat(4097) }));
  await assertFails(setDoc(D(db, 'users/U2/devices/d3'), { ...base, extra: 1 }));
  await assertFails(setDoc(D(db, 'users/U2/devices/d4'), { ...base, fcmToken: '' }));
  await assertFails(setDoc(D(db, 'users/U2/devices/' + 'a'.repeat(129)), base));
  await assertFails(setDoc(D(db, 'users/U2/devices/bad id!'), base).catch((e) => Promise.reject(e)));
  await assertFails(updateDoc(D(db, 'users/U2/devices/dev1'), { platform: 'ios', lastSeenAt: ts() }));
  await assertFails(updateDoc(D(db, 'users/U2/devices/dev1'), { fcmToken: 'x'.repeat(4097), lastSeenAt: ts() }));
});

// --- Autoria ---
test('N48 member edita task/lista de outro quando nao e o assignedTo', async () => {
  const db = as('U2');
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU3`), { title: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(db, `${H1}/tasks/tU3`), { description: 'x', updatedAt: ts() }));
  await assertFails(updateDoc(D(db, `${H1}/tasks/tNull`), { title: 'x', updatedAt: ts() })); // assignedTo null: so concluir/reabrir
  await assertFails(updateDoc(D(db, `${H1}/lists/lU3`), { name: 'x', updatedAt: ts() }));
  // conclui tarefa atribuida a outra pessoa (U3)
  await assertFails(
    updateDoc(D(db, `${H1}/tasks/tU3`), {
      status: 'done',
      completedBy: 'U2',
      completedAt: ts(),
      updatedAt: ts(),
    }),
  );
});

test('N49 U2 conclui task com completedBy = U3', async () => {
  const db = as('U2');
  await assertFails(
    updateDoc(D(db, `${H1}/tasks/tNull`), {
      status: 'done',
      completedBy: 'U3',
      completedAt: ts(),
      updatedAt: ts(),
    }),
  );
  await assertFails(
    updateDoc(D(db, `${H1}/tasks/tU2`), {
      status: 'done',
      completedBy: 'U3',
      completedAt: ts(),
      updatedAt: ts(),
    }),
  );
  // done sem completedAt de servidor
  await assertFails(
    updateDoc(D(db, `${H1}/tasks/tU2`), {
      status: 'done',
      completedBy: 'U2',
      completedAt: ts0(),
      updatedAt: ts(),
    }),
  );
});

test('N50 U2 soft-deleta lista criada por U3', async () => {
  await assertFails(updateDoc(D(as('U2'), `${H1}/lists/lU3`), { deletedAt: ts(), updatedAt: ts() }));
  await assertFails(
    updateDoc(D(as('U2'), `${H1}/lists/lU3/items/iU3`), { name: 'x', createdBy: 'U2', updatedAt: ts() }),
  );
});

// ===========================================================================
// 8.2 POSITIVOS
// ===========================================================================

test('P01 owner le familia, members, entitlement, subscription, casas (query de owner) e conteudo sem estar em access', async () => {
  const db = as('U1');
  await assertSucceeds(getDoc(D(db, 'families/F1')));
  await assertSucceeds(getDoc(D(db, 'families/F1/members/U2')));
  await assertSucceeds(getDocs(col(db, 'families/F1/members')));
  await assertSucceeds(getDoc(D(db, 'families/F1/billing/entitlement')));
  await assertSucceeds(getDoc(D(db, 'families/F1/billing/subscription')));
  const hs = await assertSucceeds(getDocs(col(db, 'families/F1/households')));
  assert.deepEqual(hs.docs.map((d) => d.id).sort(), ['H1', 'H2']);
  await assertSucceeds(getDoc(D(db, H1)));
  await assertSucceeds(getDocs(lim(db, `${H1}/tasks`)));
  await assertSucceeds(getDocs(lim(db, `${H2}/tasks`)));
  await assertSucceeds(getDocs(lim(db, `${H1}/lists`)));
  await assertSucceeds(getDocs(lim(db, `${H1}/lists/lU3/items`)));
  await assertSucceeds(getDocs(lim(db, `${H1}/activity`, 50)));
  await assertSucceeds(getDoc(D(db, `${H2}/tasks/t2`)));
});

test('P02 member U2 le familia, entitlement, H1; query array-contains retorna so H1', async () => {
  const db = as('U2');
  await assertSucceeds(getDoc(D(db, 'families/F1')));
  await assertSucceeds(getDoc(D(db, 'families/F1/billing/entitlement')));
  await assertSucceeds(getDoc(D(db, H1)));
  const snap = await assertSucceeds(
    getDocs(query(col(db, 'families/F1/households'), where('accessUids', 'array-contains', 'U2'))),
  );
  assert.deepEqual(snap.docs.map((d) => d.id), ['H1']);
  await assertSucceeds(getDocs(lim(db, `${H1}/tasks`)));
  await assertSucceeds(getDocs(lim(db, `${H1}/activity`, 50)));
});

test('P03 U2 cria task (pending, schedule null, assignedTo U2) + activity task_created no mesmo batch', async () => {
  const db = as('U2');
  const b = writeBatch(db);
  b.set(D(db, `${H1}/tasks/new1`), taskDoc('U2'));
  b.set(D(db, `${H1}/activity/act1`), activityDoc('U2', { targetId: 'new1' }));
  await assertSucceeds(b.commit());
  // com horario e notificacao
  await assertSucceeds(
    setDoc(
      D(db, `${H1}/tasks/new2`),
      taskDoc('U2', {
        schedule: {
          type: 'datetime',
          scheduledAt: Timestamp.fromDate(new Date('2030-01-01T11:00:00Z')),
          timezone: 'America/Sao_Paulo',
        },
        notification: { enabled: true, offsetMinutes: 15 },
        description: 'desc',
      }),
    ),
  );
});

test('P04 U2 edita, conclui e reabre a propria task; titulo 1-200', async () => {
  const db = as('U2');
  const ref = D(db, `${H1}/tasks/tU2`);
  await assertSucceeds(updateDoc(ref, { title: 'novo', updatedAt: ts() }));
  await assertSucceeds(updateDoc(ref, { title: 'x'.repeat(200), updatedAt: ts() }));
  await assertSucceeds(
    updateDoc(ref, { status: 'done', completedBy: 'U2', completedAt: ts(), updatedAt: ts() }),
  );
  await assertSucceeds(updateDoc(ref, { title: 'editada concluida', updatedAt: ts() }));
  await assertSucceeds(
    updateDoc(ref, { status: 'pending', completedBy: null, completedAt: null, updatedAt: ts() }),
  );
});

test('P05 U2 conclui task com assignedTo null criada por U3 (e reabre)', async () => {
  const db = as('U2');
  const ref = D(db, `${H1}/tasks/tNull`);
  await assertSucceeds(
    updateDoc(ref, { status: 'done', completedBy: 'U2', completedAt: ts(), updatedAt: ts() }),
  );
  await assertSucceeds(
    updateDoc(ref, { status: 'pending', completedBy: null, completedAt: null, updatedAt: ts() }),
  );
});

test('P06 U2 soft-deleta a propria task; U3 (admin) soft-deleta task de U2 e edita qualquer lista', async () => {
  await assertSucceeds(
    updateDoc(D(as('U2'), `${H1}/tasks/tU2`), { deletedAt: ts(), updatedAt: ts() }),
  );
  await assertSucceeds(
    updateDoc(D(as('U3'), `${H1}/tasks/tU2b`), { deletedAt: ts(), updatedAt: ts() }),
  );
  await assertSucceeds(updateDoc(D(as('U3'), `${H1}/lists/lU2`), { name: 'renomeada', updatedAt: ts() }));
  await assertSucceeds(
    updateDoc(D(as('U3'), `${H1}/lists/lU2`), { deletedAt: ts(), updatedAt: ts() }),
  );
  // admin restaura
  await assertSucceeds(
    updateDoc(D(as('U3'), `${H1}/tasks/tDel`), { deletedAt: null, updatedAt: ts() }),
  );
  await assertSucceeds(
    updateDoc(D(as('U3'), `${H1}/lists/lU3/items/iDel`), { deletedAt: null, updatedAt: ts() }),
  );
});

test('P07 U2 adiciona/completa/reordena itens em lista criada por U3', async () => {
  const db = as('U2');
  await assertSucceeds(setDoc(D(db, `${H1}/lists/lU3/items/new`), itemDoc('U2')));
  const ref = D(db, `${H1}/lists/lU3/items/iU3`); // criado por U3
  await assertSucceeds(
    updateDoc(ref, { completed: true, completedBy: 'U2', completedAt: ts(), updatedAt: ts() }),
  );
  await assertSucceeds(updateDoc(ref, { order: 2.5, updatedAt: ts() }));
  await assertSucceeds(updateDoc(ref, { name: 'Leite', updatedAt: ts() }));
  await assertSucceeds(
    updateDoc(ref, { completed: false, completedBy: null, completedAt: null, updatedAt: ts() }),
  );
  // U2 cria lista propria
  await assertSucceeds(setDoc(D(db, `${H1}/lists/lnew`), listDoc('U2', { type: 'general' })));
});

test('P08 owner atualiza families/F1.name e households/H2.name', async () => {
  const db = as('U1');
  await assertSucceeds(updateDoc(D(db, 'families/F1'), { name: 'Nova', updatedAt: ts() }));
  await assertSucceeds(updateDoc(D(db, H2), { name: 'Cozinha', updatedAt: ts() }));
  // owner (admin implicito) edita conteudo de qualquer autor
  await assertSucceeds(updateDoc(D(db, `${H1}/tasks/tU3`), { title: 'owner edita', updatedAt: ts() }));
});

test('P09 admin da casa (U3) renomeia households/H1', async () => {
  await assertSucceeds(updateDoc(D(as('U3'), H1), { name: 'Casa Nova', updatedAt: ts() }));
});

test('P10 U2 atualiza o proprio perfil e cria/atualiza/remove o proprio device', async () => {
  const db = as('U2');
  await assertSucceeds(
    updateDoc(D(db, 'users/U2'), {
      displayName: 'Novo Nome',
      locale: 'en-US',
      timezone: 'America/Manaus',
      photoUrl: 'https://example.test/p.png',
      updatedAt: ts(),
    }),
  );
  await assertSucceeds(getDoc(D(db, 'users/U2')));
  await assertSucceeds(
    setDoc(D(db, 'users/U2/devices/devNew'), {
      fcmToken: 'abc',
      platform: 'android',
      appVersion: '1.0.0',
      locale: 'pt-BR',
      timezone: 'America/Sao_Paulo',
      lastSeenAt: ts(),
      createdAt: ts(),
    }),
  );
  await assertSucceeds(
    updateDoc(D(db, 'users/U2/devices/devNew'), { fcmToken: 'def', lastSeenAt: ts() }),
  );
  await assertSucceeds(getDoc(D(db, 'users/U2/devices/devNew')));
  await assertSucceeds(deleteDoc(D(db, 'users/U2/devices/devNew')));
  await assertSucceeds(deleteDoc(D(db, 'users/U2/devices/dev1')));
});

test('P11 em frozen: todos leem; U2 edita perfil e device', async () => {
  await setFamily1Status('frozen');
  for (const u of ['U1', 'U2', 'U3']) {
    const db = as(u);
    await assertSucceeds(getDoc(D(db, 'families/F1')));
    await assertSucceeds(getDoc(D(db, `${H1}/tasks/tU2`)));
    await assertSucceeds(getDocs(lim(db, `${H1}/tasks`)));
    await assertSucceeds(getDocs(lim(db, `${H1}/lists`)));
    await assertSucceeds(getDocs(lim(db, `${H1}/lists/lU3/items`)));
    await assertSucceeds(getDocs(lim(db, `${H1}/activity`, 50)));
    await assertSucceeds(getDoc(D(db, 'families/F1/billing/entitlement')));
  }
  await assertSucceeds(getDoc(D(as('U1'), 'families/F1/billing/subscription')));
  const db2 = as('U2');
  await assertSucceeds(updateDoc(D(db2, 'users/U2'), { displayName: 'Ok', updatedAt: ts() }));
  await assertSucceeds(
    setDoc(D(db2, 'users/U2/devices/devF'), {
      fcmToken: 'a',
      platform: 'android',
      lastSeenAt: ts(),
      createdAt: ts(),
    }),
  );
  await assertSucceeds(
    updateDoc(D(db2, 'users/U2/devices/dev1'), { lastSeenAt: ts() }),
  );
});

test('P12 U1 lista os convites com where createdBy == U1', async () => {
  const snap = await assertSucceeds(
    getDocs(query(col(as('U1'), 'invitations'), where('createdBy', '==', 'U1'))),
  );
  assert.deepEqual(snap.docs.map((d) => d.id), ['INV1']);
});

test('P13 usuario le o proprio users/{uid}/memberships', async () => {
  const snap = await assertSucceeds(getDocs(col(as('U1'), 'users/U1/memberships')));
  assert.equal(snap.size, 2);
  await assertSucceeds(getDoc(D(as('U2'), 'users/U2/memberships/F1')));
});

test('P14 batch task + activity (como sincronizado apos offline) passa com familia active', async () => {
  const db = as('U3');
  const b = writeBatch(db);
  b.set(D(db, `${H1}/tasks/off1`), taskDoc('U3', { assignedTo: null }));
  b.set(D(db, `${H1}/activity/offAct`), activityDoc('U3', { targetId: 'off1' }));
  b.set(D(db, `${H1}/lists/loff`), listDoc('U3'));
  b.set(D(db, `${H1}/activity/offAct2`), activityDoc('U3', { type: 'list_created', targetType: 'list', targetId: 'loff' }));
  await assertSucceeds(b.commit());
});

test('P15 owner atribui task a member presente em accessUids (e a si mesmo via ownerId)', async () => {
  const db = as('U1');
  await assertSucceeds(setDoc(D(db, `${H1}/tasks/o1`), taskDoc('U1', { assignedTo: 'U2' })));
  await assertSucceeds(setDoc(D(db, `${H1}/tasks/o2`), taskDoc('U1', { assignedTo: 'U1' })));
  await assertSucceeds(updateDoc(D(db, `${H1}/tasks/tU3`), { assignedTo: 'U2', updatedAt: ts() }));
  await assertSucceeds(
    setDoc(D(db, `${H1}/activity/o1a`), activityDoc('U1', { type: 'task_assigned', targetId: 'o1' })),
  );
});

test('N-testers: ninguem (nem logado) le ou escreve _testers (plano de teste so pelo console/Admin)', async () => {
  for (const db of [anon(), as('U1'), as('U9')]) {
    await assertFails(getDoc(D(db, '_testers/u1@exemplo.test')));
    await assertFails(setDoc(D(db, '_testers/u9@exemplo.test'), { plan: 'family_plus' }));
  }
});
