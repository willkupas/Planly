// Seed do ambiente de integração (Emulator Suite, projeto DEV). SÓ fala com 127.0.0.1.
//
// Uso (na raiz do repo, Node 22, com os emuladores de pé):
//   node integration_test/seed/seed.mjs
//
// 1. Limpa Auth e Firestore do emulador (endpoints /emulator/v1 — só existem no emulador).
// 2. Cria usuários fictícios via signInWithIdp com idToken JSON não assinado (o Auth Emulator
//    não valida assinatura) — mesmo formato que o app usa no teste.
// 3. Usa as Functions REAIS: bootstrapUser (dono + membros), createHousehold, createInvitation,
//    acceptInvitation e setHouseholdAccess. Só o "upgrade de plano" usa o Admin SDK (simula o
//    billing, que ainda não existe).
//
// Cenário criado (emails @exemplo.test; nenhum dado real):
// (O uid do Firebase Auth é gerado pelo emulador; o `sub` do token só identifica a conta federada.)
//   dono (sub uid-teste-dono): owner de uma Família PAGA "Família Dono" (plano `family`), casas
//                     "Casa Principal" (H1) e "Casa Praia" (H2); membros Ana (H1 member) e Beto (sem casa).
//   uid-teste-ana   : membro de "Família Dono" (acessa só H1) + tem a própria Free.
//   uid-teste-beto  : membro de "Família Dono" sem acesso a casa + tem a própria Free.
// `uid-teste-novo` NÃO é criado aqui: o teste faz o primeiro acesso dele pelo app.
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const requireFromFunctions = createRequire(path.join(root, 'functions', 'package.json'));

const PROJECT = 'planly-dev-d8533';
const REGION = 'southamerica-east1';
const HOST = '127.0.0.1';
const AUTH = `http://${HOST}:9099`;
const FUNCTIONS = `http://${HOST}:5001/${PROJECT}/${REGION}`;

process.env.FIRESTORE_EMULATOR_HOST = `${HOST}:8080`;
process.env.FIREBASE_AUTH_EMULATOR_HOST = `${HOST}:9099`;
const { initializeApp } = requireFromFunctions('firebase-admin/app');
const { getFirestore } = requireFromFunctions('firebase-admin/firestore');
initializeApp({ projectId: PROJECT });
const db = getFirestore();

export const USERS = {
  dono: { sub: 'uid-teste-dono', email: 'dono@exemplo.test', name: 'Dono Teste' },
  ana: { sub: 'uid-teste-ana', email: 'ana@exemplo.test', name: 'Ana Teste' },
  beto: { sub: 'uid-teste-beto', email: 'beto@exemplo.test', name: 'Beto Teste' },
};

async function clearAll() {
  await fetch(`${AUTH}/emulator/v1/projects/${PROJECT}/accounts`, { method: 'DELETE' });
  await fetch(`http://${HOST}:8080/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, {
    method: 'DELETE',
  });
}

async function signIn(u) {
  const idToken = JSON.stringify({ sub: u.sub, email: u.email, email_verified: true, name: u.name });
  const res = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=fake-key`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      postBody: `id_token=${encodeURIComponent(idToken)}&providerId=google.com`,
      requestUri: 'http://localhost',
      returnIdpCredential: true,
      returnSecureToken: true,
    }),
  });
  if (res.status !== 200) throw new Error(`signInWithIdp ${u.sub}: ${res.status}`);
  const j = await res.json();
  return { uid: j.localId, token: j.idToken };
}

async function call(fn, data, user) {
  const res = await fetch(`${FUNCTIONS}/${fn}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${user.token}` },
    body: JSON.stringify({ data }),
  });
  const body = await res.json();
  if (res.status !== 200) {
    throw new Error(`${fn} falhou: ${body?.error?.status}/${body?.error?.details?.reason}`);
  }
  return body.result;
}

await clearAll();
const dono = await signIn(USERS.dono);
const ana = await signIn(USERS.ana);
const beto = await signIn(USERS.beto);

