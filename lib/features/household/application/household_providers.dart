import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/connectivity/online_only.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/household/data/firestore_household_repository.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/household/domain/household_repository.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return FirestoreHouseholdRepository(
    firestore: ref.watch(firestoreProvider),
    callable: ref.watch(callableInvokerProvider),
  );
});

/// Casas da família ativa acessíveis ao usuário (listener de sessão). Owner: todas; membro:
/// `accessUids array-contains uid`.
final accessibleHouseholdsProvider = StreamProvider<HouseholdsSnapshot>((ref) {
  final uid = ref.watch(currentUidProvider);
  final familyId = ref.watch(activeFamilyIdProvider);
  final membership = ref.watch(activeMembershipProvider);
  if (uid == null || familyId == null || membership == null) return const Stream.empty();
  return ref
      .watch(householdRepositoryProvider)
      .watchHouseholds(familyId, uid: uid, isOwner: membership.isOwner);
});

/// Casa ativa validada: escolha guardada se ainda acessível; senão a primeira. `null` se não
/// há casa acessível (ou ainda carregando).
final activeHouseholdProvider = Provider<Household?>((ref) {
  final items = ref.watch(accessibleHouseholdsProvider).value?.items;
  if (items == null || items.isEmpty) return null;
  final stored = ref.watch(activeContextProvider).householdId;
  for (final h in items) {
    if (h.id == stored) return h;
  }
  return items.first;
});

/// Ações de casa (callables só-online, exceto renomear que é update direto).
class HouseholdActions {
  HouseholdActions(this._ref);

  final Ref _ref;

  HouseholdRepository get _repo => _ref.read(householdRepositoryProvider);

  Future<String> create(String familyId, String name) async {
    await ensureOnline(_ref);
    return _repo.createHousehold(familyId: familyId, name: name);
  }

  /// Update direto (Rules). Tratado como só-online: offline a escrita ficaria pendente sem
  /// confirmação e o usuário não veria um erro de Rules; melhor falhar cedo e explicar.
  Future<void> rename(String familyId, String householdId, String name) async {
    await ensureOnline(_ref);
    await _repo.rename(familyId: familyId, householdId: householdId, name: name);
  }

  Future<void> delete(String familyId, String householdId) async {
    await ensureOnline(_ref);
    await _repo.deleteHousehold(familyId: familyId, householdId: householdId);
  }

  Future<void> setAccess(String familyId, String householdId, String targetUid, HouseholdRole? role) async {
    await ensureOnline(_ref);
    await _repo.setHouseholdAccess(
      familyId: familyId,
      householdId: householdId,
      targetUid: targetUid,
      role: role,
    );
  }
}

final householdActionsProvider = Provider<HouseholdActions>(HouseholdActions.new);
