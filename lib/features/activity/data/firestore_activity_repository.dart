import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';
import 'package:planly/features/activity/domain/activity_models.dart';
import 'package:planly/features/activity/domain/activity_repository.dart';

class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository({required FirebaseFirestore firestore})
    : _db = firestore;

  final FirebaseFirestore _db;

  @override
  Future<ActivityPage> fetchPage({
    required String familyId,
    required String householdId,
    int limit = activityPageSize,
    Object? cursor,
    String? actorId,
    DateTime? since,
  }) async {
    final size = limit.clamp(1, activityMaxPageSize);
    // Índices: `createdAt DESC` (automático) e `actorId ASC + createdAt DESC` (filtro por pessoa).
    Query<Map<String, dynamic>> query = _db
        .collection('families')
        .doc(familyId)
        .collection('households')
        .doc(householdId)
        .collection('activity');
    if (actorId != null) query = query.where('actorId', isEqualTo: actorId);
    if (since != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(since),
      );
    }
    query = query.orderBy('createdAt', descending: true);
    if (cursor is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(cursor);
    }
    // Pede 1 a mais para saber se há próxima página sem uma leitura extra.
    try {
      final snap = await query.limit(size + 1).get();
      final docs = snap.docs;
      final hasMore = docs.length > size;
      final page = hasMore ? docs.sublist(0, size) : docs;
      return ActivityPage(
        events: [for (final d in page) _event(d)],
        hasMore: hasMore,
        cursor: page.isEmpty ? cursor : page.last,
      );
    } catch (e) {
      throw mapFirebaseError(e);
    }
  }

  static ActivityEvent _event(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    String s(String k) => (data[k] as String?) ?? '';
    final created = data['createdAt'];
    return ActivityEvent(
      id: d.id,
      type: ActivityEventType.parse(data['type']),
      actorId: s('actorId'),
      actorName: s('actorName'),
      targetType: s('targetType'),
      targetId: s('targetId'),
      targetTitle: s('targetTitle'),
      createdAt: created is Timestamp ? created.toDate() : null,
      hasPendingWrites: d.metadata.hasPendingWrites,
    );
  }
}
