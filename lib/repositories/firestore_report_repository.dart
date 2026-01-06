import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreReportRepository {
  final FirebaseFirestore _db;

  FirestoreReportRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  Future<void> createReport({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception('NO_SESSION');

    final cleanTargetType = targetType.trim();
    final cleanTargetId = targetId.trim();
    final cleanReason = reason.trim();

    if (cleanTargetType.isEmpty || cleanTargetId.isEmpty || cleanReason.isEmpty) {
      throw Exception('INVALID_REPORT');
    }

    await _reports.add({
      'createdBy': me.uid,
      'targetType': cleanTargetType,
      'targetId': cleanTargetId,
      'reason': cleanReason,
      'details': details.trim(),
      'status': 'open',
      'handledBy': '',
      'handledAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
