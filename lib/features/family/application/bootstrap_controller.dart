import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/connectivity/online_only.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/time/device_timezone.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/auth/application/user_profile_providers.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/family/application/family_providers.dart';

/// Esperas entre tentativas automáticas de `bootstrapUser` (só para falhas de rede).
/// Nos testes: override com lista vazia.
final bootstrapRetryDelaysProvider = Provider<List<Duration>>(
  (ref) => const [Duration(seconds: 1), Duration(seconds: 3)],
);

/// Locale inicial enviado ao backend (i18n: só pt-BR por enquanto).
const _clientLocale = 'pt-BR';

/// Primeiro acesso (spec flutter-app §1 #3, §8.2): chama `bootstrapUser` (online-only,
/// idempotente), escolhe a família/casa devolvidas como contexto ativo e sincroniza os campos
/// de perfil que o cliente pode escrever (pendência da T-011).
class BootstrapController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> run() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await ensureOnline(ref);
      final user = ref.read(currentUserProvider);
      final timezone = await ref.read(deviceTimezoneProvider)();
      final repo = ref.read(familyRepositoryProvider);

      final delays = ref.read(bootstrapRetryDelaysProvider);
      var attempt = 0;
      while (true) {
        try {
          final result = await repo.bootstrapUser(
            displayName: user?.displayName,
            locale: _clientLocale,
            timezone: timezone,
          );
          final context = ref.read(activeContextProvider.notifier);
          final householdId = result.householdId;
          if (householdId != null) {
            await context.selectHousehold(result.familyId, householdId);
          } else {
            await context.selectFamily(result.familyId);
          }
          await _syncProfile(user?.uid, user?.displayName, user?.photoUrl, timezone);
          state = const AsyncData(null);
          return;
        } on NetworkFailure {
          if (attempt >= delays.length) rethrow;
          await Future<void>.delayed(delays[attempt++]);
        }
      }
    } on AppFailure catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Best-effort: falha aqui nunca bloqueia o primeiro acesso.
  Future<void> _syncProfile(String? uid, String? name, String? photoUrl, String? timezone) async {
    if (uid == null) return;
    try {
      await ref.read(userProfileRepositoryProvider).upsertClientFields(
            uid,
            displayName: name,
            photoUrl: photoUrl,
            locale: _clientLocale,
            timezone: timezone,
          );
    } on AppFailure {
      // ignora
    }
  }
}

final bootstrapControllerProvider =
    NotifierProvider<BootstrapController, AsyncValue<void>>(BootstrapController.new);
