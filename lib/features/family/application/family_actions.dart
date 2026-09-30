import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/connectivity/online_only.dart';
import 'package:planly/features/family/application/family_providers.dart';

/// Ações de membros (callables, só-online). Lançam `AppFailure`; a UI mostra o texto i18n.
class FamilyActions {
  FamilyActions(this._ref);

  final Ref _ref;

  Future<void> removeMember(String familyId, String targetUid) async {
    await ensureOnline(_ref);
    await _ref.read(familyRepositoryProvider).removeMember(familyId: familyId, targetUid: targetUid);
  }

  Future<void> leaveFamily(String familyId) async {
    await ensureOnline(_ref);
    await _ref.read(familyRepositoryProvider).leaveFamily(familyId);
  }
}

final familyActionsProvider = Provider<FamilyActions>(FamilyActions.new);
