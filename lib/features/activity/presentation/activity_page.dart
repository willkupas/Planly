import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/core/time/clock.dart';
import 'package:planly/features/activity/application/activity_grouping.dart';
import 'package:planly/features/activity/application/activity_providers.dart';
import 'package:planly/features/activity/domain/activity_models.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/activity/presentation/activity_text.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Tela 10: histórico da casa ativa ("quem fez o quê"), agrupado por dia. É um registro, não
/// um placar: sem ranking, contagem por pessoa ou pontuação.
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  bool? _wasVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // O shell mantém as abas vivas (IndexedStack): recarrega ao voltar para esta aba, já que
    // o histórico é lido por página (sem listener) e mudou enquanto outra aba estava aberta.
    final visible = TickerMode.valuesOf(context).enabled;
    if (_wasVisible == false && visible) {
      // Fora da fase de build (invalidar aqui marcaria o ProviderScope como sujo).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(activityFeedProvider);
      });
    }
    _wasVisible = visible;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(activityFeedProvider);
    final household = ref.watch(activeHouseholdProvider);
    final filter = ref.watch(activityFilterProvider);
    final restricted = ref.watch(activityRestrictedProvider);
    final people = ref.watch(activityPeopleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          household == null
              ? l10n.activityTitle
              : '${l10n.activityTitle} · ${household.name}',
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (people.length > 1)
            _PersonFilter(people: people, selected: filter),
          Expanded(
            child: AsyncValueView<ActivityFeedState>(
              value: feed,
              onRetry: () => ref.invalidate(activityFeedProvider),
              isEmpty: (s) => s.events.isEmpty,
              empty: EmptyState(
                icon: Icons.history,
                title: l10n.activityEmptyTitle,
                message: filter == null
                    ? l10n.activityEmptyMessage
                    : l10n.activityEmptyFilteredMessage,
                action: restricted
                    ? Text(l10n.activityFreeNote, textAlign: TextAlign.center)
                    : null,
              ),
              data: (context, s) => _FeedList(state: s, restricted: restricted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonFilter extends ConsumerWidget {
  const _PersonFilter({required this.people, required this.selected});

  final List<FamilyMember> people;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(currentUidProvider);
    final notifier = ref.read(activityFilterProvider.notifier);

    String nameOf(FamilyMember m) {
      if (m.uid == uid) return l10n.activityYou;
      final n = m.displayName?.trim() ?? '';
      return n.isEmpty ? l10n.activityPersonFallback : n;
    }

    return Semantics(
      label: l10n.activityFilterLabel,
      child: SingleChildScrollView(
        key: const Key('activity-filter'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ChoiceChip(
              key: const Key('activity-filter-all'),
              label: Text(l10n.activityFilterAll),
              selected: selected == null,
              onSelected: (_) => notifier.select(null),
            ),
            for (final m in people) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                key: Key('activity-filter-${m.uid}'),
                label: Text(nameOf(m)),
                selected: selected == m.uid,
                onSelected: (_) => notifier.select(m.uid),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Item achatado da lista: cabeçalho de dia, evento ou rodapé.
sealed class _Row {}

class _HeaderRow extends _Row {
  _HeaderRow(this.group);
  final ActivityDayGroup group;
}

class _EventRow extends _Row {
  _EventRow(this.event);
  final ActivityEvent event;
}

class _FeedList extends ConsumerWidget {
  const _FeedList({required this.state, required this.restricted});

  final ActivityFeedState state;
  final bool restricted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(currentUidProvider);
    final now = ref.watch(clockProvider)();
    final rows = <_Row>[
      for (final g in groupByDay(state.events, now)) ...[
        _HeaderRow(g),
        for (final e in g.events) _EventRow(e),
      ],
    ];
    final hasFooter =
        state.hasMore ||
        state.loadingMore ||
        state.loadMoreFailed ||
        restricted;

    return ListView.builder(
      key: const Key('activity-view'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length + (hasFooter ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == rows.length) {
          return _Footer(state: state, restricted: restricted);
        }
        return switch (rows[i]) {
          _HeaderRow(:final group) => _DayHeader(day: group.day, now: now),
          _EventRow(:final event) => _EventTile(
            event: event,
            l10n: l10n,
            uid: uid,
          ),
        };
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.now});

  final DateTime day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = switch (dayLabelFor(day, now)) {
      DayLabel.today => l10n.activityDayToday,
      DayLabel.yesterday => l10n.activityDayYesterday,
      DayLabel.date => l10n.activityDayDate(day),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          key: Key('activity-day-${day.year}-${day.month}-${day.day}'),
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.l10n,
    required this.uid,
  });

  final ActivityEvent event;
  final AppLocalizations l10n;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final time = event.createdAt;
    return ListTile(
      key: Key('activity-${event.id}'),
      leading: Icon(activityEventIcon(event.type)),
      title: Text(activityEventText(l10n, event, currentUid: uid)),
      subtitle: time == null ? null : Text(l10n.activityTime(time.toLocal())),
      trailing: event.hasPendingWrites
          ? Tooltip(
              message: l10n.itemPendingSync,
              child: const Icon(Icons.schedule, size: 16),
            )
          : null,
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.state, required this.restricted});

  final ActivityFeedState state;
  final bool restricted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (state.loadMoreFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.activityLoadMoreFailed,
                  key: const Key('activity-load-more-error'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (state.hasMore)
            FilledButton.tonal(
              key: const Key('activity-load-more'),
              onPressed: state.loadingMore
                  ? null
                  : () => ref.read(activityFeedProvider.notifier).loadMore(),
              child: Text(
                state.loadingMore
                    ? l10n.activityLoadingMore
                    : l10n.activityLoadMore,
              ),
            ),
          // Free: o histórico acaba na janela de 7 dias; a nota só aparece no fim da lista.
          if (restricted && !state.hasMore) ...[
            Text(
              l10n.activityFreeNote,
              key: const Key('activity-free-note'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
