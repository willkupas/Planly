import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/time/clock.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/tasks/application/task_providers.dart';
import 'package:planly/features/tasks/domain/task_models.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Estado do formulário de tarefa (criação rápida com "Mais opções" e detalhe/edição).
class TaskFormController extends ChangeNotifier {
  TaskFormController({this.original, String? defaultAssignee})
      : title = TextEditingController(text: original?.title ?? ''),
        description = TextEditingController(text: original?.description ?? ''),
        assignedTo = original != null ? original.assignedTo : defaultAssignee,
        when = original?.schedule?.scheduledAt.toLocal(),
        notify = original?.notification.enabled ?? false,
        notifyOffset = original?.notification.offsetMinutes ?? 0 {
    title.addListener(notifyListeners);
    description.addListener(notifyListeners);
  }

  /// Tarefa sendo editada (`null` na criação); atualizada quando chega versão nova (rebase).
  Task? original;
  final TextEditingController title;
  final TextEditingController description;

  /// `null` = qualquer pessoa.
  String? assignedTo;

  /// Data/hora LOCAL do aparelho; `null` = sem data.
  DateTime? when;
  bool notify;
  int notifyOffset;

  bool get hasValidTitle {
    final t = title.text.trim();
    return t.isNotEmpty && t.length <= TaskDraft.maxTitle;
  }

  void setWhen(DateTime? v) {
    when = v;
    if (v == null) notify = false;
    notifyListeners();
  }

  void setAssignee(String? v) {
    assignedTo = v;
    notifyListeners();
  }

  void setNotify(bool v) {
    notify = v;
    notifyListeners();
  }

  void setNotifyOffset(int v) {
    notifyOffset = v;
    notifyListeners();
  }

  /// Chegou versão nova da tarefa (sync/outro usuário): campos que o usuário não tocou
  /// acompanham; os editados ficam como estão.
  void rebase(Task after) {
    final before = original;
    original = after;
    if (before == null) return;
    if (title.text.trim() == before.title) title.text = after.title;
    if (description.text.trim() == before.description) description.text = after.description;
    if (assignedTo == before.assignedTo) assignedTo = after.assignedTo;
    if (when?.toUtc() == before.schedule?.scheduledAt) when = after.schedule?.scheduledAt.toLocal();
    if (notify == before.notification.enabled) notify = after.notification.enabled;
    if (notifyOffset == before.notification.offsetMinutes) notifyOffset = after.notification.offsetMinutes;
    notifyListeners();
  }

  /// Monta o rascunho. Horário inalterado preserva o `timezone` original da tarefa; horário
  /// novo usa o IANA do aparelho ([deviceTimezone]).
  TaskDraft toDraft(String deviceTimezone) {
    final w = when;
    TaskSchedule? schedule;
    if (w != null) {
      final utc = w.toUtc();
      final o = original?.schedule;
      schedule = (o != null && o.scheduledAt.isAtSameMomentAs(utc))
          ? o
          : TaskSchedule(scheduledAt: utc, timezone: deviceTimezone);
    }
    return TaskDraft(
      title: title.text.trim(),
      description: description.text.trim(),
      assignedTo: assignedTo,
      schedule: schedule,
      notification: TaskNotification(enabled: notify && w != null, offsetMinutes: notifyOffset),
    );
  }

  /// Há diferença em relação à tarefa original?
  bool get isDirty {
    final o = original;
    if (o == null) return true;
    final d = toDraft('UTC');
    return d.title != o.title ||
        d.description != o.description ||
        d.assignedTo != o.assignedTo ||
        d.schedule != o.schedule ||
        d.notification != o.notification;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }
}

const _anyone = '';
const _offsets = [0, 15, 60, 1440];

/// Campos de "Mais opções" (descrição, data/hora, responsável, notificar). O título é
/// responsabilidade de quem usa (sheet de criação ou detalhe).
class TaskFormFields extends ConsumerWidget {
  const TaskFormFields({super.key, required this.controller, this.enabled = true});

