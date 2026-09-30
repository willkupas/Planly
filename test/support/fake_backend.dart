import 'dart:async';

import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/sync/local_data_service.dart';
import 'package:planly/features/auth/domain/user_profile_repository.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/family/domain/family_repository.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/household/domain/household_repository.dart';

/// Valor observável para fakes de stream: emite o atual ao assinar e a cada mudança.
/// Sem valor nem erro = "carregando" (nada emitido).
class Live<T> {
  Live([T? initial]) {
    if (initial != null) set(initial);
  }

  T? _value;
  Object? _error;
  bool _has = false;
  final _changes = StreamController<void>.broadcast();

  T? get value => _value;

  void set(T v) {
    _value = v;
    _error = null;
    _has = true;
    _changes.add(null);
  }

  void fail(Object e) {
    _error = e;
    _has = true;
    _changes.add(null);
  }

  Stream<T> get stream => Stream<T>.multi((ctl) {
        void emit() {
          if (!_has) return;
          if (_error != null) {
            ctl.addError(_error!);
          } else {
            ctl.add(_value as T);
          }
        }

        emit();
        final sub = _changes.stream.listen((_) => emit());
        ctl.onCancel = sub.cancel;
      });
}

const uidOwner = 'u1';
const uidMember = 'u2';

const freeProfile = UserProfile(freeFamilyId: 'f1');

FamilyMembership membership(
  String id, {
  FamilyRole role = FamilyRole.owner,
  FamilyStatus status = FamilyStatus.active,
  PlanId plan = PlanId.free,
  String? name,
}) =>
    FamilyMembership(
      familyId: id,
      familyName: name ?? 'Família $id',
      role: role,
      familyStatus: status,
      plan: plan,
    );

Family family(
  String id, {
  FamilyStatus status = FamilyStatus.active,
  PlanId plan = PlanId.free,
  int members = 1,
  int households = 1,
  DateTime? deleteAfter,
  String ownerId = uidOwner,
}) =>
    Family(
      id: id,
      name: 'Família $id',
      ownerId: ownerId,
      status: status,
      plan: plan,
      memberCount: members,
      householdCount: households,
      deleteAfter: deleteAfter,
    );

const freeEntitlement =
    Entitlement(plan: PlanId.free, maxMembers: 1, maxHouseholds: 1, invitesEnabled: false);
const familyEntitlement =
    Entitlement(plan: PlanId.family, maxMembers: 4, maxHouseholds: 3, invitesEnabled: true);
const plusEntitlement =
    Entitlement(plan: PlanId.familyPlus, maxMembers: 8, maxHouseholds: null, invitesEnabled: true);

/// Backend em memória que implementa os três repositories (família, casa, perfil), para
/// testes de widget/fluxo sem Firebase. Chamadas ficam em [calls].
class FakeBackend implements FamilyRepository, HouseholdRepository, UserProfileRepository {
  final memberships = Live<List<FamilyMembership>>();
  final profile = Live<UserProfile?>();
  final _families = <String, Live<Family?>>{};
  final _entitlements = <String, Live<Entitlement?>>{};
  final _members = <String, Live<List<FamilyMember>>>{};
  final _households = <String, Live<HouseholdsSnapshot>>{};

  final calls = <String>[];

  /// Segura o `bootstrapUser` até completar (simula "carregando").
  Completer<void>? bootstrapGate;

  /// Falhas a lançar, em ordem, nas próximas chamadas de `bootstrapUser`.
  final bootstrapFailures = <AppFailure>[];

  /// Falha a lançar na próxima ação (callable/update) qualquer.
  AppFailure? nextActionFailure;

  Map<String, Object?>? lastProfileUpsert;
  String? lastBootstrapTimezone;

  Live<Family?> familyLive(String id) => _families.putIfAbsent(id, Live.new);
  Live<Entitlement?> entitlementLive(String id) => _entitlements.putIfAbsent(id, Live.new);
  Live<List<FamilyMember>> membersLive(String id) => _members.putIfAbsent(id, Live.new);
  Live<HouseholdsSnapshot> householdsLive(String id) => _households.putIfAbsent(id, Live.new);

