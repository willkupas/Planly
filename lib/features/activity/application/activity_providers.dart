import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/core/time/clock.dart';
import 'package:planly/features/activity/data/firestore_activity_repository.dart';
import 'package:planly/features/activity/domain/activity_models.dart';
import 'package:planly/features/activity/domain/activity_repository.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/application/household_providers.dart';

/// Janela do histórico para quem não tem `features.fullHistory` (Free).
const freeHistoryWindow = Duration(days: 7);

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return FirestoreActivityRepository(firestore: ref.watch(firestoreProvider));
});

/// Free (ou entitlement ainda não carregado — o mais restritivo): só os últimos 7 dias.
final activityRestrictedProvider = Provider<bool>((ref) {
  final entitlement = ref.watch(activeEntitlementProvider).value;
  return entitlement == null || !entitlement.fullHistory;
});

/// Filtro por pessoa (`actorId`); `null` = todas. Reinicia ao sair da tela.
class ActivityFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? actorId) => state = actorId;
}

final activityFilterProvider =
    NotifierProvider.autoDispose<ActivityFilterNotifier, String?>(
      ActivityFilterNotifier.new,
    );

/// Pessoas oferecidas no filtro: membros da família com acesso à casa ativa (owner tem acesso
/// implícito). Vazio enquanto carrega.
final activityPeopleProvider = Provider.autoDispose<List<FamilyMember>>((ref) {
  final familyId = ref.watch(activeFamilyIdProvider);
  final household = ref.watch(activeHouseholdProvider);
  if (familyId == null || household == null) return const [];
  final members =
      ref.watch(familyMembersProvider(familyId)).value ??
      const <FamilyMember>[];
  return [
    for (final m in members)
      if (m.isOwner || household.access.containsKey(m.uid)) m,
  ];
});

class ActivityFeedState {
  const ActivityFeedState({
    required this.events,
    required this.hasMore,
    this.cursor,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<ActivityEvent> events;
  final bool hasMore;
  final Object? cursor;
  final bool loadingMore;
  final bool loadMoreFailed;

  ActivityFeedState copyWith({
    List<ActivityEvent>? events,
    bool? hasMore,
    Object? cursor,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) {
    return ActivityFeedState(
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor ?? this.cursor,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Histórico paginado da casa ativa (sem listener: leitura por página, spec §7). Só vive com
/// a tela aberta (autoDispose). Trocar casa/filtro/plano recarrega da primeira página.
class ActivityFeedNotifier extends AsyncNotifier<ActivityFeedState> {
  String? _familyId;
  String? _householdId;
  String? _actorId;
  DateTime? _since;

  @override
  Future<ActivityFeedState> build() async {
    ref.watch(currentUidProvider);
    final familyId = _familyId = ref.watch(activeFamilyIdProvider);
    final householdId = _householdId = ref.watch(activeHouseholdProvider)?.id;
    final actorId = _actorId = ref.watch(activityFilterProvider);
    final restricted = ref.watch(activityRestrictedProvider);
    _since = restricted
        ? ref.read(clockProvider)().subtract(freeHistoryWindow)
        : null;
    if (familyId == null || householdId == null) {
      return const ActivityFeedState(events: [], hasMore: false);
    }
    final page = await ref
        .read(activityRepositoryProvider)
        .fetchPage(
          familyId: familyId,
          householdId: householdId,
          actorId: actorId,
          since: _since,
        );
    return ActivityFeedState(
      events: page.events,
      hasMore: page.hasMore,
      cursor: page.cursor,
    );
  }

  /// Próxima página (botão "Carregar mais"). Falha mantém o que já está na tela.
  Future<void> loadMore() async {
    final current = state.value;
    final familyId = _familyId;
    final householdId = _householdId;
    if (current == null || !current.hasMore || current.loadingMore) return;
    if (familyId == null || householdId == null) return;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await ref
          .read(activityRepositoryProvider)
          .fetchPage(
            familyId: familyId,
            householdId: householdId,
            cursor: current.cursor,
            actorId: _actorId,
            since: _since,
          );
      if (!ref.mounted) return;
      state = AsyncData(
        ActivityFeedState(
          events: [...current.events, ...page.events],
          hasMore: page.hasMore,
          cursor: page.cursor,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      // A UI mostra um aviso genérico de "não foi possível carregar" com nova tentativa.
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }
}

final activityFeedProvider =
    AsyncNotifierProvider.autoDispose<ActivityFeedNotifier, ActivityFeedState>(
      ActivityFeedNotifier.new,
    );
