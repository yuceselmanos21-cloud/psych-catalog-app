import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/expert_access_provider.dart';
import '../core/providers/user_provider.dart';
import '../widgets/empty_state_widget.dart';

/// Expert özelliklerine erişim kontrolü için middleware
class ExpertAccessMiddleware {
  ExpertAccessMiddleware._(); // Private constructor

  /// Expert özelliğine erişim kontrolü yapan widget wrapper
  static Widget requireAccess({
    required WidgetRef ref,
    required Widget child,
    Widget? noAccessWidget,
    String? customMessage,
  }) {
    final canAccess = ref.watch(canAccessExpertFeaturesProvider);
    final userState = ref.watch(userProvider);

    // Admin her zaman erişebilir
    if (userState.isAdmin) {
      return child;
    }

    // Expert değilse
    if (!userState.isExpert) {
      return noAccessWidget ??
          const EmptyStateWidget(
            icon: Icons.person_off,
            title: 'Uzman Değilsiniz',
            subtitle: 'Bu özelliği kullanmak için uzman olarak kayıt olmanız gerekmektedir.',
          );
    }

    // Expert ama abonelik yok
    if (!canAccess) {
      return noAccessWidget ??
          _buildSubscriptionRequiredWidget(ref, customMessage);
    }

    return child;
  }

  /// Abonelik gerekli widget'ı
  static Widget _buildSubscriptionRequiredWidget(WidgetRef ref, String? customMessage) {
    return EmptyStateWidget(
      icon: Icons.payment,
      title: 'Aktif Abonelik Gerekli',
      subtitle: customMessage ??
          'Bu özelliği kullanmak için aktif bir aboneliğiniz olmalıdır. Lütfen abonelik planınızı yenileyin.',
      actionLabel: 'Abonelik Yönet',
      onAction: () {
        // Abonelik yönetim ekranına yönlendir
        // Navigator.pushNamed(context, '/subscription');
      },
    );
  }

  /// Action çalıştırmadan önce erişim kontrolü
  static Future<T> guardAction<T>(
    WidgetRef ref,
    Future<T> Function() action, {
    String? errorMessage,
  }) async {
    final accessAction = ref.read(expertAccessActionProvider);
    
    try {
      accessAction.requireAccess();
      return await action();
    } on ExpertAccessException catch (e) {
      throw Exception(errorMessage ?? e.message);
    }
  }
}
