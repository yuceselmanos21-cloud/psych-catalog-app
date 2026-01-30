import 'dart:async';

abstract class BlockRepository {
  /// True if current user has blocked [blockedUserId].
  Stream<bool> watchIsBlocked({
    required String currentUserId,
    required String blockedUserId,
  });

  /// Get all blocked user IDs for a user.
  Stream<Set<String>> watchBlockedIds(String userId);

  /// Check if current user is blocked by [otherUserId] (reverse check).
  /// This is useful to prevent blocked users from seeing your content.
  Future<bool> isBlockedBy({
    required String currentUserId,
    required String otherUserId,
  });

  /// Block a user atomically.
  /// When user A blocks user B:
  /// - Creates /users/{A}/blocked/{B}
  /// - Also removes any follow relationship between them
  Future<void> block({
    required String currentUserId,
    required String blockedUserId,
  });

  /// Unblock a user atomically.
  Future<void> unblock({
    required String currentUserId,
    required String blockedUserId,
  });

  /// Toggle block status.
  Future<void> toggleBlock({
    required String currentUserId,
    required String blockedUserId,
  });
}
