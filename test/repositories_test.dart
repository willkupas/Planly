import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/callable_invoker.dart';
import 'package:planly/features/auth/data/firestore_user_profile_repository.dart';
import 'package:planly/features/family/data/firestore_family_repository.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/data/firestore_household_repository.dart';
import 'package:planly/features/household/domain/household_models.dart';

class _Calls {
  final log = <String>[];
  final data = <Map<String, Object?>>[];
  Map<String, dynamic> response = {'ok': true};
  AppFailure? failure;

  Future<Map<String, dynamic>> invoke(String name, Map<String, Object?> payload) async {
    log.add(name);
    data.add(payload);
    final f = failure;
    if (f != null) throw f;
    return response;
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late _Calls calls;
  late CallableInvoker invoker;

  setUp(() {
    db = FakeFirebaseFirestore();
    calls = _Calls();
    invoker = calls.invoke;
  });

  group('FirestoreFamilyRepository', () {
    test('watchMemberships lê users/{uid}/memberships e converte enums', () async {
      await db.collection('users').doc('u1').collection('memberships').doc('f1').set({
        'familyName': 'Casa dos Silva',
        'role': 'owner',
        'familyStatus': 'frozen',
        'plan': 'family_plus',
      });
      final repo = FirestoreFamilyRepository(firestore: db, callable: invoker);
      final list = await repo.watchMemberships('u1').first;
      expect(list, hasLength(1));
      expect(list.single.familyId, 'f1');
      expect(list.single.familyName, 'Casa dos Silva');
      expect(list.single.role, FamilyRole.owner);
      expect(list.single.familyStatus, FamilyStatus.frozen);
      expect(list.single.plan, PlanId.familyPlus);
    });

    test('watchFamily converte contadores, deleteAfter e transferência pendente', () async {
      final deleteAfter = DateTime.utc(2026, 12, 1);
      await db.collection('families').doc('f1').set({
        'name': 'F1',
        'ownerId': 'u1',
        'status': 'frozen',
        'plan': 'family',
        'memberCount': 3,
        'householdCount': 2,
        'deleteAfter': Timestamp.fromDate(deleteAfter),
        'pendingTransfer': {'toUid': 'u2'},
      });
      final f = await FirestoreFamilyRepository(firestore: db, callable: invoker).watchFamily('f1').first;
      expect(f, isNotNull);
      expect(f!.status, FamilyStatus.frozen);
      expect(f.isFrozen, isTrue);
      expect(f.memberCount, 3);
      expect(f.householdCount, 2);
      expect(f.deleteAfter!.toUtc(), deleteAfter);
      expect(f.pendingTransferToUid, 'u2');
    });

    test('watchFamily de doc inexistente emite null', () async {
      expect(await FirestoreFamilyRepository(firestore: db, callable: invoker).watchFamily('nope').first, isNull);
    });

    test('watchEntitlement: maxHouseholds null = ilimitado; features.invites', () async {
      await db.collection('families').doc('f1').collection('billing').doc('entitlement').set({
        'plan': 'family_plus',
        'maxMembers': 8,
        'maxHouseholds': null,
        'features': {'invites': true},
      });
      final e =
          await FirestoreFamilyRepository(firestore: db, callable: invoker).watchEntitlement('f1').first;
      expect(e!.plan, PlanId.familyPlus);
      expect(e.maxMembers, 8);
      expect(e.maxHouseholds, isNull);
      expect(e.invitesEnabled, isTrue);
      expect(e.canAddHousehold(99), isTrue);
    });

    test('Entitlement.canAddHousehold respeita o limite', () {
      const free = Entitlement(plan: PlanId.free, maxMembers: 1, maxHouseholds: 1, invitesEnabled: false);
      expect(free.canAddHousehold(0), isTrue);
      expect(free.canAddHousehold(1), isFalse);
      expect(free.isFree, isTrue);
    });

    test('watchMembers só traz membros ativos', () async {
      final col = db.collection('families').doc('f1').collection('members');
      await col.doc('u1').set({'role': 'owner', 'status': 'active', 'displayName': 'Ana'});
      await col.doc('u2').set({'role': 'member', 'status': 'active', 'displayName': 'Beto'});
      await col.doc('u3').set({'role': 'member', 'status': 'removed', 'displayName': 'Caio'});
      final members = await FirestoreFamilyRepository(firestore: db, callable: invoker).watchMembers('f1').first;
      expect(members.map((m) => m.uid), unorderedEquals(['u1', 'u2']));
      expect(members.firstWhere((m) => m.uid == 'u1').isOwner, isTrue);
    });

    test('bootstrapUser envia só campos presentes e lê familyId/householdId', () async {
      calls.response = {'ok': true, 'familyId': 'fam', 'householdId': 'hh'};
      final repo = FirestoreFamilyRepository(firestore: db, callable: invoker);
      final r = await repo.bootstrapUser(displayName: ' Ana ', locale: 'pt-BR', timezone: null);
      expect(calls.log, ['bootstrapUser']);
      expect(calls.data.single, {'displayName': 'Ana', 'locale': 'pt-BR'});
      expect(r.familyId, 'fam');
      expect(r.householdId, 'hh');
    });

    test('bootstrapUser aceita householdId nulo e rejeita resposta sem familyId', () async {
      final repo = FirestoreFamilyRepository(firestore: db, callable: invoker);
      calls.response = {'ok': true, 'familyId': 'fam', 'householdId': null};
      expect((await repo.bootstrapUser()).householdId, isNull);
      calls.response = {'ok': true};
      await expectLater(repo.bootstrapUser(), throwsA(isA<UnknownFailure>()));
    });

    test('removeMember e leaveFamily usam o contrato do cloud-functions.md §2.7', () async {
      final repo = FirestoreFamilyRepository(firestore: db, callable: invoker);
      await repo.removeMember(familyId: 'f1', targetUid: 'u2');
      await repo.leaveFamily('f1');
      expect(calls.log, ['removeMember', 'leaveFamily']);
      expect(calls.data[0], {'familyId': 'f1', 'targetUid': 'u2'});
      expect(calls.data[1], {'familyId': 'f1'});
    });

    test('falha da callable propaga como AppFailure', () async {
      calls.failure = const BusinessFailure('OWNER_CANNOT_LEAVE');
      await expectLater(
        FirestoreFamilyRepository(firestore: db, callable: invoker).leaveFamily('f1'),
        throwsA(const BusinessFailure('OWNER_CANNOT_LEAVE')),
      );
    });
  });

  group('FirestoreHouseholdRepository', () {
    Future<void> seed() async {
      final col = db.collection('families').doc('f1').collection('households');
      await col.doc('h1').set({
        'name': 'Zeta',
        'access': {'u2': 'admin'},
        'accessUids': ['u2'],
        'deletedAt': null,
      });
      await col.doc('h2').set({
        'name': 'alfa',
        'access': {'u3': 'member'},
        'accessUids': ['u3'],
        'deletedAt': null,
      });
      await col.doc('h3').set({
        'name': 'Excluída',
        'access': <String, dynamic>{},
        'accessUids': <String>[],
        'deletedAt': Timestamp.now(),
      });
    }

    test('owner lista todas as casas vivas, ordenadas por nome, com access', () async {
      await seed();
      final repo = FirestoreHouseholdRepository(firestore: db, callable: invoker);
      final snap = await repo.watchHouseholds('f1', uid: 'u1', isOwner: true).first;
      expect(snap.items.map((h) => h.name), ['alfa', 'Zeta']);
      expect(snap.items.last.access, {'u2': HouseholdRole.admin});
    });

    test('membro só vê casas em que está em accessUids', () async {
      await seed();
      final repo = FirestoreHouseholdRepository(firestore: db, callable: invoker);
      final snap = await repo.watchHouseholds('f1', uid: 'u2', isOwner: false).first;
      expect(snap.items.map((h) => h.id), ['h1']);
      final none = await repo.watchHouseholds('f1', uid: 'u9', isOwner: false).first;
      expect(none.items, isEmpty);
    });

    test('rename grava name + updatedAt (campos permitidos pelas Rules)', () async {
      await seed();
      await FirestoreHouseholdRepository(firestore: db, callable: invoker)
          .rename(familyId: 'f1', householdId: 'h1', name: '  Nova  ');
      final doc = await db.collection('families').doc('f1').collection('households').doc('h1').get();
      expect(doc.data()!['name'], 'Nova');
      expect(doc.data()!['updatedAt'], isNotNull);
      expect(doc.data()!['accessUids'], ['u2']); // intocado
    });

    test('callables: createHousehold, deleteHousehold, setHouseholdAccess', () async {
      final repo = FirestoreHouseholdRepository(firestore: db, callable: invoker);
      calls.response = {'ok': true, 'householdId': 'new'};
      expect(await repo.createHousehold(familyId: 'f1', name: ' Praia '), 'new');
      await repo.deleteHousehold(familyId: 'f1', householdId: 'h1');
      await repo.setHouseholdAccess(familyId: 'f1', householdId: 'h1', targetUid: 'u2', role: HouseholdRole.admin);
      await repo.setHouseholdAccess(familyId: 'f1', householdId: 'h1', targetUid: 'u2', role: null);
      expect(calls.log, ['createHousehold', 'deleteHousehold', 'setHouseholdAccess', 'setHouseholdAccess']);
      expect(calls.data[0], {'familyId': 'f1', 'name': 'Praia'});
      expect(calls.data[1], {'familyId': 'f1', 'householdId': 'h1'});
      expect(calls.data[2], {'familyId': 'f1', 'householdId': 'h1', 'targetUid': 'u2', 'role': 'admin'});
      expect(calls.data[3]['role'], isNull);
    });

    test('createHousehold sem householdId na resposta falha', () async {
      calls.response = {'ok': true};
      await expectLater(
        FirestoreHouseholdRepository(firestore: db, callable: invoker).createHousehold(familyId: 'f1', name: 'x'),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('FirestoreUserProfileRepository', () {
    test('watchProfile: doc inexistente = null; existente traz freeFamilyId', () async {
      final repo = FirestoreUserProfileRepository(db);
      expect(await repo.watchProfile('u1').first, isNull);
      await db.collection('users').doc('u1').set({'freeFamilyId': 'f1'});
      expect((await repo.watchProfile('u1').first)!.freeFamilyId, 'f1');
    });

    test('upsert escreve só os campos do cliente + updatedAt e não toca nos protegidos', () async {
      await db.collection('users').doc('u1').set({
        'displayName': 'Antigo',
        'email': 'a@b.c',
        'freeFamilyId': 'f1',
        'locale': 'pt-BR',
        'timezone': 'America/Sao_Paulo',
      });
      await FirestoreUserProfileRepository(db).upsertClientFields(
        'u1',
        displayName: '  Ana  ',
        photoUrl: 'https://x/y.png',
        locale: 'pt-BR',
        timezone: 'America/Manaus',
      );
      final d = (await db.collection('users').doc('u1').get()).data()!;
      expect(d['displayName'], 'Ana');
      expect(d['photoUrl'], 'https://x/y.png');
      expect(d['timezone'], 'America/Manaus');
      expect(d['updatedAt'], isNotNull);
      expect(d['email'], 'a@b.c');
      expect(d['freeFamilyId'], 'f1');
    });

    test('upsert ignora nome vazio/nulo e não envia nada se não há campos', () async {
      await db.collection('users').doc('u1').set({'displayName': 'Ana'});
      final repo = FirestoreUserProfileRepository(db);
      await repo.upsertClientFields('u1', displayName: '   ');
      final d = (await db.collection('users').doc('u1').get()).data()!;
      expect(d['displayName'], 'Ana');
      expect(d.containsKey('updatedAt'), isFalse);
    });

    test('upsert em doc inexistente vira AppFailure (não exceção de SDK)', () async {
      await expectLater(
        FirestoreUserProfileRepository(db).upsertClientFields('ghost', displayName: 'X'),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
