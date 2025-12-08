import 'dart:async';

abstract class FollowRepository {
  Stream<bool> watchIsFollowing({
    required String currentUserId,
    required String expertId,
  });

  Stream<int> watchFollowersCount(String expertId);
  Stream<int> watchFollowingCount(String userId);

  Future<void> follow({
    required String currentUserId,
    required String expertId,
  });

  Future<void> unfollow({
    required String currentUserId,
    required String expertId,
  });

  Future<void> toggleFollow({
    required String currentUserId,
    required String expertId,
  });
}
