import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_repository.dart';

class FirestorePostRepository implements PostRepository {
  final FirebaseFirestore _db;

  FirestorePostRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
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

  // ✅ Reply alanları (like/dislike + alt yanıt sayısı)
  Map<String, dynamic> _baseReplyFields() {
    return {
      'likeCount': 0,
      'dislikeCount': 0,
      'likedBy': <String>[],
      'dislikedBy': <String>[],
      'replyCount': 0, // child replies sayısı
      'editedAt': null,
    };
  }

  DocumentReference<Map<String, dynamic>> _postRef(String postId) =>
      _db.collection('posts').doc(postId);

  DocumentReference<Map<String, dynamic>> _replyRef(
      String postId,
      String replyId,
      ) =>
      _postRef(postId).collection('replies').doc(replyId);

  DocumentReference<Map<String, dynamic>> _childReplyRef(
      String postId,
      String parentReplyId,
      String childReplyId,
      ) =>
      _replyRef(postId, parentReplyId).collection('replies').doc(childReplyId);

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
  Stream<QuerySnapshot<Map<String, dynamic>>> watchFeed({int? limit}) {
    Query<Map<String, dynamic>> q =
    _db.collection('posts').orderBy('createdAt', descending: true);

    if (limit != null && limit > 0) {
      q = q.limit(limit);
    }

    return q.snapshots();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPost(String postId) {
    return _postRef(postId).snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchReplies(
      String postId, {
        int? limit,
      }) {
    Query<Map<String, dynamic>> q = _postRef(postId)
        .collection('replies')
        .orderBy('createdAt', descending: true);

    if (limit != null && limit > 0) {
      q = q.limit(limit);
    }

    return q.snapshots();
  }

  // ✅ Child replies (yoruma yorum)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchChildReplies(
      String postId,
      String parentReplyId, {
        int? limit,
      }) {
    Query<Map<String, dynamic>> q = _replyRef(postId, parentReplyId)
        .collection('replies')
        .orderBy('createdAt', descending: true);

    if (limit != null && limit > 0) {
      q = q.limit(limit);
    }

    return q.snapshots();
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

  // ---------------- YANIT (POST'A) ----------------
  @override
  Future<void> addReply({
    required String postId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final postRef = _postRef(postId);
    final replyRef = postRef.collection('replies').doc();

    final batch = _db.batch();

    batch.set(replyRef, {
      'text': trimmed,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
      ..._baseReplyFields(),
    });

    batch.update(postRef, {
      'replyCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // ✅ YORUMA YANIT (1 seviye)
  Future<void> addChildReply({
    required String postId,
    required String parentReplyId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final parentRef = _replyRef(postId, parentReplyId);
    final childRef = parentRef.collection('replies').doc();

    final batch = _db.batch();

    batch.set(childRef, {
      'text': trimmed,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
      ..._baseReplyFields(),
    });

    // parent replyCount +1
    batch.set(
      parentRef,
      {'replyCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ---------------- LIKE (POST) ----------------
  @override
  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final ref = _postRef(postId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>? ?? {};
      final raw = data['likedBy'];

      final likedBy =
      raw is List ? raw.map((e) => e.toString()).toList() : <String>[];

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

  // ---------------- REPLY REACTIONS ----------------

  Future<void> _toggleReactionOnRef({
    required DocumentReference<Map<String, dynamic>> ref,
    required String userId,
    required bool isDislike,
  }) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};

      final likedByRaw = data['likedBy'];
      final dislikedByRaw = data['dislikedBy'];

      final likedBy = likedByRaw is List
          ? likedByRaw.map((e) => e.toString()).toList()
          : <String>[];

      final dislikedBy = dislikedByRaw is List
          ? dislikedByRaw.map((e) => e.toString()).toList()
          : <String>[];

      int likeCount = _asInt(data['likeCount'] ?? likedBy.length);
      int dislikeCount = _asInt(data['dislikeCount'] ?? dislikedBy.length);

      if (!isDislike) {
        // ✅ Like toggle
        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          likeCount = likeCount > 0 ? likeCount - 1 : 0;
        } else {
          likedBy.add(userId);
          likeCount = likeCount + 1;

          // Eğer dislike vardıysa kaldır
          if (dislikedBy.remove(userId)) {
            dislikeCount = dislikeCount > 0 ? dislikeCount - 1 : 0;
          }
        }
      } else {
        // ✅ Dislike toggle
        if (dislikedBy.contains(userId)) {
          dislikedBy.remove(userId);
          dislikeCount = dislikeCount > 0 ? dislikeCount - 1 : 0;
        } else {
          dislikedBy.add(userId);
          dislikeCount = dislikeCount + 1;

          // Eğer like vardıysa kaldır
          if (likedBy.remove(userId)) {
            likeCount = likeCount > 0 ? likeCount - 1 : 0;
          }
        }
      }

      tx.set(
        ref,
        {
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
          'likeCount': likeCount,
          'dislikeCount': dislikeCount,
        },
        SetOptions(merge: true),
      );
    });
  }

  // ✅ Top-level reply like/dislike
  Future<void> toggleReplyLike({
    required String postId,
    required String replyId,
    required String userId,
  }) {
    return _toggleReactionOnRef(
      ref: _replyRef(postId, replyId),
      userId: userId,
      isDislike: false,
    );
  }

  Future<void> toggleReplyDislike({
    required String postId,
    required String replyId,
    required String userId,
  }) {
    return _toggleReactionOnRef(
      ref: _replyRef(postId, replyId),
      userId: userId,
      isDislike: true,
    );
  }

  // ✅ Child reply like/dislike
  Future<void> toggleChildReplyLike({
    required String postId,
    required String parentReplyId,
    required String replyId,
    required String userId,
  }) {
    return _toggleReactionOnRef(
      ref: _childReplyRef(postId, parentReplyId, replyId),
      userId: userId,
      isDislike: false,
    );
  }

  Future<void> toggleChildReplyDislike({
    required String postId,
    required String parentReplyId,
    required String replyId,
    required String userId,
  }) {
    return _toggleReactionOnRef(
      ref: _childReplyRef(postId, parentReplyId, replyId),
      userId: userId,
      isDislike: true,
    );
  }

  // ---------------- REPOST (✅ daha sağlam) ----------------
  @override
  Future<void> repostPost({
    required String originalPostId,
    required String text,
    required String type,
    required String authorId,
    required String authorName,
    required String authorRole,
  }) async {
    final originalRef = _postRef(originalPostId);
    final newRef = _db.collection('posts').doc();

    final batch = _db.batch();

    batch.update(originalRef, {
      'repostCount': FieldValue.increment(1),
    });

    batch.set(newRef, {
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      ..._baseTwitterFields(),
      'repostOfPostId': originalPostId,
    });

    await batch.commit();
  }

  // ---------------- DÜZENLE ----------------
  @override
  Future<void> updatePostText({
    required String postId,
    required String newText,
  }) async {
    final text = newText.trim();
    if (text.isEmpty) return;

    await _postRef(postId).update({
      'text': text,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- SİL ----------------
  @override
  Future<void> deletePost(String postId) async {
    await _postRef(postId).delete();
  }
}
