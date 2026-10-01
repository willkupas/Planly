import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:planly/features/notifications/application/push_texts.dart';
import 'package:planly/features/notifications/domain/push_event.dart';
import 'package:planly/features/reminders/application/reminder_texts.dart';
import 'package:planly/features/reminders/data/local_notification_gateway.dart';

/// Mensagens só de dados chegam aqui com o app em segundo plano ou encerrado (isolate próprio):
/// monta o texto pelo ARB e mostra a notificação local. O toque é tratado quando o app abre
/// (`launchPayload`/`taps`). Nenhum dado de usuário é logado.
@pragma('vm:entry-point')
Future<void> planlyPushBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  final event = PushEvent.fromData(message.data);
  if (event == null) return;
  final gateway = LocalNotificationGateway();
  await gateway.init(L10nReminderTexts().channels);
  await showPushEvent(gateway, L10nPushTexts(), event);
}

/// Registra o handler de segundo plano (chamar uma vez no `bootstrap`).
void registerPushBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(planlyPushBackgroundHandler);
}
