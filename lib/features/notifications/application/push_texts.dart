import 'dart:ui';

import 'package:planly/features/notifications/domain/push_event.dart';
import 'package:planly/features/reminders/domain/notification_gateway.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Título e corpo do push (montados no app via ARB; o payload não carrega texto).
typedef PushText = ({String title, String body});

abstract class PushTexts {
  PushText forType(PushEventType type);
}

/// pt-BR (idioma inicial). Funciona também no isolate de segundo plano (sem `BuildContext`).
class L10nPushTexts implements PushTexts {
  L10nPushTexts([Locale locale = const Locale('pt')]) : _l10n = lookupAppLocalizations(locale);

  final AppLocalizations _l10n;

  @override
  PushText forType(PushEventType type) => switch (type) {
        PushEventType.taskCreated => (title: _l10n.pushTaskCreatedTitle, body: _l10n.pushTaskCreatedBody),
        PushEventType.taskAssigned => (title: _l10n.pushTaskAssignedTitle, body: _l10n.pushTaskAssignedBody),
        PushEventType.taskCompleted => (title: _l10n.pushTaskCompletedTitle, body: _l10n.pushTaskCompletedBody),
        PushEventType.listItemAdded =>
          (title: _l10n.pushListItemAddedTitle, body: _l10n.pushListItemAddedBody),
      };
}

/// Mostra o evento como notificação local no canal `household_activity`.
Future<void> showPushEvent(NotificationGateway gateway, PushTexts texts, PushEvent event) {
  final t = texts.forType(event.type);
  return gateway.showActivity(ActivityNotification(
    id: event.notificationId,
    title: t.title,
    body: t.body,
    payload: event.encode(),
  ));
}
