import 'dart:async';

import 'package:planly/features/reminders/application/reminder_texts.dart';
import 'package:planly/features/reminders/domain/notification_gateway.dart';

/// Gateway em memória: registra o que foi agendado/cancelado.
class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway({this.permissionState = NotificationPermission.granted});

  NotificationPermission permissionState;

  /// Resultado do próximo `requestPermission` (simula o diálogo do sistema).
  NotificationPermission requestResult = NotificationPermission.granted;

  final scheduled = <int, ScheduledReminder>{};
  final scheduleCalls = <ScheduledReminder>[];
  final cancelCalls = <int>[];
  var initCalls = 0;
  var requestCalls = 0;
  var openSettingsCalls = 0;
  String? launch;

  /// Se true, `schedule` falha (plugin indisponível).
  bool failSchedule = false;

  final _taps = StreamController<String>.broadcast();

  void tap(String payload) => _taps.add(payload);

  @override
  Future<void> init(NotificationChannelTexts texts) async => initCalls++;

  @override
  Future<NotificationPermission> permission() async => permissionState;

  @override
  Future<NotificationPermission> requestPermission() async {
    requestCalls++;
    permissionState = requestResult;
    return requestResult;
  }

  @override
  Future<void> openSystemSettings() async => openSettingsCalls++;

  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();

  @override
  Future<void> schedule(ScheduledReminder reminder) async {
    if (failSchedule) throw StateError('falha simulada');
    scheduleCalls.add(reminder);
    scheduled[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls.add(id);
    scheduled.remove(id);
  }

  final shownActivity = <ActivityNotification>[];

  @override
  Future<void> showActivity(ActivityNotification notification) async => shownActivity.add(notification);

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async => launch;
}

/// Textos determinísticos (UTC) para testes de reconciliação.
class FakeReminderTexts implements ReminderTexts {
  @override
  NotificationChannelTexts get channels => const NotificationChannelTexts(
        remindersName: 'Lembretes',
        remindersDescription: 'd',
        activityName: 'Atividade da casa',
        activityDescription: 'd',
        accountName: 'Conta e plano',
        accountDescription: 'd',
      );

  @override
  String body(DateTime scheduledAt, DateTime fireAt) => 'as ${scheduledAt.toIso8601String()}';
}
