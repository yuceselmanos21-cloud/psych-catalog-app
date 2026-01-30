import 'dart:async';

abstract class FollowRepository {
  Stream<bool> watchIsFollowing({
    required String currentUserId,
    required String expertId,
  });

  /// expertId'nin toplam takipçi sayısı
  Stream<int> watchFollowersCount(String expertId);

  /// userId'nin toplam takip ettiği kişi sayısı
  Stream<int> watchFollowingCount(String userId);

  /// userId'nin takip ettiği kişilerin ID'lerini döndürür
  Stream<Set<String>> watchFollowingIds(String userId);

  /// userId'nin takipçilerinin ID'lerini döndürür
  Stream<Set<String>> watchFollowersIds(String userId);

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
