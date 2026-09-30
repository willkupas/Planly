import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:planly/core/time/clock.dart';
import 'package:planly/features/reminders/application/reminder_texts.dart';
import 'package:planly/features/reminders/domain/notification_gateway.dart';
import 'package:planly/features/reminders/domain/reminder_plan.dart';

/// Reconcilia os lembretes desejados ([ReminderPlan]) com as notificações agendadas no
/// [NotificationGateway]: agenda novos/alterados, cancela os que não existem mais e não mexe
/// nos inalterados (idempotente). Chamadas são serializadas (uma reconciliação por vez).
class ReminderReconciler {
  ReminderReconciler({
    required this._gateway,
    required this._texts,
    required this._clock,
    this._ready,
  });

  final NotificationGateway _gateway;
  final ReminderTexts _texts;
  final Clock _clock;

  /// Garante a inicialização do plugin (canais) antes de agendar.
  final Future<void> Function()? _ready;

  /// id da notificação -> assinatura do que foi agendado ('' = veio do sistema após reinício
  /// do app, conteúdo desconhecido: será reagendado se ainda for desejado).
  final _scheduled = <int, String>{};
  var _primed = false;
  Future<void> _tail = Future.value();

  Future<void> _enqueue(Future<void> Function() job) {
    final next = _tail.then((_) => job());
    _tail = next.catchError((Object _) {});
    return next;
  }

  /// Deixa agendados exatamente [plans] (os passados são descartados).
  Future<void> reconcile(Iterable<ReminderPlan> plans) => _enqueue(() => _reconcile(plans.toList()));

  /// Cancela tudo (logout, lembretes desligados).
  Future<void> cancelAll() => _enqueue(() => _reconcile(const []));

  Future<void> _prime() async {
    if (_primed) return;
    try {
      for (final id in await _gateway.pendingIds()) {
        _scheduled.putIfAbsent(id, () => '');
      }
      _primed = true;
    } catch (e) {
      debugPrint('Lembretes: falha ao listar agendados');
    }
  }

  Future<void> _reconcile(List<ReminderPlan> plans) async {
    try {
      await _ready?.call();
    } catch (e) {
      debugPrint('Lembretes: plugin indisponível');
    }
    await _prime();
    final now = _clock().toUtc();
    final desired = <int, ReminderPlan>{
      for (final p in plans)
        if (p.fireAt.isAfter(now)) p.notificationId: p,
    };

    for (final id in _scheduled.keys.toList()) {
      if (desired.containsKey(id)) continue;
      try {
        await _gateway.cancel(id);
        _scheduled.remove(id);
      } catch (e) {
        debugPrint('Lembretes: falha ao cancelar');
      }
    }

    for (final entry in desired.entries) {
      final p = entry.value;
      final body = _texts.body(p.scheduledAt, p.fireAt);
      final payload = p.payload.encode();
      final signature = '${p.fireAt.millisecondsSinceEpoch}|${p.title}|$body|$payload';
      if (_scheduled[entry.key] == signature) continue;
      try {
        await _gateway.schedule(ScheduledReminder(
          id: entry.key,
          title: p.title,
          body: body,
          fireAtUtc: p.fireAt,
          payload: payload,
        ));
        _scheduled[entry.key] = signature;
      } catch (e) {
        debugPrint('Lembretes: falha ao agendar');
      }
    }
  }
}
