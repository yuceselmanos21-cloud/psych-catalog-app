import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/providers/subscription_provider.dart';
import '../core/providers/user_provider.dart';
import '../repositories/firestore_subscription_repository.dart';
import '../utils/error_handler.dart';
import '../constants/app_constants.dart';

/// Account management screen (subscription cancellation, account deletion)
class AccountManagementScreen extends ConsumerStatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  ConsumerState<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends ConsumerState<AccountManagementScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userState = ref.watch(userProvider);
    final subscriptionAsync = ref.watch(activeSubscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesap Yönetimi'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Abonelik İptali (Expert ise)
            if (userState.isExpert && !userState.isAdmin) ...[
              _buildSectionTitle('Abonelik İptali', isDark),
              const SizedBox(height: 12),
              subscriptionAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox(),
                data: (subscription) {
                  if (subscription == null || subscription.isCancelled || subscription.hasExpired) {
                    return _buildNoActiveSubscription(isDark);
                  }
                  return _buildSubscriptionCancellation(context, subscription, isDark);
                },
              ),
              const SizedBox(height: 32),
            ],

            // Hesap Silme
            _buildSectionTitle('Hesap Silme', isDark),
            const SizedBox(height: 12),
            _buildAccountDeletion(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildNoActiveSubscription(bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aktif bir aboneliğiniz bulunmuyor.',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCancellation(
    BuildContext context,
    dynamic subscription,
    bool isDark,
  ) {
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aboneliği İptal Et',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Aboneliğinizi iptal ederseniz:',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            ...[
              'Abonelik bitiş tarihinde sona erecek',
              'Otomatik yenileme durdurulacak',
              'Uzman özelliklerine erişiminiz kesilecek',
              'İstediğiniz zaman aynı hesapla tekrar abone olabilirsiniz',
            ].map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : () => _cancelSubscription(context, subscription),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Aboneliği İptal Et'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDeletion(BuildContext context, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delete_forever, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hesabı Sil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Hesabınızı silerseniz:',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            ...[
              'Hesabınız deaktive edilecek (içerikleriniz korunur)',
              'Testler, postlar ve yorumlarınız silinmez',
              'Aktif aboneliğiniz varsa iptal edilecek',
              'Aynı e-posta ile tekrar kayıt olabilirsiniz',
              'Giriş yapamayacaksınız',
            ].map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : () => _deleteAccount(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Hesabı Deaktive Et'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelSubscription(BuildContext context, dynamic subscription) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aboneliği İptal Et'),
        content: const Text(
          'Aboneliğinizi iptal etmek istediğinizden emin misiniz? Abonelik bitiş tarihinde sona erecek ve istediğiniz zaman aynı hesapla tekrar abone olabilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      final subscriptionRepo = FirestoreSubscriptionRepository();
      await subscriptionRepo.cancelSubscription(subscription.subscriptionId);

      if (!mounted) return;

      AppErrorHandler.showSuccess(
        context,
        'Aboneliğiniz iptal edildi. Bitiş tarihinde sona erecek.',
      );

      // Provider'ı yenile
      ref.invalidate(activeSubscriptionProvider);
    } catch (e, stackTrace) {
      if (!mounted) return;
      AppErrorHandler.handleError(context, e, stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // İki aşamalı onay
    final confirmed1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Deaktive Et'),
        content: const Text(
          'Hesabınızı deaktive etmek istediğinizden emin misiniz? Hesabınız deaktive edilecek ancak oluşturduğunuz içerikler (testler, postlar, yorumlar) korunacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirmed1 != true) return;

    // İkinci onay
    final confirmed2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Son Uyarı'),
        content: const Text(
          'Hesabınız deaktive edilecek. Giriş yapamayacaksınız ancak oluşturduğunuz içerikler (testler, postlar, yorumlar) korunacaktır. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirmed2 != true) return;

    setState(() => _loading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      // Aktif aboneliği iptal et
      final subscriptionRepo = FirestoreSubscriptionRepository();
      final activeSubscription = await subscriptionRepo.getActiveSubscription(user.uid);
      if (activeSubscription != null && !activeSubscription.isCancelled) {
        await subscriptionRepo.cancelSubscription(activeSubscription.subscriptionId);
      }

      // ✅ SOFT DELETE: Kullanıcı hesabını deaktive et (içerikler korunur)
      // ✅ ÖNEMLİ: İsim ve username korunur (içeriklerde görünmesi için)
      await _db.collection('users').doc(user.uid).update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'isActive': false, // Hesap deaktive
        'role': 'client', // Expert rolünü kaldır
        // ✅ İçeriklerde görünmesi için name ve username korunur
        // 'name': userData['name'], // Zaten var, korunur
        // 'username': userData['username'], // Zaten var, korunur
      });

      // ✅ Firebase Auth'tan silme - Sadece oturumu kapat
      // (İçeriklerde author bilgisi korunmalı, Firebase Auth'tan silmek içerikleri bozmaz ama giriş yapamaz)
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      AppErrorHandler.showSuccess(
        context,
        'Hesabınız başarıyla deaktive edildi. Oluşturduğunuz içerikler (testler, postlar, yorumlar) korunmuştur.',
      );

      // Auth ekranına yönlendir
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    } catch (e, stackTrace) {
      if (!mounted) return;
      AppErrorHandler.handleError(
        context,
        e,
        stackTrace: stackTrace,
        customMessage: 'Hesap silinirken bir hata oluştu',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
