import 'package:planly/features/household/domain/household_models.dart';

abstract class HouseholdRepository {
  /// Casas vivas da família visíveis ao usuário. Owner: todas; membro: só as que tem acesso
  /// (query `accessUids array-contains uid`). Sempre com `limit`.
  Stream<HouseholdsSnapshot> watchHouseholds(
    String familyId, {
    required String uid,
    required bool isOwner,
  });

  /// Update direto permitido pelas Rules (`name` + `updatedAt`) a owner/admin da casa.
  Future<void> rename({required String familyId, required String householdId, required String name});

  /// Callable `createHousehold` (owner). Devolve o id da casa.
  Future<String> createHousehold({required String familyId, required String name});

  /// Callable `deleteHousehold` (owner; soft delete).
  Future<void> deleteHousehold({required String familyId, required String householdId});

  /// Callable `setHouseholdAccess` (owner). `role == null` revoga.
  Future<void> setHouseholdAccess({
    required String familyId,
    required String householdId,
    required String targetUid,
    required HouseholdRole? role,
  });
}
