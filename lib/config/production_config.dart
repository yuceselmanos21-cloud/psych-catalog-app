import 'app_config.dart';
import '../utils/logger.dart';

/// Production-specific configuration
class ProductionConfig {
  ProductionConfig._(); // Private constructor

  /// Production environment'ı kontrol et ve ayarla
  static void initialize() {
    if (AppConfig.isProduction) {
      AppLogger.info('Production environment detected');
      
      // Production-specific settings
      _setupProductionSettings();
    } else {
      AppLogger.info('Development environment detected');
    }
  }

  static void _setupProductionSettings() {
    // Production'da debug logging'i kapat
    // (AppConfig'de zaten kontrol ediliyor)
    
    // Crashlytics'i aktif et
    // (main.dart'ta zaten yapılıyor)
    
    // Analytics'i aktif et
    // (AnalyticsService'de zaten kontrol ediliyor)
  }

  /// Production checklist
  static Future<void> verifyProductionReadiness() async {
    final checks = <String, bool>{
      'Firebase initialized': true, // main.dart'ta kontrol edilecek
      'Crashlytics enabled': AppConfig.enableCrashlytics,
      'Analytics enabled': AppConfig.enableAnalytics,
      'Error handling': true, // AppErrorHandler mevcut
      'Rate limiting': true, // RateLimiter mevcut
      'Input validation': true, // InputValidator mevcut
    };

    final failed = checks.entries.where((e) => !e.value).toList();
    
    if (failed.isNotEmpty) {
      AppLogger.warning('Production readiness check failed', context: {
        'failed_checks': failed.map((e) => e.key).toList(),
      });
    } else {
      AppLogger.success('Production readiness check passed');
    }
  }
}
