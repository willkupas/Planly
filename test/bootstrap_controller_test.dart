import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/connectivity/connectivity_provider.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/core/time/device_timezone.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/auth/application/user_profile_providers.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/family/application/bootstrap_controller.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late ProviderContainer container;

  Future<void> setUpContainer({bool online = true, List<Duration> delays = const []}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    backend = FakeBackend()..seedNewUser();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(initialUser: testUser)),
        familyRepositoryProvider.overrideWithValue(backend),
        userProfileRepositoryProvider.overrideWithValue(backend),
        sharedPreferencesProvider.overrideWithValue(prefs),
        connectivityProvider.overrideWith((ref) => Stream.value(online)),
        deviceTimezoneProvider.overrideWithValue(() async => null),
        bootstrapRetryDelaysProvider.overrideWithValue(delays),
      ],
    );
    addTearDown(container.dispose);
    // mantém vivos os providers que o controller lê e deixa auth/conectividade resolverem
    container.listen(currentUserProvider, (_, _) {});
    container.listen(isOnlineProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('sucesso: seleciona família/casa devolvidas e faz upsert do perfil', () async {
    await setUpContainer();
    await container.read(bootstrapControllerProvider.notifier).run();

    expect(container.read(bootstrapControllerProvider).hasError, isFalse);
    expect(container.read(activeContextProvider),
        const ActiveContext(familyId: 'f-new', householdId: 'h-new'));
    expect(backend.calls, ['bootstrapUser', 'upsertClientFields']);
    expect(backend.lastBootstrapTimezone, isNull); // sem timezone disponível: não envia
  });

  test('falhas de rede são repetidas com backoff até dar certo', () async {
    await setUpContainer(delays: const [Duration.zero, Duration.zero]);
    backend.bootstrapFailures.addAll(const [NetworkFailure(), NetworkFailure()]);
    await container.read(bootstrapControllerProvider.notifier).run();

    expect(backend.calls.where((c) => c == 'bootstrapUser'), hasLength(3));
    expect(container.read(bootstrapControllerProvider).hasError, isFalse);
  });

  test('esgotadas as tentativas, expõe o NetworkFailure', () async {
    await setUpContainer(delays: const [Duration.zero]);
    backend.bootstrapFailures.addAll(const [NetworkFailure(), NetworkFailure(), NetworkFailure()]);
    await container.read(bootstrapControllerProvider.notifier).run();

    expect(backend.calls.where((c) => c == 'bootstrapUser'), hasLength(2));
    expect(container.read(bootstrapControllerProvider).error, isA<NetworkFailure>());
  });

  test('erro de regra (RATE_LIMITED) não é repetido automaticamente', () async {
    await setUpContainer(delays: const [Duration.zero, Duration.zero]);
    backend.bootstrapFailures.add(const BusinessFailure('RATE_LIMITED'));
    await container.read(bootstrapControllerProvider.notifier).run();

    expect(backend.calls.where((c) => c == 'bootstrapUser'), hasLength(1));
    expect(container.read(bootstrapControllerProvider).error, const BusinessFailure('RATE_LIMITED'));
  });

  test('offline: não chama a Function', () async {
    await setUpContainer(online: false);
    await container.read(bootstrapControllerProvider.notifier).run();
    expect(backend.calls, isEmpty);
    expect(container.read(bootstrapControllerProvider).error, isA<NetworkFailure>());
  });
}
