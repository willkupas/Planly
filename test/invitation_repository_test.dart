import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/invitation/data/firestore_invitation_repository.dart';
import 'package:planly/features/invitation/domain/invitation_models.dart';

void main() {
  late FakeFirebaseFirestore db;
  late List<String> names;
  late List<Map<String, Object?>> payloads;
  late Map<String, dynamic> response;
  late FirestoreInvitationRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    names = [];
    payloads = [];
    response = {'ok': true};
    repo = FirestoreInvitationRepository(
      firestore: db,
      callable: (name, data) async {
        names.add(name);
        payloads.add(data);
        return response;
      },
    );
  });

  group('código', () {
    test('normaliza, formata e mascara', () {
      expect(normalizeInviteCode(' abcde-fgh jk '), 'ABCDEFGHJK');
      expect(formatInviteCode('abcdefghjk'), 'ABCDE-FGHJK');
      expect(maskInviteCode('ABCDEFGHJK'), '•••••-•••JK');
      expect(maskInviteCode('curto'), isNot(contains('c')));
    });

    test('status efetivo: pendente vencido vira expirado', () {
      final now = DateTime(2026, 1, 1, 12);
      Invitation of(InvitationStatus s, DateTime exp) =>
          Invitation(code: 'X', familyId: 'f', grants: const [], status: s, expiresAt: exp);
      expect(of(InvitationStatus.pending, now.add(const Duration(hours: 1))).effectiveStatus(now),
          InvitationStatus.pending);
      expect(of(InvitationStatus.pending, now).effectiveStatus(now), InvitationStatus.expired);
      expect(of(InvitationStatus.accepted, now.subtract(const Duration(days: 1))).effectiveStatus(now),
          InvitationStatus.accepted);
    });
  });

  group('FirestoreInvitationRepository', () {
    test('watchCreatedBy lê só os convites do uid e converte campos', () async {
      final exp = DateTime.utc(2026, 5, 1, 10);
      await db.collection('invitations').doc('AAAAAAAA23').set({
        'familyId': 'f1',
        'createdBy': 'u1',
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(exp),
        'grants': [
          {'householdId': 'h1', 'role': 'admin'},
          {'householdId': 'h2', 'role': 'member'},
          {'householdId': 'h3', 'role': 'invalido'},
        ],
      });
      await db.collection('invitations').doc('BBBBBBBB34').set({
        'familyId': 'f1',
        'createdBy': 'outro',
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(exp),
        'grants': [],
      });
      final list = await repo.watchCreatedBy('u1').first;
      expect(list, hasLength(1));
      expect(list.single.code, 'AAAAAAAA23');
      expect(list.single.status, InvitationStatus.pending);
      expect(list.single.expiresAt.toUtc(), exp);
      expect(list.single.grants, [
        const InviteGrant(householdId: 'h1', role: HouseholdRole.admin),
        const InviteGrant(householdId: 'h2', role: HouseholdRole.member),
      ]);
    });

    test('createInvitation envia grants e lê code/link/expiresAt (ISO)', () async {
      response = {
        'ok': true,
        'code': 'ABCDEFGHJK',
        'link': 'https://planly.app/join/ABCDEFGHJK',
        'expiresAt': '2026-05-02T10:00:00.000Z',
      };
      final out = await repo.createInvitation(
        familyId: 'f1',
        grants: const [InviteGrant(householdId: 'h1', role: HouseholdRole.admin)],
      );
      expect(names.single, 'createInvitation');
      expect(payloads.single, {
        'familyId': 'f1',
        'grants': [
          {'householdId': 'h1', 'role': 'admin'},
        ],
      });
      expect(out.code, 'ABCDEFGHJK');
      expect(out.expiresAt, DateTime.utc(2026, 5, 2, 10));
    });

    test('createInvitation com resposta inválida vira UnknownFailure', () async {
      response = {'ok': true};
      expect(
        () => repo.createInvitation(familyId: 'f1', grants: const []),
        throwsA(isA<UnknownFailure>()),
      );
    });

    test('revoke e accept chamam as callables certas', () async {
      await repo.revokeInvitation('ABCDEFGHJK');
      response = {'ok': true, 'familyId': 'f9', 'householdIds': ['h1', 'h2']};
      final out = await repo.acceptInvitation('ABCDEFGHJK');
      expect(names, ['revokeInvitation', 'acceptInvitation']);
      expect(payloads, [
        {'code': 'ABCDEFGHJK'},
        {'code': 'ABCDEFGHJK'},
      ]);
      expect(out.familyId, 'f9');
      expect(out.householdIds, ['h1', 'h2']);
    });

    test('accept sem familyId vira UnknownFailure; falhas da callable propagam', () async {
      response = {'ok': true};
      expect(() => repo.acceptInvitation('ABCDEFGHJK'), throwsA(isA<UnknownFailure>()));
      final failing = FirestoreInvitationRepository(
        firestore: db,
        callable: (_, _) async => throw const BusinessFailure('INVITE_NOT_FOUND'),
      );
      expect(() => failing.acceptInvitation('X'), throwsA(const BusinessFailure('INVITE_NOT_FOUND')));
    });
  });
}