const { familyId, householdId: h1 } = await call(
  'bootstrapUser',
  { displayName: USERS.dono.name, householdName: 'Casa Principal' },
  dono,
);
await call('bootstrapUser', { displayName: USERS.ana.name }, ana);
await call('bootstrapUser', { displayName: USERS.beto.name }, beto);

// "Billing" simulado: promove a família do dono para `family` (maxMembers 4, maxHouseholds 3).
await db.doc(`families/${familyId}`).update({ plan: 'family', name: 'Família Dono' });
await db.doc(`families/${familyId}/billing/entitlement`).set({
  plan: 'family',
  maxMembers: 4,
  maxHouseholds: 3,
  features: { invites: true, recurringTasks: true, fullHistory: true },
  source: 'subscription',
  updatedAt: new Date(),
});
await db.doc(`users/${dono.uid}/memberships/${familyId}`).update({ plan: 'family', familyName: 'Família Dono' });

const { householdId: h2 } = await call('createHousehold', { familyId, name: 'Casa Praia' }, dono);

const invA = await call(
  'createInvitation',
  { familyId, grants: [{ householdId: h1, role: 'member' }] },
  dono,
);
await call('acceptInvitation', { code: invA.code }, ana);
const invB = await call('createInvitation', { familyId, grants: [{ householdId: h1, role: 'member' }] }, dono);
await call('acceptInvitation', { code: invB.code }, beto);
// Beto fica sem acesso a nenhuma casa (revogado pelo owner).
await call(
  'setHouseholdAccess',
  { familyId, householdId: h1, targetUid: beto.uid, role: null },
  dono,
);

// Famílias em estados especiais, cada uma de um owner próprio:
//   cong (sub uid-teste-cong): "Família Congelada" (frozen) com Ana como membro (acessa a casa).
//   del  (sub uid-teste-del) : "Família Excluindo" (deleting) com Beto como membro (acessa a casa).
async function paidFamilyWithMember(sub, name, familyName, member, status) {
  const owner = await signIn({ sub, email: `${sub.replace('uid-teste-', '')}@exemplo.test`, name });
  const { familyId: f, householdId: h } = await call(
    'bootstrapUser',
    { displayName: name, householdName: `Casa de ${name}` },
    owner,
  );
  await db.doc(`families/${f}`).update({ plan: 'family', name: familyName });
  await db.doc(`families/${f}/billing/entitlement`).set({
    plan: 'family',
    maxMembers: 4,
    maxHouseholds: 3,
    features: { invites: true, recurringTasks: true, fullHistory: true },
    source: 'subscription',
    updatedAt: new Date(),
  });
  const inv = await call('createInvitation', { familyId: f, grants: [{ householdId: h, role: 'member' }] }, owner);
  await call('acceptInvitation', { code: inv.code }, member);
  // Só depois de montar tudo a família muda de estado (mesmos campos que o lifecycleJob usará).
  const day = 24 * 60 * 60 * 1000;
  await db.doc(`families/${f}`).update(
    status === 'frozen'
      ? { status, frozenAt: new Date(), deleteAfter: new Date(Date.now() + 60 * day) }
      : { status },
  );
  for (const uid of [owner.uid, member.uid]) {
    await db.doc(`users/${uid}/memberships/${f}`).update({ plan: 'family', familyName, familyStatus: status });
  }
  return { familyId: f, householdId: h };
}
const frozen = await paidFamilyWithMember('uid-teste-cong', 'Cong Teste', 'Família Congelada', ana, 'frozen');
const deleting = await paidFamilyWithMember('uid-teste-del', 'Del Teste', 'Família Excluindo', beto, 'deleting');

console.log(
  JSON.stringify({
    familyId,
    h1,
    h2,
    dono: dono.uid,
    ana: ana.uid,
    beto: beto.uid,
    frozenFamily: frozen.familyId,
    deletingFamily: deleting.familyId,
  }),
);
process.exit(0);
