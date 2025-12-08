import 'package:cloud_firestore/cloud_firestore.dart';
import 'follow_repository.dart';

class FirestoreFollowRepository implements FollowRepository {
  final FirebaseFirestore _db;

  FirestoreFollowRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _followerDoc({
    required String expertId,
    required String currentUserId,
  }) =>
      _userDoc(expertId).collection('followers').doc(currentUserId);

  DocumentReference<Map<String, dynamic>> _followingDoc({
    required String currentUserId,
    required String expertId,
  }) =>
      _userDoc(currentUserId).collection('following').doc(expertId);

  @override
  Stream<bool> watchIsFollowing({
    required String currentUserId,
    required String expertId,
  }) {
    return _followingDoc(
      currentUserId: currentUserId,
      expertId: expertId,
    ).snapshots().map((doc) => doc.exists);
  }

  @override
  Stream<int> watchFollowersCount(String expertId) {
    return _userDoc(expertId).snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      final v = data['followersCount'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    });
  }

  @override
  Stream<int> watchFollowingCount(String userId) {
    return _userDoc(userId).snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      final v = data['followingCount'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    });
  }

  @override
  Future<void> follow({
    required String currentUserId,
    required String expertId,
  }) async {
    if (currentUserId == expertId) return;

    final followerRef = _followerDoc(
      expertId: expertId,
      currentUserId: currentUserId,
    );
    final followingRef = _followingDoc(
      currentUserId: currentUserId,
      expertId: expertId,
    );

    bool created = false;

    await _db.runTransaction((tx) async {
      final followerSnap = await tx.get(followerRef);
      if (followerSnap.exists) return;

      created = true;

      tx.set(followerRef, {
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(followingRef, {
        'expertId': expertId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    // ✅ Best-effort counter (rules izin verirse)
    if (created) {
      try {
        await _userDoc(expertId).set(
          {'followersCount': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
        await _userDoc(currentUserId).set(
          {'followingCount': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      } catch (_) {
        // Prod rules sıkıysa burada sessiz geçer; follow yine çalışır.
      }
    }
  }

  @override
  Future<void> unfollow({
    required String currentUserId,
    required String expertId,
  }) async {
    if (currentUserId == expertId) return;

    final followerRef = _followerDoc(
      expertId: expertId,
      currentUserId: currentUserId,
    );
    final followingRef = _followingDoc(
      currentUserId: currentUserId,
      expertId: expertId,
    );

    bool removed = false;

    await _db.runTransaction((tx) async {
      final followerSnap = await tx.get(followerRef);
      if (!followerSnap.exists) return;

      removed = true;

      tx.delete(followerRef);
      tx.delete(followingRef);
    });

    // ✅ Best-effort counter
    if (removed) {
      try {
        await _userDoc(expertId).set(
          {'followersCount': FieldValue.increment(-1)},
          SetOptions(merge: true),
        );
        await _userDoc(currentUserId).set(
          {'followingCount': FieldValue.increment(-1)},
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> toggleFollow({
    required String currentUserId,
    required String expertId,
  }) async {
    final followingRef = _followingDoc(
      currentUserId: currentUserId,
      expertId: expertId,
    );

    final snap = await followingRef.get();
    if (snap.exists) {
      await unfollow(currentUserId: currentUserId, expertId: expertId);
    } else {
      await follow(currentUserId: currentUserId, expertId: expertId);
    }
  }
}
