import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_model.dart';
import '../utils/logger.dart';

/// Expert subscription repository
class FirestoreSubscriptionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _subscriptions() =>
      _db.collection('expert_subscriptions');

  /// Kullanıcının aktif aboneliğini getir
  Future<ExpertSubscription?> getActiveSubscription(String userId) async {
    try {
      final snapshot = await _subscriptions()
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return ExpertSubscription.fromFirestore(doc.data(), doc.id);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get active subscription', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Kullanıcının abonelik durumunu stream olarak dinle
  Stream<ExpertSubscription?> watchSubscription(String userId) {
    return _subscriptions()
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['active', 'expired', 'cancelled'])
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return ExpertSubscription.fromFirestore(doc.data(), doc.id);
    });
  }

  /// Abonelik oluştur (Aylık - Admin onayından sonra)
  Future<String> createSubscription({
    required String userId,
    required SubscriptionPlan plan,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final subscription = ExpertSubscription(
        userId: userId,
        subscriptionId: '', // Firestore otomatik oluşturacak
        plan: plan,
        status: SubscriptionStatus.active, // Admin onayladığında aktif
        startDate: startDate ?? now,
        endDate: endDate ?? now.add(Duration(days: plan.durationDays)), // 30 gün (aylık)
        nextBillingDate: now.add(Duration(days: plan.durationDays)), // Bir ay sonra ödeme
        autoRenew: true, // Aylık otomatik yenileme
      );

      final docRef = await _subscriptions().add(subscription.toFirestore());
      
      AppLogger.success('Subscription created', context: {
        'userId': userId,
        'subscriptionId': docRef.id,
        'plan': plan.value,
      });

      return docRef.id;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create subscription', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Abonelik durumunu güncelle
  Future<void> updateSubscriptionStatus(
    String subscriptionId,
    SubscriptionStatus status,
  ) async {
    try {
      await _subscriptions().doc(subscriptionId).update({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('Subscription status updated', context: {
        'subscriptionId': subscriptionId,
        'status': status.value,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update subscription status', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Aboneliği iptal et
  Future<void> cancelSubscription(String subscriptionId) async {
    try {
      await _subscriptions().doc(subscriptionId).update({
        'status': SubscriptionStatus.cancelled.value,
        'autoRenew': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('Subscription cancelled', context: {
        'subscriptionId': subscriptionId,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to cancel subscription', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Aboneliğin aktif olup olmadığını kontrol et
  Future<bool> hasActiveSubscription(String userId) async {
    final subscription = await getActiveSubscription(userId);
    if (subscription == null) return false;
    
    // Süresi dolmuş mu kontrol et
    if (subscription.hasExpired) {
      // Otomatik olarak expired yap
      await updateSubscriptionStatus(
        subscription.subscriptionId,
        SubscriptionStatus.expired,
      );
      return false;
    }
    
    // ✅ Sadece aktif abonelikler
    return subscription.isActive;
  }
}
