import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/expert_access_provider.dart';
import '../core/providers/user_provider.dart';
import '../utils/error_handler.dart';
import '../utils/rate_limiter.dart';
import '../constants/app_constants.dart';
import '../services/analytics_service.dart';
import 'package:flutter/material.dart';

/// Production helper utilities
class ProductionHelpers {
  ProductionHelpers._(); // Private constructor

  /// Expert özelliğine erişim kontrolü yap ve hata göster
  static Future<bool> checkExpertAccess(
    BuildContext context,
    WidgetRef ref, {
    bool showError = true,
  }) async {
    final canAccess = ref.read(canAccessExpertFeaturesProvider);
    final userState = ref.read(userProvider);

    // Admin her zaman erişebilir
    if (userState.isAdmin) return true;

    // Expert değilse
    if (!userState.isExpert) {
      if (showError && context.mounted) {
        AppErrorHandler.showInfo(
          context,
          'Bu özelliği kullanmak için uzman olarak kayıt olmanız gerekmektedir.',
        );
      }
      return false;
    }

    // Expert ama abonelik yok
    if (!canAccess) {
      if (showError && context.mounted) {
        AppErrorHandler.showInfo(
          context,
          'Bu özelliği kullanmak için aktif bir aboneliğiniz olmalıdır. Lütfen abonelik planınızı yenileyin.',
        );
      }
      return false;
    }

    return true;
  }

  /// Rate limit ile action çalıştır
  static Future<T> executeWithRateLimit<T>(
    String actionId,
    Future<T> Function() action, {
    Duration? cooldown,
    int? maxAttempts,
    Duration? resetWindow,
    String? errorMessage,
  }) async {
    return withRateLimit(
      actionId,
      action,
      cooldown: cooldown,
      maxAttempts: maxAttempts,
      resetWindow: resetWindow,
      errorMessage: errorMessage,
    );
  }

  /// Test oluşturma için rate limit
  static Future<T> executeTestCreation<T>(
    Future<T> Function() action,
  ) async {
    return executeWithRateLimit(
      'create_test',
      action,
      cooldown: AppConstants.postCooldown,
      maxAttempts: 10,
      resetWindow: const Duration(hours: 1),
      errorMessage: 'Çok fazla test oluşturuyorsunuz. Lütfen bekleyin.',
    );
  }

  /// Post oluşturma için rate limit
  static Future<T> executePostCreation<T>(
    Future<T> Function() action,
  ) async {
    return executeWithRateLimit(
      'create_post',
      action,
      cooldown: AppConstants.postCooldown,
      maxAttempts: 20,
      resetWindow: const Duration(hours: 1),
      errorMessage: 'Çok fazla gönderi paylaşıyorsunuz. Lütfen bekleyin.',
    );
  }

  /// Follow için rate limit
  static Future<T> executeFollow<T>(
    Future<T> Function() action,
  ) async {
    return executeWithRateLimit(
      'follow_user',
      action,
      cooldown: AppConstants.followCooldown,
      maxAttempts: 50,
      resetWindow: const Duration(minutes: 5),
      errorMessage: 'Çok fazla takip işlemi yapıyorsunuz. Lütfen bekleyin.',
    );
  }

  /// Report için rate limit
  static Future<T> executeReport<T>(
    Future<T> Function() action,
  ) async {
    return executeWithRateLimit(
      'create_report',
      action,
      cooldown: AppConstants.reportCooldown,
      maxAttempts: 5,
      resetWindow: const Duration(hours: 24),
      errorMessage: 'Çok fazla şikayet oluşturuyorsunuz. Lütfen bekleyin.',
    );
  }

  /// Analytics event log
  static Future<void> logUserAction(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    await AnalyticsService.logEvent(eventName, parameters: parameters);
  }
}