  /// Usuário já existente: Family Free do `uidOwner` com uma casa.
  void seedOwnerFree({String familyId = 'f1', String householdId = 'h1'}) {
    profile.set(UserProfile(freeFamilyId: familyId));
    memberships.set([membership(familyId)]);
    familyLive(familyId).set(family(familyId));
    entitlementLive(familyId).set(freeEntitlement);
    householdsLive(familyId).set(HouseholdsSnapshot([Household(id: householdId, name: 'Minha casa')]));
    membersLive(familyId).set([const FamilyMember(uid: uidOwner, role: FamilyRole.owner, displayName: 'Teste')]);
  }

  /// Usuário novo (sem perfil nem famílias): precisa de bootstrap.
  void seedNewUser() {
    profile.set(null);
    memberships.set(const []);
  }

  void _maybeFail() {
    final f = nextActionFailure;
    if (f != null) {
      nextActionFailure = null;
      throw f;
    }
  }

  // ---- FamilyRepository ----
  @override
  Stream<List<FamilyMembership>> watchMemberships(String uid) => memberships.stream;

  @override
  Stream<Family?> watchFamily(String familyId) => familyLive(familyId).stream;

  @override
  Stream<Entitlement?> watchEntitlement(String familyId) => entitlementLive(familyId).stream;

  @override
  Stream<List<FamilyMember>> watchMembers(String familyId) => membersLive(familyId).stream;

  @override
  Future<BootstrapResult> bootstrapUser({String? displayName, String? locale, String? timezone}) async {
    calls.add('bootstrapUser');
    lastBootstrapTimezone = timezone;
    await bootstrapGate?.future;
    if (bootstrapFailures.isNotEmpty) throw bootstrapFailures.removeAt(0);
    seedOwnerFree(familyId: 'f-new', householdId: 'h-new');
    return const BootstrapResult(familyId: 'f-new', householdId: 'h-new');
  }

  @override
  Future<void> removeMember({required String familyId, required String targetUid}) async {
    calls.add('removeMember:$familyId:$targetUid');
    _maybeFail();
  }

  @override
  Future<void> leaveFamily(String familyId) async {
    calls.add('leaveFamily:$familyId');
    _maybeFail();
  }

  // ---- HouseholdRepository ----
  @override
  Stream<HouseholdsSnapshot> watchHouseholds(String familyId, {required String uid, required bool isOwner}) {
    calls.add('watchHouseholds:$familyId:$uid:${isOwner ? 'owner' : 'member'}');
    return householdsLive(familyId).stream;
  }

  @override
  Future<void> rename({required String familyId, required String householdId, required String name}) async {
    calls.add('rename:$familyId:$householdId:$name');
    _maybeFail();
  }

  @override
  Future<String> createHousehold({required String familyId, required String name}) async {
    calls.add('createHousehold:$familyId:$name');
    _maybeFail();
    final current = householdsLive(familyId).value?.items ?? const [];
    householdsLive(familyId).set(HouseholdsSnapshot([...current, Household(id: 'h-created', name: name)]));
    return 'h-created';
  }

  @override
  Future<void> deleteHousehold({required String familyId, required String householdId}) async {
    calls.add('deleteHousehold:$familyId:$householdId');
    _maybeFail();
  }

  @override
  Future<void> setHouseholdAccess({
    required String familyId,
    required String householdId,
    required String targetUid,
    required HouseholdRole? role,
  }) async {
    calls.add('setHouseholdAccess:$familyId:$householdId:$targetUid:${role?.name}');
    _maybeFail();
  }

  // ---- UserProfileRepository ----
  @override
  Stream<UserProfile?> watchProfile(String uid) => profile.stream;

  @override
  Future<void> upsertClientFields(
    String uid, {
    String? displayName,
    String? photoUrl,
    String? locale,
    String? timezone,
  }) async {
    calls.add('upsertClientFields');
    lastProfileUpsert = {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'locale': locale,
      'timezone': timezone,
    };
  }
}

class FakeLocalData implements LocalDataService {
  bool pending = false;
  int clearCalls = 0;

  @override
  Future<bool> hasPendingWrites() async => pending;

  @override
  Future<void> clearLocalData() async => clearCalls++;
}
