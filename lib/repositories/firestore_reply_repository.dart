import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreReplyRepository {
  final FirebaseFirestore _db;

  FirestoreReplyRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _replies =>
      _db.collection('replies').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllRepliesForPost(String rootPostId) {
    return _replies
        .where('rootPostId', isEqualTo: rootPostId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTopReplyPreview(String rootPostId) {
    return _replies
        .where('rootPostId', isEqualTo: rootPostId)
        .where('parentReplyId', isNull: true)
        .orderBy('engagement', descending: true)
        .limit(1)
        .snapshots();
  }

  /// Kullanıcı rolünü kontrol et (güvenlik)
  Future<String?> _getUserRole(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data()?['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Admin kontrolü (güvenlik)
  Future<bool> _isAdmin(String userId) async {
    try {
      final doc = await _db.collection('admins').doc(userId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> addReply({
    required String rootPostId,
    String? parentReplyId,
    required String text,
    required String authorId,
    required String authorName,
    required String authorUsername,
    required String authorRole,
    String? authorProfession,
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
  }) async {
    // 🔒 GÜVENLİK: Backend'de role kontrolü
    final actualRole = await _getUserRole(authorId);
    final isAdminUser = await _isAdmin(authorId);
    
    // ✅ DEBUG: Role kontrolü
    print('🔍 Reply Role Kontrolü: actualRole=$actualRole, isAdminUser=$isAdminUser, authorRole=$authorRole');
    
    // ✅ GÜVENLİK: Expert, Admin veya admins koleksiyonunda olmalı
    if (actualRole != 'expert' && actualRole != 'admin' && !isAdminUser && authorRole != 'expert' && authorRole != 'admin') {
      print('❌ Reply yetkisi yok: actualRole=$actualRole, isAdminUser=$isAdminUser, authorRole=$authorRole');
      throw Exception('Sadece uzmanlar ve adminler yorum yapabilir');
    }

    // Content validasyonu
    if (text.trim().isEmpty) {
      throw Exception('Yorum içeriği boş olamaz');
    }
    if (text.length > 500) {
      throw Exception('Yorum içeriği 500 karakterden uzun olamaz');
    }

    final cleanParent = (parentReplyId != null && parentReplyId.trim().isNotEmpty)
        ? parentReplyId.trim()
        : null;

    // ✅ TWITTER BENZERİ: Transaction kullanarak atomic operations
    await _db.runTransaction((tx) async {
      // Root post'u kontrol et
      final rootPostRef = _posts.doc(rootPostId);
      final rootPostDoc = await tx.get(rootPostRef);
      
      if (!rootPostDoc.exists) {
        throw Exception('Post bulunamadı');
      }

      // Parent reply'yi kontrol et (eğer nested reply ise)
      if (cleanParent != null) {
        final parentReplyRef = _replies.doc(cleanParent);
        final parentReplyDoc = await tx.get(parentReplyRef);
        
        if (!parentReplyDoc.exists) {
          throw Exception('Yanıtlanacak yorum bulunamadı');
        }
        
        // Parent reply'nin aynı root post'a ait olduğunu kontrol et
        final parentData = parentReplyDoc.data()!;
        if (parentData['rootPostId'] != rootPostId) {
          throw Exception('Geçersiz yorum thread\'i');
        }
      }

      // ✅ ATOMIC: Reply oluştur
      final replyRef = _replies.doc();
      tx.set(replyRef, {
        'rootPostId': rootPostId,
        'parentReplyId': cleanParent,
        'text': text,
        'authorId': authorId,
        'authorName': authorName,
        'authorUsername': authorUsername,
        'authorRole': authorRole,
        'authorProfession': authorProfession ?? '',
        'mediaUrl': mediaUrl ?? '',
        'mediaType': mediaType ?? '',
        'mediaName': mediaName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        'deleted': false,
        'likedBy': <String>[],
        'dislikedBy': <String>[],
        'likeCount': 0,
        'dislikeCount': 0,
        'replyCount': 0,
        'engagement': 0,
      });

      // ✅ ATOMIC: Root post'un reply sayısını artır
      tx.update(rootPostRef, {
        'stats.replyCount': FieldValue.increment(1),
      });

      // ✅ TWITTER BENZERİ: Nested reply ise parent'ın sayacını da artır
      if (cleanParent != null) {
        final parentReplyRef = _replies.doc(cleanParent);
        tx.update(parentReplyRef, {
          'replyCount': FieldValue.increment(1),
          'engagement': FieldValue.increment(1),
        });
      }
    });
  }

  Future<void> addChildReply({
    required String rootPostId,
    required String parentReplyId,
    required String text,
    required String authorId,
    required String authorName,
    required String authorUsername,
    required String authorRole,
    String? authorProfession,
  }) async {
    await addReply(
      rootPostId: rootPostId,
      parentReplyId: parentReplyId,
      text: text,
      authorId: authorId,
      authorName: authorName,
      authorUsername: authorUsername,
      authorRole: authorRole,
      authorProfession: authorProfession,
    );
  }

  Future<void> deleteReply({required String replyId}) async {
    await _replies.doc(replyId).update({
      'deleted': true,
      'text': '',
      'mediaUrl': '',
      'mediaType': '',
      'mediaName': '',
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleReplyLike({required String replyId, required String userId}) async {
    final ref = _replies.doc(replyId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final likedBy = _asStringList(data['likedBy']);
      final dislikedBy = _asStringList(data['dislikedBy']);

      int likeCount = _asInt(data['likeCount']);
      int dislikeCount = _asInt(data['dislikeCount']);
      final replyCount = _asInt(data['replyCount']);

      final updates = <String, dynamic>{};

      if (likedBy.contains(userId)) {
        updates['likedBy'] = FieldValue.arrayRemove([userId]);
        likeCount = (likeCount - 1) < 0 ? 0 : (likeCount - 1);
        updates['likeCount'] = likeCount;
      } else {
        updates['likedBy'] = FieldValue.arrayUnion([userId]);
        likeCount = likeCount + 1;
        updates['likeCount'] = likeCount;

        if (dislikedBy.contains(userId)) {
          updates['dislikedBy'] = FieldValue.arrayRemove([userId]);
          dislikeCount = (dislikeCount - 1) < 0 ? 0 : (dislikeCount - 1);
          updates['dislikeCount'] = dislikeCount;
        }
      }

      updates['engagement'] = (likeCount - dislikeCount) + replyCount;
      tx.update(ref, updates);
    });
  }

  Future<void> toggleReplyDislike({required String replyId, required String userId}) async {
    final ref = _replies.doc(replyId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final likedBy = _asStringList(data['likedBy']);
      final dislikedBy = _asStringList(data['dislikedBy']);

      int likeCount = _asInt(data['likeCount']);
      int dislikeCount = _asInt(data['dislikeCount']);
      final replyCount = _asInt(data['replyCount']);

      final updates = <String, dynamic>{};

      if (dislikedBy.contains(userId)) {
        updates['dislikedBy'] = FieldValue.arrayRemove([userId]);
        dislikeCount = (dislikeCount - 1) < 0 ? 0 : (dislikeCount - 1);
        updates['dislikeCount'] = dislikeCount;
      } else {
        updates['dislikedBy'] = FieldValue.arrayUnion([userId]);
        dislikeCount = dislikeCount + 1;
        updates['dislikeCount'] = dislikeCount;

        if (likedBy.contains(userId)) {
          updates['likedBy'] = FieldValue.arrayRemove([userId]);
          likeCount = (likeCount - 1) < 0 ? 0 : (likeCount - 1);
          updates['likeCount'] = likeCount;
        }
      }

      updates['engagement'] = (likeCount - dislikeCount) + replyCount;
      tx.update(ref, updates);
    });
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return <String>[];
  }
}
