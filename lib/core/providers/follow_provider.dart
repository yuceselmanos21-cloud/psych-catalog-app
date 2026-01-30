import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/firestore_follow_repository.dart';
import '../../core/di/service_locator.dart';
import '../../utils/logger.dart';
import 'user_provider.dart';

/// Following listesi provider
final followingIdsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(<String>{});
  }

  final followRepo = getIt<FirestoreFollowRepository>();
  return followRepo.watchFollowingIds(userId);
});

/// Followers listesi provider
final followersIdsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(<String>{});
  }

  final followRepo = getIt<FirestoreFollowRepository>();
  return followRepo.watchFollowersIds(userId);
});

/// Belirli bir kullanıcıyı takip ediyor mu?
final isFollowingProvider = StreamProvider.family<bool, String>((ref, expertId) {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) {
    return Stream.value(false);
  }

  final followRepo = getIt<FirestoreFollowRepository>();
  return followRepo.watchIsFollowing(
    currentUserId: currentUserId,
    expertId: expertId,
  );
});

/// Takipçi sayısı provider
final followersCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final followRepo = getIt<FirestoreFollowRepository>();
  return followRepo.watchFollowersCount(userId);
});

/// Takip edilen sayısı provider
final followingCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final followRepo = getIt<FirestoreFollowRepository>();
  return followRepo.watchFollowingCount(userId);
});

/// Follow/Unfollow action provider
final followActionProvider = Provider<FollowAction>((ref) {
  return FollowAction(ref);
});

class FollowAction {
  final Ref _ref;
  final FirestoreFollowRepository _followRepo = getIt<FirestoreFollowRepository>();

  FollowAction(this._ref);

  Future<void> toggleFollow(String expertId) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      AppLogger.warning('Cannot follow: user not logged in');
      return;
    }

    try {
      await _followRepo.toggleFollow(
        currentUserId: currentUserId,
        expertId: expertId,
      );
      AppLogger.success('Follow toggled', context: {'expertId': expertId});
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle follow', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
