import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/features/auth/application/auth_providers.dart';

/// Seleção persistida de família/casa ativas (spec flutter-app §2.1, §4.3). É a escolha
/// *guardada*; a versão validada contra memberships/casas é `activeFamilyIdProvider` /
/// `activeHouseholdProvider` (fallback automático quando a escolha some).
class ActiveContext {
  const ActiveContext({this.familyId, this.householdId});

  final String? familyId;
  final String? householdId;

  @override
  bool operator ==(Object other) =>
      other is ActiveContext && other.familyId == familyId && other.householdId == householdId;

  @override
  int get hashCode => Object.hash(familyId, householdId);
}

String _familyKey(String uid) => 'activeContext.$uid.familyId';
String _householdKey(String uid) => 'activeContext.$uid.householdId';

class ActiveContextNotifier extends Notifier<ActiveContext> {
  String? _uid;

  @override
  ActiveContext build() {
    // Chave por usuário: outra conta no mesmo aparelho nunca herda a escolha.
    final uid = _uid = ref.watch(currentUidProvider);
    if (uid == null) return const ActiveContext();
    final prefs = ref.watch(sharedPreferencesProvider);
    return ActiveContext(
      familyId: prefs.getString(_familyKey(uid)),
      householdId: prefs.getString(_householdKey(uid)),
    );
  }

  /// Troca de família: a casa volta a ser resolvida (primeira acessível).
  Future<void> selectFamily(String familyId) => _save(ActiveContext(familyId: familyId));

  Future<void> selectHousehold(String familyId, String householdId) =>
      _save(ActiveContext(familyId: familyId, householdId: householdId));

  /// Remove a escolha guardada (logout).
  Future<void> clear() async {
    final uid = _uid;
    state = const ActiveContext();
    if (uid == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_familyKey(uid));
    await prefs.remove(_householdKey(uid));
  }

  Future<void> _save(ActiveContext next) async {
    final uid = _uid;
    if (uid == null || next == state) return;
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    if (next.familyId == null) {
      await prefs.remove(_familyKey(uid));
    } else {
      await prefs.setString(_familyKey(uid), next.familyId!);
    }
    if (next.householdId == null) {
      await prefs.remove(_householdKey(uid));
    } else {
      await prefs.setString(_householdKey(uid), next.householdId!);
    }
  }
}

final activeContextProvider =
    NotifierProvider<ActiveContextNotifier, ActiveContext>(ActiveContextNotifier.new);
