import 'package:cloud_firestore/cloud_firestore.dart';
import 'follow_repository.dart';

class FirestoreFollowRepository implements FollowRepository {
  final FirebaseFirestore _db;

  FirestoreFollowRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _followersCol(String expertId) =>
      _userDoc(expertId).collection('followers');

  CollectionReference<Map<String, dynamic>> _followingCol(String userId) =>
      _userDoc(userId).collection('following');

  DocumentReference<Map<String, dynamic>> _followerDoc({
    required String expertId,
    required String currentUserId,
  }) =>
      _followersCol(expertId).doc(currentUserId);

  DocumentReference<Map<String, dynamic>> _followingDoc({
    required String currentUserId,
    required String expertId,
  }) =>
      _followingCol(currentUserId).doc(expertId);

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

  /// ✅ Sayaçlar artık user doc alanından değil,
  /// subcollection size üzerinden gelir -> rules ile uyumlu
  @override
  Stream<int> watchFollowersCount(String expertId) {
    return _followersCol(expertId).snapshots().map((snap) => snap.size);
  }

  @override
  Stream<int> watchFollowingCount(String userId) {
    return _followingCol(userId).snapshots().map((snap) => snap.size);
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

    await _db.runTransaction((tx) async {
      final followerSnap = await tx.get(followerRef);
      if (followerSnap.exists) return;

      tx.set(followerRef, {
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(followingRef, {
        'expertId': expertId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
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

    await _db.runTransaction((tx) async {
      final followerSnap = await tx.get(followerRef);
      if (!followerSnap.exists) return;

      tx.delete(followerRef);
      tx.delete(followingRef);
    });
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
