// ignore_for_file: invalid_use_of_protected_member
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';
import 'package:planly/core/sync/sync_status.dart';

void main() {
  group('syncStatusFor (spec §5.2)', () {
    test('pendente + offline = salvo neste dispositivo', () {
      expect(syncStatusFor(const SyncMeta(hasPendingWrites: true), online: false), SyncStatus.savedLocally);
      expect(syncStatusFor(const SyncMeta(hasPendingWrites: true, isFromCache: true), online: true),
          SyncStatus.savedLocally);
    });

    test('pendente + online = sincronizando', () {
      expect(syncStatusFor(const SyncMeta(hasPendingWrites: true), online: true), SyncStatus.syncing);
    });

    test('sem pendências e do servidor = sincronizado', () {
      expect(syncStatusFor(const SyncMeta(), online: true), SyncStatus.synced);
    });

    test('cache sem pendências: sincronizando se online, offline se não', () {
      expect(syncStatusFor(const SyncMeta(isFromCache: true), online: true), SyncStatus.syncing);
      expect(syncStatusFor(const SyncMeta(isFromCache: true), online: false), SyncStatus.offline);
    });
  });

  group('mapFirebaseError', () {
    FirebaseFunctionsException fn(String code, {Object? details}) =>
        FirebaseFunctionsException(message: 'x', code: code, details: details);

    test('reason do servidor vira BusinessFailure', () {
      expect(mapFirebaseError(fn('failed-precondition', details: {'reason': 'PLAN_LIMIT_HOUSEHOLDS'})),
          const BusinessFailure('PLAN_LIMIT_HOUSEHOLDS'));
      expect(mapFirebaseError(fn('permission-denied', details: {'reason': 'NOT_OWNER'})),
          const BusinessFailure('NOT_OWNER'));
      // deadline-exceeded COM reason é regra de negócio, não rede.
      expect(mapFirebaseError(fn('deadline-exceeded', details: {'reason': 'INVITE_EXPIRED'})),
          const BusinessFailure('INVITE_EXPIRED'));
    });

    test('sem reason: códigos genéricos', () {
      expect(mapFirebaseError(fn('unavailable')), isA<NetworkFailure>());
      expect(mapFirebaseError(fn('deadline-exceeded')), isA<NetworkFailure>());
      expect(mapFirebaseError(fn('unauthenticated')), isA<AccountFailure>());
      expect(mapFirebaseError(fn('permission-denied')), isA<PermissionDeniedFailure>());
      expect(mapFirebaseError(fn('resource-exhausted')), const BusinessFailure('RATE_LIMITED'));
      expect(mapFirebaseError(fn('internal')), isA<UnknownFailure>());
    });

    test('invalid-argument (reason = nome do campo) não vira regra de negócio', () {
      expect(mapFirebaseError(fn('invalid-argument', details: {'reason': 'name'})), isA<UnknownFailure>());
    });

    test('FirebaseException do Firestore', () {
      expect(mapFirebaseError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')),
          isA<PermissionDeniedFailure>());
      expect(mapFirebaseError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')),
          isA<NetworkFailure>());
      expect(mapFirebaseError(FirebaseException(plugin: 'cloud_firestore', code: 'xyz')), isA<UnknownFailure>());
      expect(mapFirebaseError(StateError('x')), isA<UnknownFailure>());
    });
  });
}
