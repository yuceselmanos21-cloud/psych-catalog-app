import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_repository.dart';

class FirestorePostRepository implements PostRepository {
  final FirebaseFirestore _db;

  FirestorePostRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // ---------------- HELPERS ----------------

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return <String>[];
  }

  Map<String, dynamic> _baseTwitterFields() {
    return {
      'likeCount': 0,
      'replyCount': 0, // top-level yorum sayısı
      'repostCount': 0,
      'quoteCount': 0,
      'likedBy': <String>[],
      'repostOfPostId': null,
      'editedAt': null,
    };
  }

  Map<String, dynamic> _baseReplyFields() {
    return {
      'likeCount': 0,
      'dislikeCount': 0,
      'likedBy': <String>[],
      'dislikedBy': <String>[],
      'replyCount': 0, // child sayısı
      'editedAt': null,
      'deleted': false,
    };
  }

  // ---------------- REFS ----------------

  DocumentReference<Map<String, dynamic>> _postRef(String postId) =>
      _db.collection('posts').doc(postId);

  DocumentReference<Map<String, dynamic>> _replyRef(String replyId) =>
      _db.collection('replies').doc(replyId);

  // ---------------- POSTS: CREATE ----------------

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

  // ---------------- POSTS: READ ----------------

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

  // ---------------- REPLIES: READ (GLOBAL MODEL) ----------------

  /// Top-level replies: parentReplyId == null
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchReplies(
      String postId, {
        int? limit,
      }) {
    Query<Map<String, dynamic>> q = _db
        .collection('replies')
        .where('rootPostId', isEqualTo: postId)
        .where('parentReplyId', isNull: true)
        .orderBy('createdAt', descending: true);

    if (limit != null && limit > 0) {
      q = q.limit(limit);
    }

    return q.snapshots();
  }

  /// Child replies of any reply
  Stream<QuerySnapshot<Map<String, dynamic>>> watchChildReplies(
      String postId, // eski imza uyumu için duruyor
      String parentReplyId, {
        int? limit,
      }) {
    Query<Map<String, dynamic>> q = _db
        .collection('replies')
        .where('parentReplyId', isEqualTo: parentReplyId)
        .orderBy('createdAt', descending: true);

    if (limit != null && limit > 0) {
      q = q.limit(limit);
    }

    return q.snapshots();
  }

  /// PostDetail için: post’a bağlı tüm replies (top + child)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllRepliesForPost(
      String postId, {
        int? limit,
      }) {
    Query<Map<String, dynamic>> q = _db
        .collection('replies')
        .where('rootPostId', isEqualTo: postId)
        .orderBy('createdAt', descending: true);

    if (limit != null && limit > 0) {
      q = q.limit(limit);
    }

    return q.snapshots();
  }

  // ---------------- REPLIES: CREATE ----------------

  /// Post'a top-level yorum
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
    final replyRef = _db.collection('replies').doc();

    final batch = _db.batch();

    batch.set(replyRef, {
      'rootPostId': postId,
      'parentReplyId': null,
      'text': trimmed,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
      ..._baseReplyFields(),
    });

    // top-level yorum sayısı
    batch.update(postRef, {
      'replyCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Reply’ye reply (child)
  Future<void> addChildReply({
    required String postId,
    required String parentReplyId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final parentRef = _replyRef(parentReplyId);
    final childRef = _db.collection('replies').doc();

    final batch = _db.batch();

    batch.set(childRef, {
      'rootPostId': postId,
      'parentReplyId': parentReplyId,
      'text': trimmed,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
      ..._baseReplyFields(),
    });

    // parent'ın child sayısı
    batch.set(
      parentRef,
      {'replyCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ---------------- REPLIES: DELETE (FIXED) ----------------

  /// Global model uyumlu yorum silme.
  /// - Çocuk varsa: soft delete (ağacı korur)
  /// - Çocuk yoksa: hard delete + sayaç düzeltme
  Future<void> deleteReply({
    required String postId,
    required String replyId,
    required String userId,
  }) async {
    final replyRef = _replyRef(replyId);
    final postRef = _postRef(postId);

    await _db.runTransaction((tx) async {
      final replySnap = await tx.get(replyRef);
      if (!replySnap.exists) return;

      final data = replySnap.data() ?? <String, dynamic>{};

      final authorId = data['authorId']?.toString();
      if (authorId != null && authorId != userId) {
        throw Exception('not-owner');
      }

      final parentReplyId = data['parentReplyId']?.toString();
      final childCount = _asInt(data['replyCount'] ?? 0);

      // Child varsa -> soft delete
      if (childCount > 0) {
        tx.set(
          replyRef,
          {
            'text': '[Silindi]',
            'deleted': true,
            'editedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return;
      }

      // Leaf -> hard delete
      tx.delete(replyRef);

      // Sayaç düzeltme (increment ile daha stabil)
      if (parentReplyId == null || parentReplyId.isEmpty) {
        tx.set(
          postRef,
          {'replyCount': FieldValue.increment(-1)},
          SetOptions(merge: true),
        );
      } else {
        final parentRef = _replyRef(parentReplyId);
        tx.set(
          parentRef,
          {'replyCount': FieldValue.increment(-1)},
          SetOptions(merge: true),
        );
      }
    });
  }

  // ---------------- POSTS: LIKE ----------------

  @override
  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final ref = _postRef(postId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final likedBy = _asStringList(data['likedBy']);

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

  // ---------------- REPLIES: LIKE / DISLIKE ----------------

  Future<void> _toggleReactionOnRef({
    required DocumentReference<Map<String, dynamic>> ref,
    required String userId,
    required bool isDislike,
  }) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};

      final likedBy = _asStringList(data['likedBy']);
      final dislikedBy = _asStringList(data['dislikedBy']);

      int likeCount = _asInt(data['likeCount'] ?? likedBy.length);
      int dislikeCount = _asInt(data['dislikeCount'] ?? dislikedBy.length);

      if (!isDislike) {
        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          likeCount = likeCount > 0 ? likeCount - 1 : 0;
        } else {
          likedBy.add(userId);
          likeCount = likeCount + 1;

          if (dislikedBy.remove(userId)) {
            dislikeCount = dislikeCount > 0 ? dislikeCount - 1 : 0;
          }
        }
      } else {
        if (dislikedBy.contains(userId)) {
          dislikedBy.remove(userId);
          dislikeCount = dislikeCount > 0 ? dislikeCount - 1 : 0;
        } else {
          dislikedBy.add(userId);
          dislikeCount = dislikeCount + 1;

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

  Future<void> toggleReplyLike({
    required String postId,
    required String replyId,
    required String userId,
  }) {
    return _toggleReactionOnRef(
      ref: _replyRef(replyId),
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
      ref: _replyRef(replyId),
      userId: userId,
      isDislike: true,
    );
  }

  Future<void> toggleChildReplyLike({
    required String postId,
    required String parentReplyId,
    required String replyId,
    required String userId,
  }) {
    return _toggleReactionOnRef(
      ref: _replyRef(replyId),
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
      ref: _replyRef(replyId),
      userId: userId,
      isDislike: true,
    );
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

  // ---------------- EDIT ----------------

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

  // ---------------- DELETE ----------------

  @override
  Future<void> deletePost(String postId) async {
    await _postRef(postId).delete();
  }
}
