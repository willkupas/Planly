import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/app/app.dart';
import 'package:planly/core/connectivity/connectivity_provider.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/core/sync/write_failure_center.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/features/lists/data/firestore_list_repository.dart';
import 'package:planly/l10n/app_localizations.dart';

import 'support/harness.dart';

Widget _host(Widget child, {bool online = true}) => ProviderScope(
      overrides: [isOnlineProvider.overrideWithValue(online)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt', 'BR'),
        home: Scaffold(body: Center(child: child)),
      ),
    );

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PlanlyApp)));

void main() {
  group('SyncIndicator', () {
    testWidgets('offline com escrita pendente: "Salvo neste dispositivo"', (tester) async {
      await tester.pumpWidget(_host(
        const SyncIndicator(meta: SyncMeta(hasPendingWrites: true, isFromCache: true)),
        online: false,
      ));
      expect(find.text('Salvo neste dispositivo'), findsOneWidget);
    });

    testWidgets('online com escrita pendente: "Sincronizando…"', (tester) async {
      await tester.pumpWidget(_host(const SyncIndicator(meta: SyncMeta(hasPendingWrites: true))));
      expect(find.text('Sincronizando…'), findsOneWidget);
    });

    testWidgets('confirmado pelo servidor: "Sincronizado" e some depois de ~2 s', (tester) async {
      await tester.pumpWidget(_host(const SyncIndicator(meta: SyncMeta())));
      expect(find.text('Sincronizado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Sincronizado'), findsNothing);
    });

    testWidgets('sem pendências, do cache e sem rede: "Offline"', (tester) async {
      await tester.pumpWidget(_host(const SyncIndicator(meta: SyncMeta(isFromCache: true)), online: false));
      expect(find.text('Offline'), findsOneWidget);
    });
  });

  group('escritas rejeitadas (app)', () {
    Future<TestApp> ownerApp() async {
      final app = await TestApp.create();
      app.backend.seedOwnerFree();
      return app;
    }

    Future<void> createTask(WidgetTester tester, String title) async {
      await tester.tap(find.byKey(const Key('fab-add-task')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quick-add-field')), title);
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick-add-submit')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    }

    testWidgets('tarefa recusada ao sincronizar: aviso global, detalhe e "Descartar"', (tester) async {
      final app = await ownerApp();
      app.tasks.ackFailure = const PermissionDeniedFailure();
      await app.pump(tester);
      expect(find.byKey(const Key('write-failures-banner')), findsNothing);

      await createTask(tester, 'Vai falhar');
      await tester.pump(const Duration(seconds: 5)); // snackbar some
      await tester.pumpAndSettle();

      expect(find.text('1 alteração não foi sincronizada'), findsOneWidget);
      await tester.tap(find.byKey(const Key('write-failures-view')));
      await tester.pumpAndSettle();
      expect(find.text('Alterações não sincronizadas'), findsOneWidget);
      expect(find.text('Criar tarefa “Vai falhar”'), findsOneWidget);
      expect(find.text('Você não tem permissão para fazer isso.'), findsOneWidget);

      final id = _container(tester).read(writeFailureCenterProvider).single.id;
      await tester.tap(find.byKey(Key('write-failure-dismiss-$id')));
      await tester.pumpAndSettle();

      // a folha fecha sozinha e o banner some; a UI segue usável
      expect(find.text('Alterações não sincronizadas'), findsNothing);
      expect(find.byKey(const Key('write-failures-banner')), findsNothing);
      await tester.tap(find.byKey(const Key('fab-add-task')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quick-add-field')), findsOneWidget);
    });

    testWidgets('várias falhas: contador no plural e "Descartar tudo"', (tester) async {
      final app = await ownerApp();
      await app.pump(tester);
      final c = _container(tester);
      c.read(writeFailureCenterProvider.notifier)
        ..report(WriteKind.itemAdd, const PermissionDeniedFailure(), title: 'Leite')
        ..report(WriteKind.listRename, const NetworkFailure(), title: 'Mercado')
        ..report(WriteKind.itemReorder, const UnknownFailure());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('3 alterações não foram sincronizadas'), findsOneWidget);
      await tester.tap(find.byKey(const Key('write-failures-view')));
      await tester.pumpAndSettle();
      expect(find.text('Adicionar item “Leite”'), findsOneWidget);
      expect(find.text('Renomear lista para “Mercado”'), findsOneWidget);
      expect(find.text('Reordenar itens'), findsOneWidget);

      await tester.tap(find.byKey(const Key('write-failures-dismiss-all')));
      await tester.pumpAndSettle();
      expect(c.read(writeFailureCenterProvider), isEmpty);
      expect(find.byKey(const Key('write-failures-banner')), findsNothing);
    });

    testWidgets('sair da conta descarta os avisos da sessão', (tester) async {
      final app = await ownerApp();
      await app.pump(tester);
      final c = _container(tester);
      c.read(writeFailureCenterProvider.notifier).report(WriteKind.taskCreate, const UnknownFailure(), title: 'X');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();

      expect(app.auth.signOutCalls, 1);
      expect(c.read(writeFailureCenterProvider), isEmpty);
    });

    testWidgets('logout com escritas pendentes: aviso, "Cancelar" mantém e "Sair mesmo assim" sai', (tester) async {
      final app = await ownerApp();
      app.local.pending = true;
      await app.pump(tester);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();
      expect(find.text('Alterações não sincronizadas'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(app.auth.signOutCalls, 0);

      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair mesmo assim'));
      await tester.pumpAndSettle();
      expect(app.auth.signOutCalls, 1);
      expect(app.local.clearCalls, 1);
    });
  });

  group('commitOptimistic + canal de falhas (listas)', () {
    test('erro de Rules tardio (depois da tolerância) vai para onLateError', () async {
      final c = Completer<void>();
      Object? late;
      await commitOptimistic(c.future, onLateError: (e) => late = e); // volta sem ack (~2 s)
      expect(late, isNull);
      final err = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
      c.completeError(err);
      await Future<void>.delayed(Duration.zero);
      expect(late, err);
    });

    test('erro que chega dentro da tolerância volta ao chamador e NÃO duplica no canal', () async {
      Object? late;
      final err = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
      await expectLater(
        commitOptimistic(Future<void>.error(err), onLateError: (e) => late = e),
        throwsA(isA<PermissionDeniedFailure>()),
      );
      expect(late, isNull);
    });
  });
}
