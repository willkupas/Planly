import 'dart:ui';

import 'package:planly/features/reminders/domain/notification_gateway.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Textos das notificações e dos canais (fora de widgets: sem `BuildContext`).
abstract class ReminderTexts {
  NotificationChannelTexts get channels;

  /// Corpo curto do lembrete. [scheduledAt] e [fireAt] em UTC; a conversão para o fuso do
  /// aparelho é feita aqui.
  String body(DateTime scheduledAt, DateTime fireAt);
}

String _two(int n) => n.toString().padLeft(2, '0');

String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// pt-BR (idioma inicial). Quando houver mais idiomas, resolver o locale do aparelho aqui.
class L10nReminderTexts implements ReminderTexts {
  L10nReminderTexts([Locale locale = const Locale('pt')]) : _l10n = lookupAppLocalizations(locale);

  final AppLocalizations _l10n;

  @override
  NotificationChannelTexts get channels => NotificationChannelTexts(
        remindersName: _l10n.channelRemindersName,
        remindersDescription: _l10n.channelRemindersDescription,
        activityName: _l10n.channelActivityName,
        activityDescription: _l10n.channelActivityDescription,
        accountName: _l10n.channelAccountName,
        accountDescription: _l10n.channelAccountDescription,
      );

  @override
  String body(DateTime scheduledAt, DateTime fireAt) {
    final s = scheduledAt.toLocal();
    final f = fireAt.toLocal();
    final sDay = DateTime(s.year, s.month, s.day);
    final fDay = DateTime(f.year, f.month, f.day);
    final days = DateTime.utc(sDay.year, sDay.month, sDay.day)
        .difference(DateTime.utc(fDay.year, fDay.month, fDay.day))
        .inDays;
    if (days == 0) return _l10n.reminderBodyToday(_time(s));
    if (days == 1) return _l10n.reminderBodyTomorrow(_time(s));
    return _l10n.reminderBodyDate('${_two(s.day)}/${_two(s.month)}', _time(s));
  }
}
