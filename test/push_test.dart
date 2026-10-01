import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/notifications/application/push_texts.dart';
import 'package:planly/features/notifications/data/firestore_device_repository.dart';
import 'package:planly/features/notifications/domain/push_event.dart';

import 'support/harness.dart';

const _event = PushEvent(type: PushEventType.taskCreated, familyId: 'f1', householdId: 'h1', targetId: 't1');

Map<String, dynamic> _data(PushEvent e) => {
      'type': e.type.wire,
      'familyId': e.familyId,
      'householdId': e.householdId,
      'targetId': e.targetId,
    };

void main() {
  group('PushEvent', () {
    test('fromData valida tipo e ids', () {
      expect(PushEvent.fromData(_data(_event)), _event);
      expect(PushEvent.fromData({..._data(_event), 'type': 'outro'}), isNull);
      expect(PushEvent.fromData({..._data(_event), 'targetId': ''}), isNull);
      expect(PushEvent.fromData({'type': 'task_created'}), isNull);
      expect(PushEvent.fromData({..._data(_event), 'familyId': 1}), isNull);
    });

    test('encode/parse de payload local; lixo e payload de lembrete são ignorados', () {
      for (final t in PushEventType.values) {
        final e = PushEvent(type: t, familyId: 'f', householdId: 'h', targetId: 'x1');
        expect(PushEvent.parse(e.encode()), e);
      }
      expect(PushEvent.parse(null), isNull);
      expect(PushEvent.parse('planly://task/x?f=1&h=2'), isNull);
      expect(PushEvent.parse('planly://event/task_created'), isNull);
      expect(PushEvent.parse('https://evil.example/event/task_created/x?f=1&h=2'), isNull);
    });

    test('id da notificação é estável por tipo/alvo (itens da mesma lista se substituem)', () {
      const a = PushEvent(type: PushEventType.listItemAdded, familyId: 'f', householdId: 'h', targetId: 'l1');
      const b = PushEvent(type: PushEventType.listItemAdded, familyId: 'f', householdId: 'h', targetId: 'l1');
      const c = PushEvent(type: PushEventType.listItemAdded, familyId: 'f', householdId: 'h', targetId: 'l2');
      expect(a.notificationId, b.notificationId);
      expect(a.notificationId, isNot(c.notificationId));
      expect(a.notificationId, greaterThanOrEqualTo(0));
    });

    test('textos vêm do ARB e não carregam conteúdo', () {
      final texts = L10nPushTexts();
      for (final t in PushEventType.values) {
        final x = texts.forType(t);
        expect(x.title, isNotEmpty);
        expect(x.body, isNotEmpty);
      }
      expect(texts.forType(PushEventType.taskCompleted).title, 'Tarefa concluída');
    });
  });

  group('FirestoreDeviceRepository', () {
    test('cria com fcmToken (nunca "token"), atualiza sem mexer em createdAt e remove', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreDeviceRepository(firestore: db);
      await repo.register(uid: 'u1', deviceId: 'd1', fcmToken: 'A', locale: 'pt-BR', timezone: 'America/Sao_Paulo');

      var snap = await db.doc('users/u1/devices/d1').get();
      expect(snap.data()!.keys.toSet(),
          {'fcmToken', 'platform', 'lastSeenAt', 'createdAt', 'locale', 'timezone'});
      expect(snap.get('fcmToken'), 'A');
      expect(snap.get('platform'), 'android');
      final created = snap.get('createdAt') as Timestamp;

      await repo.register(uid: 'u1', deviceId: 'd1', fcmToken: 'B');
      snap = await db.doc('users/u1/devices/d1').get();
      expect(snap.get('fcmToken'), 'B');
      expect(snap.get('createdAt'), created);
      expect(snap.data()!.containsKey('token'), isFalse);

      await repo.remove(uid: 'u1', deviceId: 'd1');
      expect((await db.doc('users/u1/devices/d1').get()).exists, isFalse);
      await repo.remove(uid: 'u1', deviceId: 'd1'); // idempotente
    });
  });

  group('integração com o app', () {
    Future<TestApp> seeded() async {
      final app = await TestApp.create();
      app.backend.seedOwnerFree();
      return app;
    }

    testWidgets('registra o token no login e atualiza em onTokenRefresh', (tester) async {
      final app = await seeded();
      await app.pump(tester);
      expect(app.devices.registerCalls, ['tok-1']);
      expect(app.devices.devices.length, 1);
      expect(app.devices.devices.keys.single, startsWith('u1/'));

      app.push.refreshToken('tok-2');
      await tester.pumpAndSettle();
      expect(app.devices.registerCalls, ['tok-1', 'tok-2']);
      expect(app.devices.devices.values.single, 'tok-2');
      // Mesmo deviceId (doc único por instalação).
      expect(app.devices.devices.length, 1);
    });

    testWidgets('sem token disponível não registra nem quebra', (tester) async {
      final app = await seeded();
      app.push.currentToken = null;
      await app.pump(tester);
      expect(app.devices.registerCalls, isEmpty);
    });

    testWidgets('logout remove o device e invalida o token', (tester) async {
      final app = await seeded();
      await app.pump(tester);
      expect(app.devices.devices, isNotEmpty);

      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();

      expect(app.devices.devices, isEmpty);
      expect(app.devices.removeCalls, 1);
      expect(app.push.deleteTokenCalls, 1);
      expect(app.auth.signOutCalls, 1);
    });

    testWidgets('mensagem em primeiro plano vira notificação local com texto do ARB', (tester) async {
      final app = await seeded();
      await app.pump(tester);

      app.push.receive(_data(_event));
      await tester.pumpAndSettle();
      final shown = app.notifications.shownActivity.single;
      expect(shown.title, 'Nova tarefa');
      expect(shown.id, _event.notificationId);
      expect(PushEvent.parse(shown.payload), _event);

      // Dados inválidos são ignorados.
      app.push.receive({'type': 'task_created'});
      await tester.pumpAndSettle();
      expect(app.notifications.shownActivity, hasLength(1));
    });

    testWidgets('toque na notificação abre a tarefa (mesma casa)', (tester) async {
      final app = await seeded();
      await app.pump(tester);

      app.notifications.tap(_event.encode());
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      expect(GoRouter.of(ctx).state.matchedLocation, '/home/task/t1');
    });

    testWidgets('evento de item abre a lista', (tester) async {
      final app = await seeded();
      await app.pump(tester);

      const e = PushEvent(type: PushEventType.listItemAdded, familyId: 'f1', householdId: 'h1', targetId: 'l9');
      app.notifications.tap(e.encode());
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      expect(GoRouter.of(ctx).state.matchedLocation, '/lists/l9');
    });

    testWidgets('toque de outra casa ajusta o contexto ativo antes de navegar', (tester) async {
      final app = await seeded();
      app.backend.householdsLive('f1').set(HouseholdsSnapshot([
        Household(id: 'h1', name: 'Minha casa'),
        Household(id: 'h2', name: 'Praia'),
      ]));
      await app.pump(tester);

      const e = PushEvent(type: PushEventType.taskAssigned, familyId: 'f1', householdId: 'h2', targetId: 't7');
      app.push.open(_data(e));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(Scaffold).first);
      expect(GoRouter.of(ctx).state.matchedLocation, '/home/task/t7');
      final container = ProviderScope.containerOf(ctx);
      expect(container.read(activeContextProvider).householdId, 'h2');
    });

    testWidgets('cold start: mensagem inicial abre o destino depois da sessão pronta', (tester) async {
      final app = await seeded();
      app.push.initial = _data(_event);
      await app.pump(tester);
      final ctx = tester.element(find.byType(Scaffold).first);
      expect(GoRouter.of(ctx).state.matchedLocation, '/home/task/t1');
    });

    testWidgets('payload de lembrete de tarefa não é tratado como push', (tester) async {
      final app = await seeded();
      await app.pump(tester);
      app.notifications.tap('planly://task/x?f=f1&h=h1');
      await tester.pumpAndSettle();
      expect(app.notifications.shownActivity, isEmpty);
    });
  });
}

