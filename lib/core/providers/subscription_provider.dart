import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/firestore_subscription_repository.dart';
import '../../models/subscription_model.dart';
import '../../utils/logger.dart';
import 'user_provider.dart';

/// Subscription repository provider
final subscriptionRepoProvider = Provider<FirestoreSubscriptionRepository>((ref) {
  return FirestoreSubscriptionRepository();
});

/// Kullanıcının aktif aboneliği
final activeSubscriptionProvider = StreamProvider<ExpertSubscription?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(null);
  }

  final repo = ref.watch(subscriptionRepoProvider);
  return repo.watchSubscription(userId);
});

/// Abonelik durumu (aktif mi?)
final hasActiveSubscriptionProvider = Provider<bool>((ref) {
  final subscriptionAsync = ref.watch(activeSubscriptionProvider);
  return subscriptionAsync.when(
    data: (subscription) {
      if (subscription == null) return false;
      // Sadece aktif abonelikler (trial yok, aylık abonelik var)
      return subscription.isActive && !subscription.hasExpired;
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Abonelik action provider
final subscriptionActionProvider = Provider<SubscriptionAction>((ref) {
  return SubscriptionAction(ref);
});

class SubscriptionAction {
  final FirestoreSubscriptionRepository _repo;

  SubscriptionAction(Ref ref)
      : _repo = ref.read(subscriptionRepoProvider);

  /// Aylık abonelik başlat (Admin onayından sonra)
  Future<String> startMonthlySubscription({
    required String userId,
    required SubscriptionPlan plan,
  }) async {
    try {
      final subscriptionId = await _repo.createSubscription(
        userId: userId,
        plan: plan,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)), // Aylık
      );
      
      AppLogger.success('Monthly subscription started', context: {
        'userId': userId,
        'subscriptionId': subscriptionId,
        'plan': plan.value,
      });
      
      return subscriptionId;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to start monthly subscription', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Payment ile abonelik oluştur (gelecekte kullanılacak)
  Future<String> createPaidSubscription({
    required String userId,
    required SubscriptionPlan plan,
    String? paymentMethodId,
  }) async {
    try {
      final subscriptionId = await _repo.createSubscription(
        userId: userId,
        plan: plan,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)), // Aylık
      );
      
      // Payment method ID'yi güncelle (gelecekte)
      if (paymentMethodId != null) {
        // Payment verification yapılacak
      }
      
      AppLogger.success('Paid subscription created', context: {
        'userId': userId,
        'subscriptionId': subscriptionId,
        'plan': plan.value,
      });
      
      return subscriptionId;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create paid subscription', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Aboneliği iptal et
  Future<void> cancelSubscription(String subscriptionId) async {
    try {
      await _repo.cancelSubscription(subscriptionId);
      AppLogger.success('Subscription cancelled', context: {
        'subscriptionId': subscriptionId,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to cancel subscription', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
