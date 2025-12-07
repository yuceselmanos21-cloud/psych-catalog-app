import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_repository.dart';

class FirestorePostRepository implements PostRepository {
  final FirebaseFirestore _db;

  FirestorePostRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> _baseTwitterFields() {
    return {
      'likeCount': 0,
      'replyCount': 0,
      'repostCount': 0,
      'quoteCount': 0,
      'likedBy': <String>[],
      'repostOfPostId': null,
      'editedAt': null,
    };
  }

  // ---------------- POST OLUŞTURMA ----------------
  @override
  Future<void> sendPost(
      String content, {
        String? authorId,
        String? authorName,
        String? authorRole,
        String type = 'text',
      }) async {
    final text = content.trim();
    if (text.isEmpty) return;

    final payload = <String, dynamic>{
      'text': text,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      ..._baseTwitterFields(),
    };

    if (authorId != null) payload['authorId'] = authorId;
    if (authorName != null) payload['authorName'] = authorName;
    if (authorRole != null) payload['authorRole'] = authorRole;

    await _db.collection('posts').add(payload);
  }

  // ---------------- OKUMA ----------------
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchFeed() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPost(String postId) {
    return _db.collection('posts').doc(postId).snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchReplies(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('replies')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ---------------- YANIT ----------------
  @override
  Future<void> addReply({
    required String postId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final postRef = _db.collection('posts').doc(postId);
    final replyRef = postRef.collection('replies').doc();

    final batch = _db.batch();

    batch.set(replyRef, {
      'text': trimmed,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(postRef, {
      'replyCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // ---------------- LIKE ----------------
  @override
  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final ref = _db.collection('posts').doc(postId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>? ?? {};
      final raw = data['likedBy'];

      final likedBy = raw is List
          ? raw.map((e) => e.toString()).toList()
          : <String>[];

      int likeCount = _asInt(data['likeCount'] ?? likedBy.length);

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        likeCount = likeCount > 0 ? likeCount - 1 : 0;
      } else {
        likedBy.add(userId);
        likeCount = likeCount + 1;
      }

      tx.update(ref, {
        'likedBy': likedBy,
        'likeCount': likeCount,
      });
    });
  }

  // ---------------- REPOST ----------------
  @override
  Future<void> repostPost({
    required String originalPostId,
    required String text,
    required String type,
    required String authorId,
    required String authorName,
    required String authorRole,
  }) async {
    final originalRef = _db.collection('posts').doc(originalPostId);

    await originalRef.update({
      'repostCount': FieldValue.increment(1),
    });

    await _db.collection('posts').add({
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      ..._baseTwitterFields(),
      'repostOfPostId': originalPostId,
    });
  }

  // ---------------- DÜZENLE ----------------
  @override
  Future<void> updatePostText({
    required String postId,
    required String newText,
  }) async {
    final text = newText.trim();
    if (text.isEmpty) return;

    await _db.collection('posts').doc(postId).update({
      'text': text,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- SİL ----------------
  @override
  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
    // Replies alt koleksiyonu otomatik silinmez.
    // İleride Cloud Function ile temizleyebiliriz.
  }
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPostsByAuthor(
      String authorId, {
        int limit = 10,
      }) {
    return _db
        .collection('posts')
        .where('authorId', isEqualTo: authorId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

}
