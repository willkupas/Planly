// Integração de ponta a ponta: app (flavor dev) + Emulator Suite com as Functions e as Rules
// REAIS. Sem credenciais reais. Passo a passo: docs/testing/integracao-emulador.md
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:planly/core/error/app_failure.dart';

import 'support/env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initEmulatorFirebase);

  testWidgets('A. primeiro acesso (Free): login -> bootstrap real -> dashboard; limites; logout/login',
      (tester) async {
    final prefs = await resetClientState();
    final app = await launchApp(tester, prefs, accNovo);

    // Login (credencial falsa no Auth Emulator).
    await tapKey(tester, 'login-google');
    await waitFor(tester, find.byKey(const Key('dashboard-content')), reason: 'dashboard após bootstrap');
    final uid = FirebaseAuth.instance.currentUser!.uid;
    expect(find.text('Minha casa'), findsWidgets); // casa inicial no seletor

    // users/{uid}: criado pela Function, com upsert do cliente (updatedAt serverTimestamp nas Rules).
    final db = FirebaseFirestore.instance;
    final user = await db.doc('users/$uid').get();
    expect(user.exists, isTrue);
    expect(user.data()!['freeFamilyId'], isA<String>());
    expect(user.data()!['locale'], 'pt-BR');
    expect(user.data()!['timezone'], isNotEmpty);
    final familyId = user.data()!['freeFamilyId'] as String;

    // Queries que o app faz, contra as Rules reais.
    final memberships = await db.collection('users/$uid/memberships').limit(50).get();
    expect(memberships.docs.single.id, familyId);
    final hh = await db.collection('families/$familyId/households').limit(50).get();
    expect(hh.docs, hasLength(1));
    final members =
        await db.collection('families/$familyId/members').where('status', isEqualTo: 'active').limit(50).get();
    expect(members.docs, hasLength(1));
    // Membro (array-contains) também é aceito pelas Rules; o owner não está em accessUids => vazio, sem erro.
    final asMember = await db
        .collection('families/$familyId/households')
        .where('accessUids', arrayContains: uid)
        .limit(50)
        .get();
    expect(asMember.docs, isEmpty);

    // Envelope {ok:true, familyId, householdId} e idempotência (mesmos ids).
    final invoke = realInvoker();
    final again = await invoke('bootstrapUser', {'locale': 'pt-BR'});
    expect(again['ok'], true);
    expect(again['familyId'], familyId);
    expect(again['householdId'], hh.docs.single.id);

    // Free: limites vindos do servidor chegam como BusinessFailure(reason).
    await expectLater(
      invoke('createHousehold', {'familyId': familyId, 'name': 'Outra'}),
      throwsA(isA<BusinessFailure>().having((e) => e.reason, 'reason', 'PLAN_LIMIT_HOUSEHOLDS')),
    );
    await expectLater(
      invoke('deleteHousehold', {'familyId': familyId, 'householdId': hh.docs.single.id}),
      throwsA(isA<BusinessFailure>().having((e) => e.reason, 'reason', 'LAST_HOUSEHOLD')),
    );
    await expectLater(
      invoke('createInvitation', {
        'familyId': familyId,
        'grants': [
          {'householdId': hh.docs.single.id, 'role': 'member'},
        ],
      }),
      throwsA(isA<BusinessFailure>().having((e) => e.reason, 'reason', 'FEATURE_NOT_IN_PLAN')),
    );
    await expectLater(
      invoke('leaveFamily', {'familyId': familyId}),
      throwsA(isA<BusinessFailure>().having((e) => e.reason, 'reason', 'OWNER_CANNOT_LEAVE')),
    );

    // Família (hub) e limite de casas na UI: upsell SEM chamar a Function.
    await tapKey(tester, 'nav-family');
    await waitFor(tester, find.text('Grátis'));
    expect(find.text('1 de 1 pessoas'), findsOneWidget);
    expect(find.text('1 de 1 casas'), findsOneWidget);
    await tapKey(tester, 'go-households');
    await tapKey(tester, 'add-household');
    await waitFor(tester, find.byKey(const Key('upsell-dialog')));
    expect((await db.collection('families/$familyId/households').get()).docs, hasLength(1));
    await tester.tap(find.text('Entendi'));
    await settle(tester);
    expect(app.account().sub, accNovo.sub);
  });

  testWidgets('A2. logout limpo e logout com escrita pendente; relogin volta a funcionar', (tester) async {
    final prefs = await resetClientState();
    await launchApp(tester, prefs, accNovo);
    await tapKey(tester, 'login-google');
    await waitFor(tester, find.byKey(const Key('dashboard-content')));
    final auth = FirebaseAuth.instance;
    final uid = auth.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    // (Conta já tem família: sem bootstrap, o contexto ativo é resolvido por padrão, sem gravar prefs.)
    await prefs.setString('activeContext.$uid.familyId', 'lixo-a-limpar-no-logout');

    Future<void> logoutViaUi() async {
      await tapKey(tester, 'open-settings');
      await tapKey(tester, 'logout');
    }

    // 1) logout sem pendências.
    await logoutViaUi();
    await waitFor(tester, find.byKey(const Key('login-google')), reason: 'tela de login');
    expect(auth.currentUser, isNull);
    expect(prefs.getString('activeContext.$uid.familyId'), isNull);
    expect(prefs.getBool('firestore.pendingClear'), isNot(true), reason: 'terminate+clearPersistence na mesma sessão');

    // 2) relogin: o Firestore reaberto após terminate() ainda aponta para o emulador.
    await tapKey(tester, 'login-google');
    await waitFor(tester, find.byKey(const Key('dashboard-content')), reason: 'dashboard após relogin');
    final fresh = await db.doc('users/$uid').get(const GetOptions(source: Source.server));
    expect(fresh.exists, isTrue, reason: 'leitura do SERVIDOR (emulador) após reabrir o Firestore');

    // 3) logout com escrita pendente (rede do Firestore desligada só para forjar a pendência).
    final familyId = fresh.data()!['freeFamilyId'] as String;
    final hh = await db
        .collection('families/$familyId/households')
        .limit(5)
        .get(const GetOptions(source: Source.server));
    await db.disableNetwork();
    unawaited(db.doc('families/$familyId/households/${hh.docs.single.id}').update({
      'name': 'Pendente',
      'updatedAt': FieldValue.serverTimestamp(),
    }));
    await settle(tester, ms: 300);
    await logoutViaUi();
    await waitFor(tester, find.text('Alterações não sincronizadas'), reason: 'aviso de pendências');
    await tester.tap(find.text('Sair mesmo assim'));
    await waitFor(tester, find.byKey(const Key('login-google')), reason: 'login após "sair mesmo assim"');
    expect(auth.currentUser, isNull);
    expect(prefs.getBool('firestore.pendingClear'), isNot(true));

    // 4) novo login após logout forçado: app volta a funcionar, e a escrita descartada não vazou.
    await tapKey(tester, 'login-google');
    await waitFor(tester, find.byKey(const Key('dashboard-content')), reason: 'dashboard após logout forçado');
    final after = await db
        .doc('families/$familyId/households/${hh.docs.single.id}')
        .get(const GetOptions(source: Source.server));
    expect(after.data()!['name'], 'Minha casa', reason: 'escrita pendente foi descartada');
  });

  /// Login pela UI e espera do dashboard.
  Future<RunningApp> loginAs(WidgetTester tester, FakeAccount acc) async {
    final prefs = await resetClientState();
    final app = await launchApp(tester, prefs, acc);
    await tapKey(tester, 'login-google');
    await waitFor(tester, find.byKey(const Key('dashboard-content')), reason: 'dashboard de ${acc.name}');
    return app;
  }

  /// Seletor do dashboard -> troca a família ativa -> fecha a sheet (toque na barreira).
  Future<void> switchFamily(WidgetTester tester, String familyId) async {
    await tapKey(tester, 'household-selector');
    await tapKey(tester, 'switch-family-$familyId');
    await tester.tapAt(const Offset(5, 60));
    await settle(tester);
  }

  Matcher businessFailure(String reason) =>
      isA<BusinessFailure>().having((e) => e.reason, 'reason', reason);

  testWidgets('D. membro sem acesso a casa: memberships mostram a família, Rules negam o resto', (tester) async {
    await loginAs(tester, accBeto);
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    expect(uid, seedBetoUid);

    // Query de membro (array-contains) é aceita pelas Rules e volta vazia; a listagem completa é negada.
    final mine = await db
        .collection('families/$seedFamilyId/households')
        .where('accessUids', arrayContains: uid)
        .limit(50)
        .get();
    expect(mine.docs, isEmpty);
    await expectLater(
      db.collection('families/$seedFamilyId/households').limit(50).get(),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
    );
    await expectLater(
      db.doc('families/$seedFamilyId/billing/subscription').get(),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
    );
    // membro lê entitlement e members (Rules: isFamilyMember).
    expect((await db.doc('families/$seedFamilyId/billing/entitlement').get()).exists, isTrue);
    final members = await db
        .collection('families/$seedFamilyId/members')
        .where('status', isEqualTo: 'active')
        .limit(50)
        .get();
    expect(members.docs, hasLength(3));

    // UI: trocar para a família do dono, onde não há casa liberada -> /no-access (conteúdo).
    await switchFamily(tester, seedFamilyId);
    await waitFor(tester, find.text('Sem acesso a esta casa'), reason: '/no-access');
    expect(find.textContaining('ainda não vinculou'), findsOneWidget);
    // Família/Configurações seguem livres: o membro consegue sair pela tela de membros.
    await tapKey(tester, 'no-access-switch');
    expect(find.byKey(Key('switch-family-$seedFamilyId')), findsOneWidget);
  });

  testWidgets('F. família deleting: /no-access com texto de exclusão', (tester) async {
    await loginAs(tester, accBeto);
    const deleting = String.fromEnvironment('SEED_DELETING');
    await switchFamily(tester, deleting);
    await waitFor(tester, find.text('Sem acesso a esta casa'), reason: '/no-access (deleting)');
    expect(find.textContaining('sendo excluída'), findsOneWidget);
    // leaveFamily é permitido pelo servidor mesmo assim (sair nunca é bloqueado).
    final out = await realInvoker()('leaveFamily', {'familyId': deleting});
    expect(out['ok'], true);
  });

  testWidgets('E. família frozen: banner, leitura, e sair da família congelada', (tester) async {
    await loginAs(tester, accAna);
    const frozen = String.fromEnvironment('SEED_FROZEN');
    await switchFamily(tester, frozen);
    await waitFor(tester, find.byKey(const Key('frozen-banner')), reason: 'banner frozen');
    expect(find.textContaining('Somente leitura'), findsWidgets);
    expect(find.textContaining('Exclusão em'), findsOneWidget);
    final db = FirebaseFirestore.instance;
    // Leitura continua funcionando em frozen.
    expect((await db.collection('families/$frozen/households').where('accessUids', arrayContains: seedAnaUid).get()).docs,
        hasLength(1));

    await tapKey(tester, 'nav-family');
    await tapKey(tester, 'go-members');
    await waitFor(tester, find.text('Ana Teste (você)'));
    await tapKey(tester, 'leave-family');
    await tester.tap(find.widgetWithText(FilledButton, 'Sair da família'));
    await settle(tester, ms: 1500);
    final left = await db.collection('users/$seedAnaUid/memberships').get(const GetOptions(source: Source.server));
    expect(left.docs.map((d) => d.id), isNot(contains(frozen)));
  });

  testWidgets('B. owner em plano Família: casas, limites, acesso por casa, remover membro', (tester) async {
    await loginAs(tester, accDono);
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final invoke = realInvoker();

    // Hub: plano pago e uso vindo do servidor.
    await tapKey(tester, 'nav-family');
    await waitFor(tester, find.text('3 de 4 pessoas'), reason: 'uso de membros');
    expect(find.text('2 de 3 casas'), findsOneWidget);
    expect(find.byKey(const Key('see-plans')), findsNothing);

    // Casas: owner lista todas (query sem where), cria a 3ª pela Function real.
    await tapKey(tester, 'go-households');
    await waitFor(tester, find.text('Casa Praia'));
    expect(find.text('Casa Principal'), findsWidgets);
    await tapKey(tester, 'add-household');
    await tester.enterText(find.byType(TextField), 'Casa Sítio');
    await tester.tap(find.text('Criar'));
    await waitFor(tester, find.text('Casa criada.'), reason: 'createHousehold real');
    await waitFor(tester, find.text('Casa Sítio'));

    // Limite do plano (3/3): UI avisa sem chamar; servidor recusa com reason.
    await waitGone(tester, find.byType(SnackBar));
    await tester.tap(find.byKey(const Key('add-household')));
    await waitFor(tester, find.text('O limite de casas do plano foi atingido.'));
    await expectLater(
      invoke('createHousehold', {'familyId': seedFamilyId, 'name': 'Excedente'}),
      throwsA(businessFailure('PLAN_LIMIT_HOUSEHOLDS')),
    );

    await waitGone(tester, find.byType(SnackBar));
    // Renomear (update direto nas Rules reais: name + updatedAt serverTimestamp).
    await tester.tap(find.byKey(Key('household-menu-$seedH2')));
    await settle(tester);
    await tester.tap(find.text('Renomear'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Casa da Praia');
    await tester.tap(find.text('Salvar'));
    await waitFor(tester, find.text('Casa da Praia'), reason: 'rename refletido pelo stream');
    final renamed = await db.doc('families/$seedFamilyId/households/$seedH2').get(const GetOptions(source: Source.server));
    expect(renamed.data()!['name'], 'Casa da Praia');

    await waitGone(tester, find.byType(SnackBar));
    // Excluir a casa nova (soft delete) via deleteHousehold real.
    final sitio = (await db.collection('families/$seedFamilyId/households').get())
        .docs
        .firstWhere((d) => d.data()['name'] == 'Casa Sítio');
    await tester.tap(find.byKey(Key('household-menu-${sitio.id}')));
    await settle(tester);
    await tester.tap(find.text('Excluir'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await waitFor(tester, find.text('Casa excluída.'), reason: 'deleteHousehold real');
    await waitGone(tester, find.text('Casa Sítio'));
    final deleted = await db.doc('families/$seedFamilyId/households/${sitio.id}').get(const GetOptions(source: Source.server));
    expect(deleted.data()!['deletedAt'], isNotNull);
    expect(deleted.data()!['accessUids'], isEmpty);

    await waitGone(tester, find.byType(SnackBar));
    // Membros + acesso por casa (setHouseholdAccess real).
    await tapKey(tester, 'nav-family');
    await tapKey(tester, 'go-members');
    await waitFor(tester, find.text('Beto Teste'));
    expect(find.text('Dono Teste (você)'), findsOneWidget);
    expect(find.text('Ana Teste'), findsOneWidget);
    await tester.tap(find.byKey(Key('member-menu-$seedBetoUid')));
    await settle(tester);
    await tester.tap(find.text('Acesso às casas'));
    await settle(tester);
    await waitFor(tester, find.text('Acesso de Beto Teste'));
    await tester.tap(find.descendant(of: find.byKey(Key('access-$seedH2')), matching: find.text('Participante')));
    await settle(tester, ms: 2000);
    var h2 = await db.doc('families/$seedFamilyId/households/$seedH2').get(const GetOptions(source: Source.server));
    expect(h2.data()!['accessUids'], contains(seedBetoUid));
    expect((h2.data()!['access'] as Map)[seedBetoUid], 'member');
    await tester.tap(find.descendant(of: find.byKey(Key('access-$seedH2')), matching: find.text('Nenhum')));
    await settle(tester, ms: 2000);
    h2 = await db.doc('families/$seedFamilyId/households/$seedH2').get(const GetOptions(source: Source.server));
    expect(h2.data()!['accessUids'], isNot(contains(seedBetoUid)));
    await tester.tapAt(const Offset(5, 60)); // fecha a sheet
    await settle(tester);

    // Remover membro pela UI (removeMember real) e erros de negócio via reason.
    await tester.tap(find.byKey(Key('member-menu-$seedBetoUid')));
    await settle(tester);
    await tester.tap(find.text('Remover'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
    await waitFor(tester, find.text('Membro removido.'), reason: 'removeMember real');
    await waitGone(tester, find.text('Beto Teste'));
    final betoM = await db.doc('families/$seedFamilyId/members/$seedBetoUid').get(const GetOptions(source: Source.server));
    expect(betoM.data()!['status'], 'removed');
    await expectLater(
      invoke('removeMember', {'familyId': seedFamilyId, 'targetUid': seedBetoUid}),
      completes, // idempotente
    );
    await expectLater(
      invoke('leaveFamily', {'familyId': seedFamilyId}),
      throwsA(businessFailure('OWNER_CANNOT_LEAVE')),
    );
    final fam = await db.doc('families/$seedFamilyId').get(const GetOptions(source: Source.server));
    expect(fam.data()!['memberCount'], 2);
    expect(fam.data()!['ownerId'], uid);
  });

  testWidgets('C. membro (Ana) numa família paga: só a casa liberada, sem gestão, e sai da família', (tester) async {
    await loginAs(tester, accAna);
    final db = FirebaseFirestore.instance;
    final invoke = realInvoker();

    await switchFamily(tester, seedFamilyId);
    // Seletor: só a casa H1 (query array-contains); H2 não aparece.
    await tapKey(tester, 'household-selector');
    await waitFor(tester, find.byKey(Key('switch-household-$seedH1')));
    expect(find.byKey(Key('switch-household-$seedH2')), findsNothing);
    await tester.tap(find.byKey(Key('switch-household-$seedH1')));
    await settle(tester);

    await tapKey(tester, 'nav-family');
    await waitFor(tester, find.text('2 de 4 pessoas'), reason: 'uso após remoções');
    expect(find.byKey(const Key('see-plans')), findsNothing);
    await tapKey(tester, 'go-households');
    await waitFor(tester, find.text('Casa Principal'));
    expect(find.text('Casa da Praia'), findsNothing);
    expect(find.byKey(const Key('add-household')), findsNothing);
    await tapKey(tester, 'nav-family');

    // Regras e Functions recusam gestão por membro.
    await expectLater(
      db.collection('families/$seedFamilyId/households').limit(50).get(),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
    );
    await expectLater(
      invoke('createHousehold', {'familyId': seedFamilyId, 'name': 'X'}),
      throwsA(businessFailure('NOT_OWNER')),
    );
    await expectLater(
      invoke('removeMember', {'familyId': seedFamilyId, 'targetUid': seedBetoUid}),
      throwsA(businessFailure('NOT_OWNER')),
    );

    await tapKey(tester, 'go-members');
    await waitFor(tester, find.text('Ana Teste (você)'));
    expect(find.text('Dono Teste'), findsOneWidget);
    expect(find.byKey(const Key('invite-button')), findsNothing);
    await tapKey(tester, 'leave-family');
    await tester.tap(find.widgetWithText(FilledButton, 'Sair da família'));
    await settle(tester, ms: 2000);
    final ms = await db.collection('users/$seedAnaUid/memberships').get(const GetOptions(source: Source.server));
    expect(ms.docs.map((d) => d.id), isNot(contains(seedFamilyId)));
    // Sem mais acesso: ler a família (antes permitido a membro) agora é negado pelas Rules.
    await expectLater(
      db.doc('families/$seedFamilyId').get(const GetOptions(source: Source.server)),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
    );
  });
}
