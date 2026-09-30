import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:planly/features/reminders/domain/notification_gateway.dart';
import 'package:timezone/timezone.dart' as tz;

/// Ids dos canais Android (estáveis: o usuário pode ter configurado o som por canal).
abstract final class NotificationChannels {
  static const reminders = 'reminders';
  static const householdActivity = 'household_activity';
  static const account = 'account_plan';
}

/// Implementação com `flutter_local_notifications`. Android apenas (foco atual).
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  NotificationChannelTexts? _texts;
  Future<void>? _initFuture;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> init(NotificationChannelTexts texts) {
    return _initFuture ??= _init(texts).catchError((Object e) {
      _initFuture = null; // permite nova tentativa
      throw e;
    });
  }

  Future<void> _init(NotificationChannelTexts texts) async {
    _texts = texts;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p != null && p.isNotEmpty) _taps.add(p);
      },
    );
    final android = _android;
    if (android == null) return;
    await android.createNotificationChannel(AndroidNotificationChannel(
      NotificationChannels.reminders,
      texts.remindersName,
      description: texts.remindersDescription,
      importance: Importance.high,
    ));
    // Criados já; usados por tarefas futuras (push da casa, conta e plano).
    await android.createNotificationChannel(AndroidNotificationChannel(
      NotificationChannels.householdActivity,
      texts.activityName,
      description: texts.activityDescription,
      importance: Importance.defaultImportance,
    ));
    await android.createNotificationChannel(AndroidNotificationChannel(
      NotificationChannels.account,
      texts.accountName,
      description: texts.accountDescription,
      importance: Importance.defaultImportance,
    ));
  }

  @override
  Future<NotificationPermission> permission() async {
    final enabled = await _android?.areNotificationsEnabled();
    return enabled == true ? NotificationPermission.granted : NotificationPermission.denied;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    final granted = await _android?.requestNotificationsPermission();
    return granted == true ? NotificationPermission.granted : NotificationPermission.denied;
  }

  @override
  Future<void> openSystemSettings() async {
    await _android?.openAppNotificationSettings();
  }

  @override
  Future<Set<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final p in pending) p.id};
  }

  @override
  Future<void> schedule(ScheduledReminder r) {
    final texts = _texts;
    return _plugin.zonedSchedule(
      id: r.id,
      title: r.title,
      body: r.body,
      payload: r.payload,
      // Instante absoluto: UTC -> TZDateTime(UTC). Independe do fuso do aparelho, então
      // trocar de fuso não desloca o lembrete.
      scheduledDate: tz.TZDateTime.from(r.fireAtUtc.toUtc(), tz.UTC),
      // Inexato com Doze liberado: sem SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM (política da Play).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.reminders,
          texts?.remindersName ?? NotificationChannels.reminders,
          channelDescription: texts?.remindersDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<String?> launchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) return details?.notificationResponse?.payload;
    } catch (e) {
      debugPrint('Falha ao ler notificação de abertura');
    }
    return null;
  }
}
