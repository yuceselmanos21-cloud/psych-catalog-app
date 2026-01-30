import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../config/app_config.dart';

/// Merkezi logging sistemi
class AppLogger {
  AppLogger._(); // Private constructor

  /// Error log - Her zaman aktif, Crashlytics'e gönderilir
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    if (AppConfig.enableErrorLogging) {
      // Console'a yaz
      debugPrint('❌ ERROR: $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   StackTrace: $stackTrace');
      }
      if (context != null) {
        debugPrint('   Context: $context');
      }

      // Crashlytics'e gönder (production'da)
      if (AppConfig.enableCrashlytics) {
        if (error != null && stackTrace != null) {
          // Context bilgilerini custom key olarak ekle
          if (context != null) {
            context.forEach((key, value) {
              FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
            });
          }
          FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            reason: message,
          );
        } else {
          FirebaseCrashlytics.instance.log('ERROR: $message');
          if (context != null) {
            context.forEach((key, value) {
              FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
            });
          }
        }
      }
    }
  }

  /// Warning log
  static void warning(
    String message, {
    Map<String, dynamic>? context,
  }) {
    if (AppConfig.enableDebugLogging) {
      debugPrint('⚠️ WARNING: $message');
      if (context != null) {
        debugPrint('   Context: $context');
      }
    }
  }

  /// Info log
  static void info(
    String message, {
    Map<String, dynamic>? context,
  }) {
    if (AppConfig.enableDebugLogging) {
      debugPrint('ℹ️ INFO: $message');
      if (context != null) {
        debugPrint('   Context: $context');
      }
    }
  }

  /// Debug log - Sadece development'da
  static void debug(
    String message, {
    Map<String, dynamic>? context,
  }) {
    if (AppConfig.enableVerboseLogging) {
      debugPrint('🔵 DEBUG: $message');
      if (context != null) {
        debugPrint('   Context: $context');
      }
    }
  }

  /// Success log
  static void success(
    String message, {
    Map<String, dynamic>? context,
  }) {
    if (AppConfig.enableDebugLogging) {
      debugPrint('✅ SUCCESS: $message');
      if (context != null) {
        debugPrint('   Context: $context');
      }
    }
  }

  /// Performance log
  static void performance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? context,
  }) {
    if (AppConfig.enableDebugLogging) {
      debugPrint('⏱️ PERFORMANCE: $operation took ${duration.inMilliseconds}ms');
      if (context != null) {
        debugPrint('   Context: $context');
      }
    }

    // Performance Monitoring'e gönder (production'da)
    if (AppConfig.enablePerformanceMonitoring) {
      // Firebase Performance trace kullanılabilir
      // Şimdilik sadece log
    }
  }

  /// User action log (Analytics için)
  static void userAction(
    String action, {
    Map<String, dynamic>? parameters,
  }) {
    debug('User Action: $action', context: parameters);
    // Analytics'e gönderilecek (gelecekte)
  }
}
