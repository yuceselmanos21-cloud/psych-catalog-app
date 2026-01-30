import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/firestore_block_repository.dart';
import '../../core/di/service_locator.dart';
import '../../utils/logger.dart';
import 'user_provider.dart';

/// Engellenen kullanıcı ID'leri provider
final blockedIdsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(<String>{});
  }

  final blockRepo = getIt<FirestoreBlockRepository>();
  return blockRepo.watchBlockedIds(userId);
});

/// Belirli bir kullanıcı engellenmiş mi?
final isBlockedProvider = StreamProvider.family<bool, String>((ref, blockedUserId) {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) {
    return Stream.value(false);
  }

  final blockRepo = getIt<FirestoreBlockRepository>();
  return blockRepo.watchIsBlocked(
    currentUserId: currentUserId,
    blockedUserId: blockedUserId,
  );
});

/// Block/Unblock action provider
final blockActionProvider = Provider<BlockAction>((ref) {
  return BlockAction(ref);
});

class BlockAction {
  final Ref _ref;
  final FirestoreBlockRepository _blockRepo = getIt<FirestoreBlockRepository>();

  BlockAction(this._ref);

  Future<void> block(String blockedUserId) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      AppLogger.warning('Cannot block: user not logged in');
      return;
    }

    try {
      await _blockRepo.block(
        currentUserId: currentUserId,
        blockedUserId: blockedUserId,
      );
      AppLogger.success('User blocked', context: {'blockedUserId': blockedUserId});
    } catch (e, stackTrace) {
      AppLogger.error('Failed to block user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> unblock(String blockedUserId) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      AppLogger.warning('Cannot unblock: user not logged in');
      return;
    }

    try {
      await _blockRepo.unblock(
        currentUserId: currentUserId,
        blockedUserId: blockedUserId,
      );
      AppLogger.success('User unblocked', context: {'blockedUserId': blockedUserId});
    } catch (e, stackTrace) {
      AppLogger.error('Failed to unblock user', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
