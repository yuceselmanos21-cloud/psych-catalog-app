import 'package:cloud_firestore/cloud_firestore.dart';

/// Expert subscription model
class ExpertSubscription {
  final String userId;
  final String subscriptionId;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? nextBillingDate;
  final bool autoRenew;
  final String? paymentMethodId;
  final Map<String, dynamic>? metadata;

  ExpertSubscription({
    required this.userId,
    required this.subscriptionId,
    required this.plan,
    required this.status,
    this.startDate,
    this.endDate,
    this.nextBillingDate,
    this.autoRenew = true,
    this.paymentMethodId,
    this.metadata,
  });

  bool get isActive => status == SubscriptionStatus.active;
  bool get isExpired => status == SubscriptionStatus.expired;
  bool get isCancelled => status == SubscriptionStatus.cancelled;
  bool get isTrial => status == SubscriptionStatus.trial;

  /// Abonelik süresi dolmuş mu?
  bool get hasExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// Kalan gün sayısı
  int? get daysRemaining {
    if (endDate == null) return null;
    final now = DateTime.now();
    if (now.isAfter(endDate!)) return 0;
    return endDate!.difference(now).inDays;
  }

  factory ExpertSubscription.fromFirestore(Map<String, dynamic> data, String id) {
    return ExpertSubscription(
      userId: data['userId'] as String,
      subscriptionId: id,
      plan: SubscriptionPlan.fromString(data['plan'] as String? ?? 'expert'),
      status: SubscriptionStatus.fromString(data['status'] as String? ?? 'inactive'),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      nextBillingDate: (data['nextBillingDate'] as Timestamp?)?.toDate(),
      autoRenew: data['autoRenew'] as bool? ?? true,
      paymentMethodId: data['paymentMethodId'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'plan': plan.value,
      'status': status.value,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'nextBillingDate': nextBillingDate != null ? Timestamp.fromDate(nextBillingDate!) : null,
      'autoRenew': autoRenew,
      'paymentMethodId': paymentMethodId,
      'metadata': metadata,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Abonelik planları (Aylık - Tek Plan)
enum SubscriptionPlan {
  expert('expert', 'Uzman Planı', 499.00, 30); // Aylık - Tek Plan

  final String value;
  final String displayName;
  final double monthlyPrice; // Aylık ücret
  final int durationDays; // 30 gün (aylık)

  const SubscriptionPlan(this.value, this.displayName, this.monthlyPrice, this.durationDays);

  /// Aylık ücret getter (geriye dönük uyumluluk için)
  double get price => monthlyPrice;

  static SubscriptionPlan fromString(String value) {
    return SubscriptionPlan.values.firstWhere(
      (plan) => plan.value == value,
      orElse: () => SubscriptionPlan.expert,
    );
  }
}

/// Abonelik durumu
enum SubscriptionStatus {
  inactive('inactive', 'Aktif Değil'),
  active('active', 'Aktif'),
  trial('trial', 'Deneme'),
  expired('expired', 'Süresi Dolmuş'),
  cancelled('cancelled', 'İptal Edilmiş'),
  pending('pending', 'Beklemede'),
  suspended('suspended', 'Askıya Alınmış');

  final String value;
  final String displayName;

  const SubscriptionStatus(this.value, this.displayName);

  static SubscriptionStatus fromString(String value) {
    return SubscriptionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SubscriptionStatus.inactive,
    );
  }
}
