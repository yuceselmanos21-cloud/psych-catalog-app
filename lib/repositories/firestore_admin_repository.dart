import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Singleton pattern ile bellek optimizasyonu
class FirestoreAdminRepository {
  static FirestoreAdminRepository? _instance;
  static FirestoreAdminRepository get instance {
    _instance ??= FirestoreAdminRepository._();
    return _instance!;
  }

  FirestoreAdminRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _reports => _db.collection('reports');
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');
  // ✅ Yorumlar artık posts koleksiyonunda (isComment: true), replies koleksiyonu kullanılmıyor
  CollectionReference<Map<String, dynamic>> get _attachments => _db.collection('attachments');

  // -------- Expert Applications --------
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingExperts({int limit = 50}) {
    return _users
        .where('requestedRole', isEqualTo: 'expert')
        .where('expertStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<void> approveExpert({
    required String targetUid,
    required String adminUid,
  }) async {
    await _users.doc(targetUid).update({
      'role': 'expert',
      'expertStatus': 'approved',
      'expertReviewedAt': FieldValue.serverTimestamp(),
      'expertReviewedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectExpert({
    required String targetUid,
    required String adminUid,
  }) async {
    await _users.doc(targetUid).update({
      'role': 'client',
      'expertStatus': 'rejected',
      'expertReviewedAt': FieldValue.serverTimestamp(),
      'expertReviewedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // -------- Users --------
  Stream<QuerySnapshot<Map<String, dynamic>>> watchLatestUsers({int limit = 50}) {
    return _users.orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  Future<Map<String, dynamic>?> getUserByUsernameLower(String usernameLower) async {
    final q = usernameLower.trim().toLowerCase();
    if (q.isEmpty) return null;

    final snap = await _users.where('usernameLower', isEqualTo: q).limit(1).get();
    if (snap.docs.isEmpty) return null;

    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  Future<void> setBanned({
    required String targetUid,
    required bool banned,
    required String adminUid,
  }) async {
    await _users.doc(targetUid).update({
      'banned': banned,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setRole({
    required String targetUid,
    required String role, // client|expert|admin
    required String adminUid,
  }) async {
    final r = role.trim();
    if (r != 'client' && r != 'expert' && r != 'admin') {
      throw Exception('INVALID_ROLE');
    }

    await _users.doc(targetUid).update({
      'role': r,
      'updatedAt': FieldValue.serverTimestamp(),
      'roleUpdatedAt': FieldValue.serverTimestamp(),
      'roleUpdatedBy': adminUid,
    });
  }

  // -------- Reports --------
  Stream<QuerySnapshot<Map<String, dynamic>>> watchOpenReports({int limit = 100}) {
    return _reports
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<void> closeReport({
    required String reportId,
    required String adminUid,
  }) async {
    await _reports.doc(reportId).update({
      'status': 'closed',
      'handledBy': adminUid,
      'handledAt': FieldValue.serverTimestamp(),
    });
  }

  // -------- Moderation Actions --------

  String? _attIdFromUrl(String mediaUrl) {
    final s = mediaUrl.trim();
    if (!s.startsWith('att:')) return null;
    final id = s.substring(4).trim();
    return id.isEmpty ? null : id;
  }

  String? _attIdFromTextToken(String rawText) {
    final re = RegExp(r'\[\[att:([a-zA-Z0-9_-]+)\|([^|\]]*)\|([^|\]]*)\]\]');
    final m = re.firstMatch(rawText);
    if (m == null) return null;
    final id = (m.group(1) ?? '').trim();
    return id.isEmpty ? null : id;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> deletePostAsAdmin(String postId) async {
    final postRef = _posts.doc(postId);

    // Önce post'u oku ve reply'leri bul (transaction dışında)
    final postSnap = await postRef.get();
    if (!postSnap.exists) return;

    final data = postSnap.data() ?? <String, dynamic>{};
    final repostOf = (data['repostOfPostId'] ?? '').toString().trim();
    final isQuote = data['isQuoteRepost'] == true;

    // Attachment: mediaUrl veya token fallback
    final mediaUrl = (data['mediaUrl'] ?? '').toString().trim();
    String? attId = _attIdFromUrl(mediaUrl);
    attId ??= _attIdFromTextToken((data['content'] ?? data['text'] ?? '').toString());

    // ✅ Yorumlar artık posts koleksiyonunda (isComment: true)
    // Reply'leri bul (transaction dışında)
    final repliesQuery = await _posts
        .where('rootPostId', isEqualTo: postId)
        .where('isComment', isEqualTo: true)
        .get();
    final replyRefs = repliesQuery.docs.map((doc) => doc.reference).toList();

    // Transaction içinde tüm işlemleri yap
    await _db.runTransaction((tx) async {
      // RepostCount/quoteCount düşür
      if (repostOf.isNotEmpty) {
        final originalRef = _posts.doc(repostOf);
        final origSnap = await tx.get(originalRef);
        if (origSnap.exists) {
          final od = origSnap.data() ?? <String, dynamic>{};
          final stats = od['stats'] as Map<String, dynamic>? ?? <String, dynamic>{};
          
          if (isQuote) {
            final cur = _asInt(stats['quoteCount'] ?? 0);
            final next = (cur - 1).clamp(0, double.infinity).toInt();
            tx.update(originalRef, {'stats.quoteCount': next});
          } else {
            final cur = _asInt(stats['repostCount'] ?? 0);
            final next = (cur - 1).clamp(0, double.infinity).toInt();
            tx.update(originalRef, {'stats.repostCount': next});
          }
        }
      }

      // Reply'leri sil
      for (final replyRef in replyRefs) {
        tx.delete(replyRef);
      }

      // Attachment'ı sil
      if (attId != null) {
        tx.delete(_attachments.doc(attId));
      }

      // Post'u sil
      tx.delete(postRef);
    });
  }

  Future<void> softDeleteReplyAsAdmin(String replyId) async {
    // ✅ Yorumlar artık posts koleksiyonunda (isComment: true)
    final replyRef = _posts.doc(replyId);
    final replyDoc = await replyRef.get();
    
    if (!replyDoc.exists) {
      throw Exception('Yorum bulunamadı');
    }
    
    final data = replyDoc.data() ?? <String, dynamic>{};
    final rootPostId = (data['rootPostId'] ?? '').toString();
    final parentPostId = (data['parentPostId'] ?? '').toString();
    
    // ✅ SOFT DELETE: Yorumu silme, sadece deleted flag'i ekle
    await replyRef.update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': 'admin', // Admin tarafından silindi
      'content': FieldValue.delete(), // İçeriği kaldır
      'mediaUrl': FieldValue.delete(), // Eklentiyi kaldır
      'mediaType': FieldValue.delete(),
      'mediaName': FieldValue.delete(),
    });
    
    // ✅ Post'un replyCount'unu düşür (eğer top-level yorum ise)
    if (rootPostId.isNotEmpty) {
      final rootPostRef = _posts.doc(rootPostId);
      await rootPostRef.update({
        'stats.replyCount': FieldValue.increment(-1),
      });
      
      // ✅ Nested yorum ise (parentPostId != rootPostId), parent yorumun sayacını da düşür
      if (parentPostId.isNotEmpty && parentPostId != rootPostId) {
        final parentCommentRef = _posts.doc(parentPostId);
        await parentCommentRef.update({
          'stats.replyCount': FieldValue.increment(-1),
        });
      }
    }
  }

  // -------- Test Management --------
  Future<void> deleteTestAsAdmin(String testId) async {
    // ✅ Önce test dokümanını oku (görselleri temizlemek için)
    final testRef = _db.collection('tests').doc(testId);
    final testDoc = await testRef.get();
    
    if (!testDoc.exists) {
      throw Exception('Test bulunamadı');
    }
    
    final data = testDoc.data() ?? <String, dynamic>{};
    final questions = data['questions'];
    
    // ✅ Görsel sorular için görselleri Storage'dan sil
    if (questions is List) {
      for (final q in questions) {
        if (q is Map) {
          final type = q['type']?.toString() ?? '';
          if (type == 'image_question') {
            final imageUrl = q['imageUrl']?.toString();
            if (imageUrl != null && imageUrl.isNotEmpty) {
              try {
                // ✅ Firebase Storage URL'den path çıkar
                if (imageUrl.contains('firebasestorage.googleapis.com')) {
                  final uri = Uri.parse(imageUrl);
                  final pathSegments = uri.pathSegments;
                  
                  // Format: /v0/b/{bucket}/o/{encodedPath}
                  if (pathSegments.length >= 4 && pathSegments[0] == 'v0' && pathSegments[1] == 'b') {
                    final oIndex = pathSegments.indexOf('o');
                    if (oIndex != -1 && oIndex + 1 < pathSegments.length) {
                      final encodedPath = pathSegments[oIndex + 1];
                      final storagePath = Uri.decodeComponent(encodedPath);
                      final storageRef = _storage.ref().child(storagePath);
                      await storageRef.delete();
                    }
                  }
                }
              } catch (e) {
                // ✅ Storage silme hatası kritik değil, sessizce devam et
                // (Dosya zaten silinmiş olabilir veya URL formatı farklı olabilir)
              }
            }
          }
        }
      }
    }
    
    // ✅ Test dokümanını sil
    await testRef.delete();
  }

  // -------- Admin Management --------
  Future<void> addAdminByUid({
    required String targetUid,
    required String adminUid,
    String? usernameLower,
  }) async {
    await _db.collection('admins').doc(targetUid).set({
      if (usernameLower != null) 'usernameLower': usernameLower,
      'addedBy': adminUid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    // Kullanıcının role'ünü de admin yap
    await _users.doc(targetUid).update({
      'role': 'admin',
      'roleUpdatedAt': FieldValue.serverTimestamp(),
      'roleUpdatedBy': adminUid,
    });
  }

  Future<void> removeAdminByUid(String targetUid) async {
    await _db.collection('admins').doc(targetUid).delete();
    
    // Kullanıcının role'ünü client'a düşür (admin değilse)
    final userDoc = await _users.doc(targetUid).get();
    if (userDoc.exists) {
      final data = userDoc.data() ?? <String, dynamic>{};
      // Eğer role sadece admin koleksiyonundan geliyorsa, client yap
      // Ama eğer users'da da admin ise, orada da güncelle
      if (data['role'] == 'admin') {
        await _users.doc(targetUid).update({
          'role': 'client',
          'roleUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}
