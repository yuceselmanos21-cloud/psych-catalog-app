import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class FirestoreReportRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  FirestoreReportRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  Future<void> createReport({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
    File? attachment,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception('NO_SESSION');

    final cleanTargetType = targetType.trim();
    final cleanTargetId = targetId.trim();
    final cleanReason = reason.trim();

    if (cleanTargetType.isEmpty || cleanTargetId.isEmpty || cleanReason.isEmpty) {
      throw Exception('INVALID_REPORT');
    }

    String? attachmentUrl;
    if (attachment != null) {
      try {
        final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}_${path.basename(attachment.path)}';
        final ref = _storage.ref().child('report_attachments/$me.uid/$fileName');
        await ref.putFile(attachment);
        attachmentUrl = await ref.getDownloadURL();
      } catch (e) {
        // Attachment yüklenemezse hata fırlatma, sadece log
        debugPrint('⚠️ Report attachment yüklenemedi: $e');
      }
    }

    await _reports.add({
      'createdBy': me.uid,
      'targetType': cleanTargetType,
      'targetId': cleanTargetId,
      'reason': cleanReason,
      'details': details.trim(),
      'attachmentUrl': attachmentUrl,
      'status': 'open',
      'handledBy': '',
      'handledAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
