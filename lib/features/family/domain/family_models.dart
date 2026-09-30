/// Entidades de domínio da Family (data-model §3.2–3.7). Sem tipos de SDK.
enum FamilyStatus {
  active,
  frozen,
  deleting;

  static FamilyStatus parse(Object? v) => switch (v) {
        'frozen' => FamilyStatus.frozen,
        'deleting' => FamilyStatus.deleting,
        _ => FamilyStatus.active,
      };
}

enum FamilyRole {
  owner,
  member;

  static FamilyRole parse(Object? v) => v == 'owner' ? FamilyRole.owner : FamilyRole.member;
}

enum PlanId {
  free,
  family,
  familyPlus;

  static PlanId parse(Object? v) => switch (v) {
        'family' => PlanId.family,
        'family_plus' => PlanId.familyPlus,
        _ => PlanId.free,
      };
}

/// Espelho `users/{uid}/memberships/{familyId}`.
class FamilyMembership {
  const FamilyMembership({
    required this.familyId,
    required this.familyName,
    required this.role,
    required this.familyStatus,
    required this.plan,
  });

  final String familyId;
  final String familyName;
  final FamilyRole role;
  final FamilyStatus familyStatus;
  final PlanId plan;

  bool get isOwner => role == FamilyRole.owner;
}

/// `families/{familyId}`.
class Family {
  const Family({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.status,
    required this.plan,
    required this.memberCount,
    required this.householdCount,
    this.deleteAfter,
    this.pendingTransferToUid,
  });

  final String id;
  final String name;
  final String ownerId;
  final FamilyStatus status;
  final PlanId plan;
  final int memberCount;
  final int householdCount;
  final DateTime? deleteAfter;
  final String? pendingTransferToUid;

  bool get isFrozen => status == FamilyStatus.frozen;
}

/// `families/{f}/billing/entitlement`. `maxHouseholds == null` = ilimitado.
class Entitlement {
  const Entitlement({
    required this.plan,
    required this.maxMembers,
    required this.maxHouseholds,
    required this.invitesEnabled,
  });

  final PlanId plan;
  final int maxMembers;
  final int? maxHouseholds;
  final bool invitesEnabled;

  bool get isFree => plan == PlanId.free;

  /// Só para UX (o backend decide de verdade).
  bool canAddHousehold(int householdCount) =>
      maxHouseholds == null || householdCount < maxHouseholds!;
}

/// `families/{f}/members/{uid}`.
class FamilyMember {
  const FamilyMember({
    required this.uid,
    required this.role,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final FamilyRole role;
  final String? displayName;
  final String? photoUrl;

  bool get isOwner => role == FamilyRole.owner;
}

class BootstrapResult {
  const BootstrapResult({required this.familyId, this.householdId});

  final String familyId;
  final String? householdId;
}
