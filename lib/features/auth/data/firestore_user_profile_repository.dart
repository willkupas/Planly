import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';
import 'package:planly/features/auth/domain/user_profile_repository.dart';

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((d) {
      if (!d.exists) return null;
      return UserProfile(freeFamilyId: d.data()?['freeFamilyId'] as String?);
    }).handleError((Object e) => throw mapFirebaseError(e));
  }

  @override
  Future<void> upsertClientFields(
    String uid, {
    String? displayName,
    String? photoUrl,
    String? locale,
    String? timezone,
  }) async {
    final name = displayName?.trim();
    final data = <String, Object?>{
      if (name != null && name.isNotEmpty) 'displayName': name.length > 100 ? name.substring(0, 100) : name,
      if (photoUrl != null && photoUrl.isNotEmpty && photoUrl.length <= 2048) 'photoUrl': photoUrl,
      'locale': ?locale,
      'timezone': ?timezone,
    };
    if (data.isEmpty) return;
    data['updatedAt'] = FieldValue.serverTimestamp();
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      throw mapFirebaseError(e);
    }
  }
}
