import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';

import 'support/fake_auth_repository.dart';
import 'support/harness.dart';

/// Fluxo de sessão (T-011) com o dashboard da T-014 como destino pós-login.
void main() {
  Future<TestApp> seeded({FakeAuthRepository? auth}) async {
    final app = await TestApp.create(auth: auth);
    app.backend.seedOwnerFree();
    return app;
  }

  Future<void> logoutViaSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
  }

  testWidgets('sessão restaurada abre o dashboard em pt-BR', (tester) async {
    final app = await seeded();
    await app.pump(tester);

    expect(find.text('Minha casa'), findsOneWidget); // casa ativa no topo
    expect(find.text('Início'), findsOneWidget); // aba da navegação
    expect(find.byKey(const Key('login-google')), findsNothing);
  });

  testWidgets('splash enquanto a sessão resolve, depois login', (tester) async {
    final repo = FakeAuthRepository(emitInitial: false);
    final app = await TestApp.create(auth: repo);
    app.backend.seedOwnerFree();
    await app.pump(tester, settle: false); // a splash tem spinner: sem pumpAndSettle
    await tester.pump();
    expect(find.bySemanticsLabel('Carregando'), findsOneWidget);

    repo.resolve();
    await tester.pumpAndSettle();
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('fluxo login -> dashboard -> logout (settings) -> login', (tester) async {
    final repo = FakeAuthRepository();
    final app = await seeded(auth: repo);
    await app.pump(tester);
    expect(find.text('Entrar com Google'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(repo.signInCalls, 1);
    expect(find.text('Minha casa'), findsOneWidget);

    await logoutViaSettings(tester);
    expect(repo.signOutCalls, 1);
    expect(app.local.clearCalls, 1);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('login mostra loading e bloqueia toque duplo', (tester) async {
    final repo = FakeAuthRepository()..signInGate = Completer<void>();
    final app = await seeded(auth: repo);
    await app.pump(tester);

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pump();
    expect(find.text('Entrando…'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('login-google'))).onPressed, isNull);

    repo.signInGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Minha casa'), findsOneWidget);
    expect(repo.signInCalls, 1);
  });

  testWidgets('erro de rede (offline) mostra mensagem amigável e permite tentar de novo',
      (tester) async {
    final repo = FakeAuthRepository()..nextSignInFailure = const NetworkFailure();
    final app = await seeded(auth: repo);
    await app.pump(tester);

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão. Verifique sua internet e tente de novo.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(find.text('Minha casa'), findsOneWidget);
  });

  testWidgets('cancelar o login não mostra erro', (tester) async {
    final repo = FakeAuthRepository()..nextSignInFailure = const CancelledFailure();
    final app = await seeded(auth: repo);
    await app.pump(tester);

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.textContaining('Algo deu errado'), findsNothing);
  });
}
