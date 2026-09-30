import 'package:flutter/material.dart';
import 'package:planly/features/activity/domain/activity_models.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Frase amigável do evento, só com os snapshots (`actorName`/`targetTitle`). O autor atual
/// aparece como "Você".
String activityEventText(
  AppLocalizations l10n,
  ActivityEvent e, {
  required String? currentUid,
}) {
  final actor = e.actorId == currentUid
      ? l10n.activityYou
      : (e.actorName.trim().isEmpty
            ? l10n.activitySomeone
            : e.actorName.trim());
  final title = e.targetTitle;
  return switch (e.type) {
    ActivityEventType.taskCreated => l10n.activityEventTaskCreated(
      actor,
      title,
    ),
    ActivityEventType.taskAssigned => l10n.activityEventTaskAssigned(
      actor,
      title,
    ),
    ActivityEventType.taskCompleted => l10n.activityEventTaskCompleted(
      actor,
      title,
    ),
    ActivityEventType.taskReopened => l10n.activityEventTaskReopened(
      actor,
      title,
    ),
    ActivityEventType.taskUpdated => l10n.activityEventTaskUpdated(
      actor,
      title,
    ),
    ActivityEventType.taskDeleted => l10n.activityEventTaskDeleted(
      actor,
      title,
    ),
    ActivityEventType.listCreated => l10n.activityEventListCreated(
      actor,
      title,
    ),
    ActivityEventType.listDeleted => l10n.activityEventListDeleted(
      actor,
      title,
    ),
    ActivityEventType.itemAdded => l10n.activityEventItemAdded(actor, title),
    ActivityEventType.itemCompleted => l10n.activityEventItemCompleted(
      actor,
      title,
    ),
    ActivityEventType.itemDeleted => l10n.activityEventItemDeleted(
      actor,
      title,
    ),
    ActivityEventType.memberJoined => l10n.activityEventMemberJoined(actor),
    ActivityEventType.memberLeft => l10n.activityEventMemberLeft(actor),
    ActivityEventType.householdCreated => l10n.activityEventHouseholdCreated(
      actor,
      title,
    ),
    ActivityEventType.unknown => l10n.activityEventUnknown(actor),
  };
}

IconData activityEventIcon(ActivityEventType type) => switch (type) {
  ActivityEventType.taskCreated ||
  ActivityEventType.listCreated => Icons.add_circle_outline,
  ActivityEventType.taskAssigned => Icons.person_add_alt_outlined,
  ActivityEventType.taskCompleted ||
  ActivityEventType.itemCompleted => Icons.check_circle_outline,
  ActivityEventType.taskReopened => Icons.replay,
  ActivityEventType.taskUpdated => Icons.edit_outlined,
  ActivityEventType.taskDeleted ||
  ActivityEventType.listDeleted ||
  ActivityEventType.itemDeleted => Icons.delete_outline,
  ActivityEventType.itemAdded => Icons.add_shopping_cart,
  ActivityEventType.memberJoined => Icons.login,
  ActivityEventType.memberLeft => Icons.logout,
  ActivityEventType.householdCreated => Icons.home_outlined,
  ActivityEventType.unknown => Icons.history,
};
