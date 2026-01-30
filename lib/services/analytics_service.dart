import 'package:firebase_analytics/firebase_analytics.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';

/// Analytics service
class AnalyticsService {
  AnalyticsService._(); // Private constructor

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Screen view log
  static Future<void> logScreenView(String screenName) async {
    if (!AppConfig.enableAnalytics) return;

    try {
      await _analytics.logScreenView(screenName: screenName);
      AppLogger.debug('Screen view logged', context: {'screen': screenName});
    } catch (e) {
      AppLogger.error('Failed to log screen view', error: e);
    }
  }

  /// Event log
  static Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    if (!AppConfig.enableAnalytics) return;

    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters != null 
            ? Map<String, Object>.from(parameters.map((key, value) => MapEntry(key, value as Object)))
            : null,
      );
      AppLogger.debug('Event logged', context: {
        'event': eventName,
        'parameters': parameters,
      });
    } catch (e) {
      AppLogger.error('Failed to log event', error: e);
    }
  }

  /// User property set
  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!AppConfig.enableAnalytics) return;

    try {
      await _analytics.setUserProperty(name: name, value: value);
      AppLogger.debug('User property set', context: {'name': name, 'value': value});
    } catch (e) {
      AppLogger.error('Failed to set user property', error: e);
    }
  }

  /// User ID set
  static Future<void> setUserId(String? userId) async {
    if (!AppConfig.enableAnalytics) return;

    try {
      await _analytics.setUserId(id: userId);
      AppLogger.debug('User ID set', context: {'userId': userId});
    } catch (e) {
      AppLogger.error('Failed to set user ID', error: e);
    }
  }

  // --- PREDEFINED EVENTS ---

  /// Post oluşturuldu
  static Future<void> logPostCreated({bool hasMedia = false}) async {
    await logEvent('post_created', parameters: {'has_media': hasMedia});
  }

  /// Post beğenildi
  static Future<void> logPostLiked(String postId) async {
    await logEvent('post_liked', parameters: {'post_id': postId});
  }

  /// Yorum yapıldı
  static Future<void> logCommentCreated(String postId) async {
    await logEvent('comment_created', parameters: {'post_id': postId});
  }

  /// Takip edildi
  static Future<void> logUserFollowed(String userId) async {
    await logEvent('user_followed', parameters: {'user_id': userId});
  }

  /// Test çözüldü
  static Future<void> logTestSolved(String testId) async {
    await logEvent('test_solved', parameters: {'test_id': testId});
  }

  /// Test oluşturuldu
  static Future<void> logTestCreated() async {
    await logEvent('test_created');
  }

  /// AI analiz istendi
  static Future<void> logAnalysisRequested({bool hasAttachment = false}) async {
    await logEvent('analysis_requested', parameters: {'has_attachment': hasAttachment});
  }

  /// Mesaj gönderildi
  static Future<void> logMessageSent(String chatId) async {
    await logEvent('message_sent', parameters: {'chat_id': chatId});
  }

  /// Arama yapıldı
  static Future<void> logSearch(String query, String target) async {
    await logEvent('search', parameters: {
      'search_term': query,
      'target': target,
    });
  }

  /// Kullanıcı engellendi
  static Future<void> logUserBlocked(String userId) async {
    await logEvent('user_blocked', parameters: {'user_id': userId});
  }

  /// Şikayet oluşturuldu
  static Future<void> logReportCreated(String targetType, String targetId) async {
    await logEvent('report_created', parameters: {
      'target_type': targetType,
      'target_id': targetId,
    });
  }
}
