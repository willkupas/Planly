import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/app/app.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/auth/application/auth_providers.dart';

import 'support/fake_auth_repository.dart';

Future<void> pumpApp(WidgetTester tester, FakeAuthRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: const PlanlyApp(),
    ),
  );
}

void main() {
  testWidgets('sessão restaurada abre o dashboard em pt-BR', (tester) async {
    await pumpApp(tester, FakeAuthRepository(initialUser: testUser));
    await tester.pumpAndSettle();

    expect(find.text('Início'), findsOneWidget);
    expect(find.byKey(const Key('login-google')), findsNothing);
  });

  testWidgets('splash enquanto a sessão resolve, depois login', (tester) async {
    final repo = FakeAuthRepository(emitInitial: false);
    await pumpApp(tester, repo);
    await tester.pump();
    expect(find.bySemanticsLabel('Carregando'), findsOneWidget);

    repo.resolve();
    await tester.pumpAndSettle();
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('fluxo splash -> login -> home -> logout -> login', (tester) async {
    final repo = FakeAuthRepository();
    await pumpApp(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Entrar com Google'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(repo.signInCalls, 1);
    expect(find.text('Início'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(repo.signOutCalls, 1);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('login mostra loading e bloqueia toque duplo', (tester) async {
    final repo = FakeAuthRepository()..signInGate = Completer<void>();
    await pumpApp(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pump();
    expect(find.text('Entrando…'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('login-google'))).onPressed, isNull);

    repo.signInGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Início'), findsOneWidget);
    expect(repo.signInCalls, 1);
  });

  testWidgets('erro de rede (offline) mostra mensagem amigável e permite tentar de novo',
      (tester) async {
    final repo = FakeAuthRepository()..nextSignInFailure = const NetworkFailure();
    await pumpApp(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão. Verifique sua internet e tente de novo.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(find.text('Início'), findsOneWidget);
  });

  testWidgets('cancelar o login não mostra erro', (tester) async {
    final repo = FakeAuthRepository()..nextSignInFailure = const CancelledFailure();
    await pumpApp(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.textContaining('Algo deu errado'), findsNothing);
  });
}
