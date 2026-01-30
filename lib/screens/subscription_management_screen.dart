import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/providers/subscription_provider.dart';
import '../core/providers/user_provider.dart';
import '../models/subscription_model.dart';
import '../utils/error_handler.dart';
import '../constants/app_constants.dart';
import '../widgets/empty_state_widget.dart';
import '../repositories/firestore_subscription_repository.dart';

/// Subscription management screen
class SubscriptionManagementScreen extends ConsumerWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subscriptionAsync = ref.watch(activeSubscriptionProvider);
    final userState = ref.watch(userProvider);

    // Sadece expert/admin görebilir
    if (!userState.isExpert && !userState.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Abonelik Yönetimi')),
        body: EmptyStateWidget(
          icon: Icons.person_off,
          title: 'Uzman Değilsiniz',
          subtitle: 'Bu sayfaya sadece uzmanlar erişebilir.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonelik Yönetimi'),
        elevation: 0,
      ),
      body: subscriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          // ✅ Build sırasında showSnackBar çağrılamaz, post-frame callback kullan
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              AppErrorHandler.handleError(context, error, stackTrace: stack);
            }
          });
          return EmptyStates.error(
            message: 'Abonelik bilgisi yüklenemedi',
            onRetry: () => ref.refresh(activeSubscriptionProvider),
          );
        },
        data: (subscription) {
          if (subscription == null) {
            return _buildNoSubscription(context, ref, isDark);
          }

          return _buildSubscriptionInfo(context, ref, subscription, isDark);
        },
      ),
    );
  }

  Widget _buildNoSubscription(BuildContext context, WidgetRef ref, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: isDark ? Colors.deepPurple.shade900.withOpacity(0.3) : Colors.deepPurple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.deepPurple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aktif bir aboneliğiniz bulunmuyor. Uzman özelliklerini kullanmak için abonelik planı seçin.',
                      style: TextStyle(
                        color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Abonelik Planları',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...SubscriptionPlan.values
              .map((plan) => _buildPlanCard(context, ref, plan, isDark)),
        ],
      ),
    );
  }

  Widget _buildSubscriptionInfo(
    BuildContext context,
    WidgetRef ref,
    ExpertSubscription subscription,
    bool isDark,
  ) {
    final daysRemaining = subscription.daysRemaining;
    final isExpired = subscription.hasExpired;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mevcut Abonelik Kartı
          Card(
            elevation: 2,
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        subscription.isActive ? Icons.check_circle : Icons.cancel,
                        color: subscription.isActive ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscription.plan.displayName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subscription.status.displayName,
                              style: TextStyle(
                                fontSize: 14,
                                color: subscription.isActive
                                    ? Colors.green
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (subscription.startDate != null) ...[
                    _buildInfoRow(
                      'Başlangıç Tarihi',
                      _formatDate(subscription.startDate!),
                      isDark,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (subscription.endDate != null) ...[
                    _buildInfoRow(
                      'Bitiş Tarihi',
                      _formatDate(subscription.endDate!),
                      isDark,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (daysRemaining != null) ...[
                    _buildInfoRow(
                      'Kalan Süre',
                      daysRemaining! > 0
                          ? '$daysRemaining gün'
                          : 'Süresi dolmuş',
                      isDark,
                      valueColor: daysRemaining! > 7
                          ? Colors.green
                          : (daysRemaining! > 0 ? Colors.orange : Colors.red),
                    ),
                  ],
                  if (subscription.nextBillingDate != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Sonraki Ödeme',
                      _formatDate(subscription.nextBillingDate!),
                      isDark,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // İşlemler
          if (subscription.isActive && !isExpired) ...[
            Text(
              'İşlemler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (subscription.autoRenew)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Otomatik Yenilemeyi İptal Et'),
                  subtitle: const Text('Aboneliğiniz bitiş tarihinde otomatik olarak yenilenmeyecek'),
                  onTap: () => _cancelAutoRenew(context, ref, subscription.subscriptionId),
                ),
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings, color: Colors.orange),
                title: const Text('Hesap Yönetimi'),
                subtitle: const Text('Abonelik iptali ve hesap silme işlemleri'),
                onTap: () {
                  Navigator.pushNamed(context, '/accountManagement');
                },
              ),
            ),
          ],

          // Yeni Plan Seç
          const SizedBox(height: 24),
          Text(
            'Plan Değiştir',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...SubscriptionPlan.values
              .where((plan) => plan != subscription.plan)
              .map((plan) => _buildPlanCard(context, ref, plan, isDark)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    WidgetRef ref,
    SubscriptionPlan plan,
    bool isDark,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '${plan.monthlyPrice.toStringAsFixed(2)}₺/ay',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Aylık abonelik (30 gün)',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // ✅ RE-SUBSCRIPTION: Aynı hesapla tekrar abone ol
                  _resubscribe(context, ref, plan);
                },
                child: const Text('Tekrar Abone Ol'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelAutoRenew(
    BuildContext context,
    WidgetRef ref,
    String subscriptionId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Otomatik Yenilemeyi İptal Et'),
        content: const Text(
          'Aboneliğiniz bitiş tarihinde otomatik olarak yenilenmeyecek. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final action = ref.read(subscriptionActionProvider);
        await action.cancelSubscription(subscriptionId);
        
        if (context.mounted) {
          AppErrorHandler.showSuccess(
            context,
            'Otomatik yenileme iptal edildi',
          );
        }
      } catch (e, stackTrace) {
        if (context.mounted) {
          AppErrorHandler.handleError(context, e, stackTrace: stackTrace);
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  Future<void> _resubscribe(BuildContext context, WidgetRef ref, SubscriptionPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tekrar Abone Ol'),
        content: Text(
          '${plan.displayName} planına (${plan.monthlyPrice.toStringAsFixed(2)}₺/ay) tekrar abone olmak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abone Ol'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      // Yeni abonelik oluştur
      final subscriptionRepo = FirestoreSubscriptionRepository();
      await subscriptionRepo.createSubscription(
        userId: user.uid,
        plan: plan,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)), // Aylık
      );

      if (!context.mounted) return;

      AppErrorHandler.showSuccess(
        context,
        'Aboneliğiniz başarıyla başlatıldı!',
      );

      // Provider'ı yenile
      ref.invalidate(activeSubscriptionProvider);
    } catch (e, stackTrace) {
      if (!context.mounted) return;
      AppErrorHandler.handleError(context, e, stackTrace: stackTrace);
    }
  }
}
