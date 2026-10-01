import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planly/features/notifications/domain/device_repository.dart';

/// Rules (devices): o cliente escreve só o próprio doc; `createdAt` não muda no update;
/// o token vive em `fcmToken` (nunca em `token`).
class FirestoreDeviceRepository implements DeviceRepository {
  FirestoreDeviceRepository({required FirebaseFirestore firestore}) : _db = firestore;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String deviceId) =>
      _db.doc('users/$uid/devices/$deviceId');

  @override
  Future<void> register({
    required String uid,
    required String deviceId,
    required String fcmToken,
    String? locale,
    String? timezone,
  }) async {
    final ref = _doc(uid, deviceId);
    final fields = <String, Object?>{
      'fcmToken': fcmToken,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'locale': ?locale,
      'timezone': ?timezone,
    };
    Future<void> create() => ref.set({
          ...fields,
          'platform': 'android',
          'createdAt': FieldValue.serverTimestamp(),
        });

    final snap = await ref.get();
    if (!snap.exists) {
      try {
        await create();
        return;
      } on FirebaseException catch (e) {
        // Doc existia no servidor (cache vazio): o create vira update e é negado; atualiza.
        if (e.code != 'permission-denied') rethrow;
      }
    }
    await ref.update(fields);
  }

  @override
  Future<void> remove({required String uid, required String deviceId}) => _doc(uid, deviceId).delete();
}