  final TaskFormController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final when = controller.when;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('task-description'),
              controller: controller.description,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: TaskDraft.maxDescription,
              decoration: InputDecoration(labelText: l10n.taskDescriptionLabel),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('task-date'),
                    icon: const Icon(Icons.event_outlined),
                    label: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        when == null ? l10n.taskNoDate : l10n.taskScheduleAt(when, when),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onPressed: enabled ? () => _pickDateTime(context, ref) : null,
                  ),
                ),
                if (when != null && enabled)
                  IconButton(
                    key: const Key('task-date-clear'),
                    tooltip: l10n.taskClearDate,
                    icon: const Icon(Icons.close),
                    onPressed: () => controller.setWhen(null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _AssigneeField(key: const Key('task-assignee'), controller: controller, enabled: enabled),
            const SizedBox(height: 4),
            SwitchListTile(
              key: const Key('task-notify'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.taskNotifyLabel),
              subtitle: when == null ? Text(l10n.taskNotifyNeedsDate) : null,
              value: controller.notify && when != null,
              onChanged: enabled && when != null ? controller.setNotify : null,
            ),
            if (controller.notify && when != null) _OffsetField(controller: controller, enabled: enabled),
          ],
        );
      },
    );
  }

  Future<void> _pickDateTime(BuildContext context, WidgetRef ref) async {
    final now = ref.read(clockProvider)();
    final initial = controller.when ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(controller.when ?? now),
    );
    if (time == null) return;
    controller.setWhen(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
}

class _AssigneeField extends ConsumerWidget {
  const _AssigneeField({super.key, required this.controller, required this.enabled});

  final TaskFormController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myUid = ref.watch(currentUidProvider);
    final candidates = ref.watch(assigneeCandidatesProvider).value ?? const <FamilyMember>[];
    final current = controller.assignedTo;

    String nameOf(FamilyMember m) {
      final n = m.displayName?.trim().isNotEmpty == true ? m.displayName!.trim() : l10n.memberNoName;
      return m.uid == myUid ? l10n.memberYou(n) : n;
    }

    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: _anyone, child: Text(l10n.taskAssigneeAnyone)),
      for (final m in candidates) DropdownMenuItem(value: m.uid, child: Text(nameOf(m), overflow: TextOverflow.ellipsis)),
      // Responsável atual fora da lista (saiu da casa, ainda carregando): mantém o valor válido.
      if (current != null && !candidates.any((m) => m.uid == current))
        DropdownMenuItem(
          value: current,
          child: Text(current == myUid ? l10n.memberYou(l10n.memberNoName) : l10n.memberNoName),
        ),
    ];
    return DropdownButtonFormField<String>(
      key: ValueKey('assignee-${current ?? _anyone}-${items.length}'),
      initialValue: current ?? _anyone,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.taskAssigneeLabel),
      items: items,
      onChanged: enabled ? (v) => controller.setAssignee(v == null || v == _anyone ? null : v) : null,
    );
  }
}

class _OffsetField extends StatelessWidget {
  const _OffsetField({required this.controller, required this.enabled});

  final TaskFormController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offsets = {..._offsets, controller.notifyOffset}.toList()..sort();
    String label(int m) => switch (m) {
          0 => l10n.taskNotifyAtTime,
          60 => l10n.taskNotifyHourBefore,
          1440 => l10n.taskNotifyDayBefore,
          _ => l10n.taskNotifyMinutesBefore(m),
        };
    return DropdownButtonFormField<int>(
      key: const Key('task-notify-offset'),
      initialValue: controller.notifyOffset,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.taskNotifyLabel),
      items: [for (final m in offsets) DropdownMenuItem(value: m, child: Text(label(m)))],
      onChanged: enabled ? (v) => controller.setNotifyOffset(v ?? 0) : null,
    );
  }
}
