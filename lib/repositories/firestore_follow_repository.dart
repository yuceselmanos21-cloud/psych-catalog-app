import 'package:cloud_firestore/cloud_firestore.dart';
import 'follow_repository.dart';

/// Follow model:
/// - /users/{uid}/following/{targetId}
/// - /users/{targetId}/followers/{uid}
///
/// This repository does NOT try to maintain counters in /users documents.
/// Counts are derived from the size of the followers/following subcollections,
/// which works on the Spark plan (no Cloud Functions needed).
class FirestoreFollowRepository implements FollowRepository {
  final FirebaseFirestore _db;

  FirestoreFollowRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _users() =>
      _db.collection('users').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );

  CollectionReference<Map<String, dynamic>> _followingCol(String uid) =>
      _users().doc(uid).collection('following').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );

  CollectionReference<Map<String, dynamic>> _followersCol(String targetId) =>
      _users().doc(targetId).collection('followers').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );

  /// True if current user follows [expertId].
  @override
  Stream<bool> watchIsFollowing({
    required String currentUserId,
    required String expertId,
  }) {
    final ref = _followingCol(currentUserId).doc(expertId);
    return ref.snapshots().map((snap) => snap.exists);
  }

  /// Live followers count (derived from subcollection size).
  @override
  Stream<int> watchFollowersCount(String userId) {
    return _followersCol(userId).snapshots().map((q) => q.size);
  }

  /// Live following count (derived from subcollection size).
  @override
  Stream<int> watchFollowingCount(String userId) {
    return _followingCol(userId).snapshots().map((q) => q.size);
  }

  /// Follow atomically via batch
  @override
  Future<void> follow({
    required String currentUserId,
    required String expertId,
  }) async {
    if (currentUserId.trim().isEmpty) {
      throw ArgumentError('currentUserId is empty');
    }
    if (expertId.trim().isEmpty) {
      throw ArgumentError('expertId is empty');
    }
    if (currentUserId == expertId) return;

    final followingRef = _followingCol(currentUserId).doc(expertId);
    final followerRef = _followersCol(expertId).doc(currentUserId);

    final snap = await followingRef.get();
    if (snap.exists) return; // Already following

    final batch = _db.batch();
    batch.set(followingRef, <String, dynamic>{
      'targetId': expertId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(followerRef, <String, dynamic>{
      'followerId': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Unfollow atomically via batch
  @override
  Future<void> unfollow({
    required String currentUserId,
    required String expertId,
  }) async {
    if (currentUserId.trim().isEmpty) {
      throw ArgumentError('currentUserId is empty');
    }
    if (expertId.trim().isEmpty) {
      throw ArgumentError('expertId is empty');
    }
    if (currentUserId == expertId) return;

    final followingRef = _followingCol(currentUserId).doc(expertId);
    final followerRef = _followersCol(expertId).doc(currentUserId);

    final snap = await followingRef.get();
    if (!snap.exists) return; // Not following

    final batch = _db.batch();
    batch.delete(followingRef);
    batch.delete(followerRef);

    await batch.commit();
  }

  /// Follow/unfollow atomically via batch:
  /// - create/delete /users/{currentUserId}/following/{expertId}
  /// - create/delete /users/{expertId}/followers/{currentUserId}
  ///
  /// NOTE: The Firestore rules must allow:
  /// - following create/delete only by owner (currentUserId)
  /// - followers create/delete only by follower (currentUserId)
  @override
  Future<void> toggleFollow({
    required String currentUserId,
    required String expertId,
  }) async {
    if (currentUserId.trim().isEmpty) {
      throw ArgumentError('currentUserId is empty');
    }
    if (expertId.trim().isEmpty) {
      throw ArgumentError('expertId is empty');
    }
    if (currentUserId == expertId) return;

    final followingRef = _followingCol(currentUserId).doc(expertId);
    final followerRef = _followersCol(expertId).doc(currentUserId);

    final snap = await followingRef.get();
    final batch = _db.batch();

    if (snap.exists) {
      // unfollow
      batch.delete(followingRef);
      batch.delete(followerRef);
    } else {
      // follow
      batch.set(followingRef, <String, dynamic>{
        'targetId': expertId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(followerRef, <String, dynamic>{
        'followerId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
