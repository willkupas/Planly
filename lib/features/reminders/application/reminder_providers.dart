import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/core/time/clock.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/reminders/application/reminder_reconciler.dart';
import 'package:planly/features/reminders/application/reminder_texts.dart';
import 'package:planly/features/reminders/data/local_notification_gateway.dart';
import 'package:planly/features/reminders/domain/notification_gateway.dart';
import 'package:planly/features/reminders/domain/reminder_plan.dart';
import 'package:planly/features/tasks/application/task_providers.dart';

const remindersEnabledKey = 'reminders.enabled';
const reminderPermissionAskedKey = 'reminders.permissionAsked';

/// Plugin de notificações (testes sobrescrevem com um fake).
final notificationGatewayProvider = Provider<NotificationGateway>((ref) => LocalNotificationGateway());

final reminderTextsProvider = Provider<ReminderTexts>((ref) => L10nReminderTexts());

/// Preferência local (por aparelho) que liga/desliga todos os lembretes. Padrão: ligado.
class RemindersEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(remindersEnabledKey) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(remindersEnabledKey, value);
  }
}

final remindersEnabledProvider =
    NotifierProvider<RemindersEnabledNotifier, bool>(RemindersEnabledNotifier.new);

Future<void> _ensureGatewayReady(Ref ref) =>
    ref.read(notificationGatewayProvider).init(ref.read(reminderTextsProvider).channels);

final reminderReconcilerProvider = Provider<ReminderReconciler>((ref) {
  return ReminderReconciler(
    gateway: ref.watch(notificationGatewayProvider),
    texts: ref.watch(reminderTextsProvider),
    clock: ref.watch(clockProvider),
    ready: () => _ensureGatewayReady(ref),
  );
});

/// Observa as tarefas da casa ativa e mantém as notificações locais em sincronia (criar,
/// editar, concluir, excluir e reatribuir são cobertos só por reconciliação do stream).
///
/// Sem usuário ou com lembretes desligados: cancela tudo. Sem contexto ativo ainda: não mexe
/// no que já está agendado. Trocar de casa reconcilia com as tarefas da nova casa.
final reminderSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUidProvider);
  final scope = ref.watch(taskScopeProvider);
  final enabled = ref.watch(remindersEnabledProvider);
  final reconciler = ref.watch(reminderReconcilerProvider);

  if (uid == null || !enabled) {
    unawaited(reconciler.cancelAll());
    return;
  }
  if (scope == null) return;

  final clock = ref.read(clockProvider);
  final sub = ref.watch(taskRepositoryProvider).watchScheduled(scope).listen(
    (snap) {
      unawaited(reconciler.reconcile(computeReminderPlans(
        tasks: snap.items,
        familyId: scope.familyId,
        householdId: scope.householdId,
        uid: uid,
        now: clock(),
      )));
    },
    // Erro de stream (offline sem cache, Rules): mantém o que já está agendado.
    onError: (Object e) => debugPrint('Lembretes: stream de tarefas indisponível'),
  );
  ref.onDispose(sub.cancel);
});

/// Estado da permissão do sistema + se já pedimos (depois de negar, o Android pode não
/// mostrar o diálogo de novo: a UI oferece os ajustes do sistema).
class ReminderPermissionState {
  const ReminderPermissionState({required this.permission, required this.asked});

  final NotificationPermission permission;
  final bool asked;

  bool get granted => permission == NotificationPermission.granted;
}

class ReminderPermissionNotifier extends AsyncNotifier<ReminderPermissionState> {
  NotificationGateway get _gateway => ref.read(notificationGatewayProvider);

  bool get _asked => ref.read(sharedPreferencesProvider).getBool(reminderPermissionAskedKey) ?? false;

  @override
  Future<ReminderPermissionState> build() async {
    final permission = await _read();
    return ReminderPermissionState(permission: permission, asked: _asked);
  }

  Future<NotificationPermission> _read() async {
    try {
      await _ensureGatewayReady(ref);
      return await _gateway.permission();
    } catch (e) {
      debugPrint('Lembretes: permissão indisponível');
      return NotificationPermission.denied;
    }
  }

  /// Relê o estado (ao voltar dos ajustes do sistema).
  Future<void> refresh() async {
    final permission = await _read();
    if (!ref.mounted) return;
    state = AsyncData(ReminderPermissionState(permission: permission, asked: _asked));
  }

  /// Pede a permissão (a UI explica antes). Devolve o resultado.
  Future<NotificationPermission> request() async {
    await ref.read(sharedPreferencesProvider).setBool(reminderPermissionAskedKey, true);
    var result = NotificationPermission.denied;
    try {
      await _ensureGatewayReady(ref);
      result = await _gateway.requestPermission();
    } catch (e) {
      debugPrint('Lembretes: falha ao pedir permissão');
    }
    if (ref.mounted) state = AsyncData(ReminderPermissionState(permission: result, asked: true));
    return result;
  }

  Future<void> openSystemSettings() async {
    try {
      await _gateway.openSystemSettings();
    } catch (e) {
      debugPrint('Lembretes: falha ao abrir ajustes');
    }
  }
}

final reminderPermissionProvider =
    AsyncNotifierProvider<ReminderPermissionNotifier, ReminderPermissionState>(ReminderPermissionNotifier.new);

/// Toque numa notificação aguardando navegação (consumido por `reminderNavigationProvider`,
/// que espera a sessão ficar pronta).
class ReminderOpenRequestNotifier extends Notifier<ReminderPayload?> {
  @override
  ReminderPayload? build() => null;

  void request(ReminderPayload payload) => state = payload;

  void clear() => state = null;
}

final reminderOpenRequestProvider =
    NotifierProvider<ReminderOpenRequestNotifier, ReminderPayload?>(ReminderOpenRequestNotifier.new);

/// Liga os toques em notificações (app aberto e cold start) ao [reminderOpenRequestProvider].
final reminderTapProvider = Provider<void>((ref) {
  final gateway = ref.watch(notificationGatewayProvider);
  final notifier = ref.read(reminderOpenRequestProvider.notifier);

  void handle(String? raw) {
    final payload = ReminderPayload.parse(raw);
    if (payload != null) notifier.request(payload);
  }

  final sub = gateway.taps.listen(handle);
  ref.onDispose(sub.cancel);
  unawaited(() async {
    try {
      await _ensureGatewayReady(ref);
      handle(await gateway.launchPayload());
    } catch (e) {
      debugPrint('Lembretes: falha ao ler abertura por notificação');
    }
  }());
});
