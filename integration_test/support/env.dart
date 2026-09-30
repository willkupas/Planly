import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/app/app.dart';
import 'package:planly/core/firebase/callable_invoker.dart';
import 'package:planly/core/firebase/emulators.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/auth/data/auth_provider_adapter.dart';
import 'package:planly/features/auth/data/firebase_auth_repository.dart';
import 'package:planly/features/auth/domain/auth_provider_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ids criados por `integration_test/seed/seed.mjs` (vêm por `--dart-define`, ver
/// docs/testing/integracao-emulador.md). Nenhum é segredo: só existem no emulador.
const seedFamilyId = String.fromEnvironment('SEED_FAMILY');
const seedH1 = String.fromEnvironment('SEED_H1');
const seedH2 = String.fromEnvironment('SEED_H2');
const seedAnaUid = String.fromEnvironment('SEED_ANA');
const seedBetoUid = String.fromEnvironment('SEED_BETO');

/// Contas fictícias: o Auth Emulator aceita um `idToken` JSON sem assinatura.
class FakeAccount {
  const FakeAccount(this.sub, this.name);
  final String sub;
  final String name;
  String get email => '${sub.replaceFirst('uid-teste-', '')}@exemplo.test';

  String get idToken =>
      jsonEncode({'sub': sub, 'email': email, 'email_verified': true, 'name': name});
}

const accNovo = FakeAccount('uid-teste-novo', 'Novo Teste');
const accDono = FakeAccount('uid-teste-dono', 'Dono Teste');
const accAna = FakeAccount('uid-teste-ana', 'Ana Teste');
const accBeto = FakeAccount('uid-teste-beto', 'Beto Teste');

/// Substitui o Google Sign-In: devolve uma credencial Google "falsa" da conta escolhida.
class FakeGoogleAdapter implements AuthProviderAdapter {
  FakeGoogleAdapter(this.current);
  FakeAccount Function() current;

  @override
  AuthProviderId get id => AuthProviderId.google;

  @override
  Future<AuthCredential> obtainCredential() async =>
      GoogleAuthProvider.credential(idToken: current().idToken);

  @override
  Future<void> signOut() async {}
}

bool _initialized = false;

/// Inicializa o Firebase apontando para o Emulator Suite (mesmo caminho do `bootstrap()` dev,
/// sem App Check/Crashlytics/Analytics).
Future<void> initEmulatorFirebase() async {
  if (_initialized) return;
  await Firebase.initializeApp();
  await connectToFirebaseEmulators();
  _initialized = true;
}

/// Estado limpo entre testes: sem sessão e sem cache/preferências de sessões anteriores.
Future<SharedPreferences> resetClientState() async {
  await FirebaseAuth.instance.signOut();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  try {
    await FirebaseFirestore.instance.terminate();
    await FirebaseFirestore.instance.clearPersistence();
  } catch (_) {}
  return prefs;
}

class RunningApp {
  RunningApp(this.tester, this.container, this.account);
  final WidgetTester tester;
  final ProviderContainer container;
  final FakeAccount Function() account;
}

/// Sobe o app REAL (Firestore/Functions/Auth reais no emulador); só o botão do Google é
/// trocado por `FakeGoogleAdapter`.
Future<RunningApp> launchApp(WidgetTester tester, SharedPreferences prefs, FakeAccount acc) async {
  var current = acc;
  final adapter = FakeGoogleAdapter(() => current);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWith(
          (ref) => FirebaseAuthRepository(auth: ref.watch(firebaseAuthProvider), adapters: [adapter]),
        ),
      ],
      child: const PlanlyApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  final container = ProviderScope.containerOf(tester.element(find.byType(PlanlyApp)));
  return RunningApp(tester, container, () => current);
}

/// Polling com tempo real (rede de verdade): `pumpAndSettle` não serve com streams vivos.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('timeout esperando ${reason ?? finder}');
}

Future<void> waitGone(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('timeout esperando sumir $finder');
}

Future<void> settle(WidgetTester tester, {int ms = 600}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await waitFor(tester, f);
  await tester.tap(f);
  await settle(tester);
}

/// Invoker real das Functions no emulador (mesmo usado pelo app).
CallableInvoker realInvoker() => firebaseCallableInvoker(FirebaseFunctions.instanceFor(region: functionsRegion));
