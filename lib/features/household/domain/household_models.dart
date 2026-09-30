import 'package:planly/core/sync/sync_status.dart';

enum HouseholdRole {
  admin,
  member;

  static HouseholdRole? parse(Object? v) => switch (v) {
        'admin' => HouseholdRole.admin,
        'member' => HouseholdRole.member,
        _ => null,
      };
}

/// `families/{f}/households/{h}` (data-model §3.8). O owner nunca aparece em `access`
/// (acesso implícito).
class Household {
  const Household({
    required this.id,
    required this.name,
    this.access = const {},
    this.deleted = false,
  });

  final String id;
  final String name;
  final Map<String, HouseholdRole> access;
  final bool deleted;
}

class HouseholdsSnapshot {
  const HouseholdsSnapshot(this.items, [this.meta = const SyncMeta()]);

  final List<Household> items;
  final SyncMeta meta;
}
