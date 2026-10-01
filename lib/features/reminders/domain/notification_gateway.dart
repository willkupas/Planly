/// Estado da permissão de notificações do sistema (`POST_NOTIFICATIONS` no Android 13+).
enum NotificationPermission { granted, denied }

/// Textos dos canais Android (vêm do ARB; o gateway não tem texto fixo).
class NotificationChannelTexts {
  const NotificationChannelTexts({
    required this.remindersName,
    required this.remindersDescription,
    required this.activityName,
    required this.activityDescription,
    required this.accountName,
    required this.accountDescription,
  });

  final String remindersName;
  final String remindersDescription;
  final String activityName;
  final String activityDescription;
  final String accountName;
  final String accountDescription;
}

/// Notificação local a agendar (instante absoluto em UTC).
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAtUtc,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final DateTime fireAtUtc;
  final String payload;
}

/// Notificação imediata da atividade da casa (push de eventos compartilhados, T-023).
class ActivityNotification {
  const ActivityNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final String payload;
}

/// Abstração sobre o plugin de notificações locais (testes usam um fake).
abstract class NotificationGateway {
  /// Cria os canais e registra o callback de toque. Idempotente.
  Future<void> init(NotificationChannelTexts texts);

  Future<NotificationPermission> permission();

  /// Mostra o diálogo do sistema (Android 13+). Se já foi negado duas vezes, o sistema não
  /// mostra de novo: use [openSystemSettings].
  Future<NotificationPermission> requestPermission();

  Future<void> openSystemSettings();

  /// Ids das notificações agendadas (ainda não disparadas).
  Future<Set<int>> pendingIds();

  /// Agenda (ou substitui, mesmo id) um lembrete. Agendamento inexato permitido com o
  /// aparelho ocioso: sem `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`.
  Future<void> schedule(ScheduledReminder reminder);

  Future<void> cancel(int id);

  /// Mostra agora uma notificação no canal `household_activity` (mesmo id substitui).
  Future<void> showActivity(ActivityNotification notification);

  /// Payloads de toques em notificações com o app em execução.
  Stream<String> get taps;

  /// Payload da notificação que abriu o app (cold start), se houver.
  Future<String?> launchPayload();
}
