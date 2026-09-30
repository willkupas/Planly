// Listas/itens e convites contra o Emulator Suite (Rules e Functions REAIS), sem UI: usa os
// repositórios/callables reais do app. Como rodar (emuladores de pé + Android ligado):
//   .\integration_test\run_emulator_tests.ps1 -Test integration_test/lists_and_invitations_test.dart
// Cenário do seed: dono (owner, plano Família, casas Principal=H1 e Praia=H2), ana (membro só H1),
// beto (membro sem casa). Contas novas (novo, extra) são criadas aqui via bootstrapUser.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/invitation/data/firestore_invitation_repository.dart';
import 'package:planly/features/invitation/domain/invitation_models.dart';
import 'package:planly/features/lists/data/firestore_list_repository.dart';
import 'package:planly/features/lists/domain/list_models.dart';

import 'support/env.dart';

const accExtra = FakeAccount('uid-teste-extra', 'Extra Teste');

Future<String> _signIn(FakeAccount acc) async {
  final auth = FirebaseAuth.instance;
  await auth.signOut();
  await auth.signInWithCredential(GoogleAuthProvider.credential(idToken: acc.idToken));
  return auth.currentUser!.uid;
}

Matcher _reason(String r) => isA<BusinessFailure>().having((e) => e.reason, 'reason', r);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initEmulatorFirebase);

  testWidgets('LISTAS: criar lista + item + completar + count() agregado + activity nas Rules reais',
      (tester) async {
    await tester.runAsync(() async {
      await resetClientState();
      final db = FirebaseFirestore.instance;
      final repo = FirestoreListRepository(firestore: db);

      // Dono cria lista e itens.
      final donoUid = await _signIn(accDono);
      final listId = await repo.createList(
        familyId: seedFamilyId,
        householdId: seedH1,
        name: 'Mercado ${DateTime.now().millisecondsSinceEpoch}',
        type: ListType.shopping,
        actorId: donoUid,
        actorName: accDono.name,
      );
      final i1 = await repo.addItem(
          familyId: seedFamilyId, householdId: seedH1, listId: listId, name: 'Leite', order: 1000,
          actorId: donoUid, actorName: accDono.name);
      final i2 = await repo.addItem(
          familyId: seedFamilyId, householdId: seedH1, listId: listId, name: 'Pão', order: 2000,
          actorId: donoUid, actorName: accDono.name);

      final listDoc = await db
          .doc('families/$seedFamilyId/households/$seedH1/lists/$listId')
          .get(const GetOptions(source: Source.server));
      expect(listDoc.exists, isTrue);
      expect(listDoc.data()!['type'], 'shopping');

      // count() agregado no servidor com where + limit(200) (mesmo código do app).
      expect(await repo.pendingCount(seedFamilyId, seedH1, listId), 2);

      // Ana (membro com acesso a H1) completa um item; count cai para 1.
      final anaUid = await _signIn(accAna);
      await repo.setItemCompleted(
          familyId: seedFamilyId, householdId: seedH1, listId: listId, itemId: i1, itemName: 'Leite',
          completed: true, actorId: anaUid, actorName: accAna.name);
      expect(await repo.pendingCount(seedFamilyId, seedH1, listId), 1);
      final item1 = await db
          .doc('families/$seedFamilyId/households/$seedH1/lists/$listId/items/$i1')
          .get(const GetOptions(source: Source.server));
      expect(item1.data()!['completed'], true);
      expect(item1.data()!['completedBy'], anaUid);

      // Stream de itens (query com índice existente) sob as Rules: pendente antes de concluído.
      final snap = await repo.watchItems(seedFamilyId, seedH1, listId).firstWhere((s) => !s.meta.isFromCache);
      expect(snap.items.map((e) => e.id), [i2, i1]);

      // Activity gravada nos mesmos batches.
      final acts = await db
          .collection('families/$seedFamilyId/households/$seedH1/activity')
          .where('targetId', whereIn: [listId, i1, i2])
          .limit(20)
          .get(const GetOptions(source: Source.server));
      final types = acts.docs.map((d) => d.data()['type']).toList();
      expect(types, containsAll(['list_created', 'item_added', 'item_completed']));

      // Beto (sem casa) não lê nem conta itens: Rules negam.
      await _signIn(accBeto);
      await expectLater(
        db.collection('families/$seedFamilyId/households/$seedH1/lists/$listId/items').limit(20).get(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
      expect(await repo.pendingCount(seedFamilyId, seedH1, listId), isNull,
          reason: 'sem acesso, pendingCount devolve null (erro engolido)');

      // Soft delete do item + da lista (dono) gera activity.
      await _signIn(accDono);
      await repo.deleteItem(
          familyId: seedFamilyId, householdId: seedH1, listId: listId, itemId: i2, itemName: 'Pão',
          actorId: donoUid, actorName: accDono.name);
      expect(await repo.pendingCount(seedFamilyId, seedH1, listId), 0);
      await repo.deleteList(
          familyId: seedFamilyId, householdId: seedH1, listId: listId, listName: 'Mercado',
          actorId: donoUid, actorName: accDono.name);
      final gone = await db
          .doc('families/$seedFamilyId/households/$seedH1/lists/$listId')
          .get(const GetOptions(source: Source.server));
      expect(gone.data()!['deletedAt'], isNotNull);
    });
  });

  testWidgets('CONVITES: create -> accept (outro usuário) -> acesso às casas -> revoke', (tester) async {
    await tester.runAsync(() async {
      await resetClientState();
      final db = FirebaseFirestore.instance;
      final invoke = realInvoker();
      final repo = FirestoreInvitationRepository(firestore: db, callable: invoke);

      final donoUid = await _signIn(accDono);
      await invoke('bootstrapUser', {'locale': 'pt-BR'});

      // Seed: dono+ana+beto = 3 de 4. Convite 1 (H2) é revogado; depois aceito-por-extra falha.
      final inv1 = await repo.createInvitation(
        familyId: seedFamilyId,
        grants: [InviteGrant(householdId: seedH2, role: HouseholdRole.member)],
      );
      expect(inv1.code, hasLength(10));
      expect(inv1.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);

      // Lista do owner (Rules: where createdBy == uid; get direto é negado).
      final mine = await repo.watchCreatedBy(donoUid).firstWhere((l) => l.any((i) => i.code == inv1.code));
      expect(mine.firstWhere((i) => i.code == inv1.code).status, InvitationStatus.pending);
      await expectLater(
        db.doc('invitations/${inv1.code}').get(const GetOptions(source: Source.server)),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );

      await repo.revokeInvitation(inv1.code);
      await repo.revokeInvitation(inv1.code); // idempotente
      await _signIn(accExtra);
      await realInvoker()('bootstrapUser', {'locale': 'pt-BR'});
      await expectLater(repo.acceptInvitation(inv1.code), throwsA(_reason('INVITE_NOT_FOUND')));

      // Convite 2 (H2 + H1 não: só H2 como participante): aceito por "novo".
      await _signIn(accDono);
      final inv2 = await repo.createInvitation(
        familyId: seedFamilyId,
        grants: [InviteGrant(householdId: seedH2, role: HouseholdRole.member)],
      );

      // Quem não é o dono não revoga.
      await _signIn(accExtra);
      await expectLater(repo.revokeInvitation(inv2.code), throwsA(_reason('INVITE_NOT_FOUND')));

      final novoUid = await _signIn(accNovo);
      await realInvoker()('bootstrapUser', {'locale': 'pt-BR'});
      final accepted = await repo.acceptInvitation(inv2.code);
      expect(accepted.familyId, seedFamilyId);
      expect(accepted.householdIds, [seedH2]);
      final again = await repo.acceptInvitation(inv2.code); // idempotente para quem já é membro
      expect(again.familyId, seedFamilyId);

      // Acesso concedido: membro lê só H2 (query de membro); listar tudo é negado.
      final houses = await db
          .collection('families/$seedFamilyId/households')
          .where('accessUids', arrayContains: novoUid)
          .limit(50)
          .get(const GetOptions(source: Source.server));
      expect(houses.docs.map((d) => d.id), [seedH2]);
      await expectLater(
        db.collection('families/$seedFamilyId/households').limit(50).get(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
      final memberDoc = await db
          .doc('families/$seedFamilyId/members/$novoUid')
          .get(const GetOptions(source: Source.server));
      expect(memberDoc.data()!['status'], 'active');

      // Convite usado não pode ser aceito por outra conta nem revogado.
      await _signIn(accExtra);
      await expectLater(repo.acceptInvitation(inv2.code), throwsA(_reason('INVITE_NOT_FOUND')));
      await _signIn(accDono);
      await expectLater(repo.revokeInvitation(inv2.code), throwsA(_reason('INVITE_NOT_FOUND')));

      // Família cheia (4 de 4): novo convite é recusado pelo servidor.
      await expectLater(
        repo.createInvitation(
          familyId: seedFamilyId,
          grants: [InviteGrant(householdId: seedH1, role: HouseholdRole.member)],
        ),
        throwsA(_reason('PLAN_LIMIT_MEMBERS')),
      );
    });
  });
}
