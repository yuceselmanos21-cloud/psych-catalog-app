import 'package:cloud_firestore/cloud_firestore.dart';
import 'block_repository.dart';

/// Block model:
/// - /users/{uid}/blocked/{blockedUserId}
///
/// This is a one-way blocking system:
/// - If user A blocks user B, A won't see B's content
/// - B also won't see A's content (bidirectional effect)
/// - When blocking, any existing follow relationship is removed
class FirestoreBlockRepository implements BlockRepository {
  final FirebaseFirestore _db;

  FirestoreBlockRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _users() =>
      _db.collection('users').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );

  CollectionReference<Map<String, dynamic>> _blockedCol(String uid) =>
      _users().doc(uid).collection('blocked').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );

  /// True if current user has blocked [blockedUserId].
  @override
  Stream<bool> watchIsBlocked({
    required String currentUserId,
    required String blockedUserId,
  }) {
    final ref = _blockedCol(currentUserId).doc(blockedUserId);
    return ref.snapshots().map((snap) => snap.exists);
  }

  /// Get all blocked user IDs for a user.
  @override
  Stream<Set<String>> watchBlockedIds(String userId) {
    return _blockedCol(userId).snapshots().map((snap) => 
      snap.docs.map((doc) => doc.id).toSet()
    );
  }

  /// Check if current user is blocked by [otherUserId] (reverse check).
  /// This checks if otherUserId has blocked currentUserId.
  @override
  Future<bool> isBlockedBy({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (currentUserId.trim().isEmpty || otherUserId.trim().isEmpty) {
      return false;
    }
    if (currentUserId == otherUserId) return false;

    final ref = _blockedCol(otherUserId).doc(currentUserId);
    final snap = await ref.get();
    return snap.exists;
  }

  /// Block a user atomically.
  /// When user A blocks user B:
  /// - Creates /users/{A}/blocked/{B}
  /// - Also removes any follow relationship between them (both directions)
  @override
  Future<void> block({
    required String currentUserId,
    required String blockedUserId,
  }) async {
    if (currentUserId.trim().isEmpty) {
      throw ArgumentError('currentUserId is empty');
    }
    if (blockedUserId.trim().isEmpty) {
      throw ArgumentError('blockedUserId is empty');
    }
    if (currentUserId == blockedUserId) return;

    final blockedRef = _blockedCol(currentUserId).doc(blockedUserId);
    
    // Check if already blocked
    final snap = await blockedRef.get();
    if (snap.exists) return; // Already blocked

    final batch = _db.batch();
    
    // Add to blocked list
    batch.set(blockedRef, <String, dynamic>{
      'blockedUserId': blockedUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Remove follow relationships (both directions) if they exist
    final followingRef = _users().doc(currentUserId).collection('following').doc(blockedUserId);
    final followerRef = _users().doc(blockedUserId).collection('followers').doc(currentUserId);
    final reverseFollowingRef = _users().doc(blockedUserId).collection('following').doc(currentUserId);
    final reverseFollowerRef = _users().doc(currentUserId).collection('followers').doc(blockedUserId);

    // Check and remove if exists
    final followingSnap = await followingRef.get();
    final followerSnap = await followerRef.get();
    final reverseFollowingSnap = await reverseFollowingRef.get();
    final reverseFollowerSnap = await reverseFollowerRef.get();

    if (followingSnap.exists) batch.delete(followingRef);
    if (followerSnap.exists) batch.delete(followerRef);
    if (reverseFollowingSnap.exists) batch.delete(reverseFollowingRef);
    if (reverseFollowerSnap.exists) batch.delete(reverseFollowerRef);

    await batch.commit();
  }

  /// Unblock a user atomically.
  @override
  Future<void> unblock({
    required String currentUserId,
    required String blockedUserId,
  }) async {
    if (currentUserId.trim().isEmpty) {
      throw ArgumentError('currentUserId is empty');
    }
    if (blockedUserId.trim().isEmpty) {
      throw ArgumentError('blockedUserId is empty');
    }
    if (currentUserId == blockedUserId) return;

    final blockedRef = _blockedCol(currentUserId).doc(blockedUserId);
    
    final snap = await blockedRef.get();
    if (!snap.exists) return; // Not blocked

    await blockedRef.delete();
  }

  /// Toggle block status.
  @override
  Future<void> toggleBlock({
    required String currentUserId,
    required String blockedUserId,
  }) async {
    if (currentUserId.trim().isEmpty) {
      throw ArgumentError('currentUserId is empty');
    }
    if (blockedUserId.trim().isEmpty) {
      throw ArgumentError('blockedUserId is empty');
    }
    if (currentUserId == blockedUserId) return;

    final blockedRef = _blockedCol(currentUserId).doc(blockedUserId);
    final snap = await blockedRef.get();

    if (snap.exists) {
      // Unblock
      await unblock(
        currentUserId: currentUserId,
        blockedUserId: blockedUserId,
      );
    } else {
      // Block
      await block(
        currentUserId: currentUserId,
        blockedUserId: blockedUserId,
      );
    }
  }
}
