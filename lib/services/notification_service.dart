import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';
import '../config/app_config.dart';

/// Push notification service
class NotificationService {
  NotificationService._(); // Private constructor

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Initialize notification service
  static Future<void> initialize() async {
    if (!AppConfig.enableAnalytics) return;

    try {
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.info('User granted notification permission');
        
        // Get FCM token
        String? token = await _messaging.getToken();
        if (token != null) {
          await _saveTokenToFirestore(token);
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          _saveTokenToFirestore(newToken);
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages (when app is in background)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      } else {
        AppLogger.warning('User declined notification permission');
      }
    } catch (e) {
      AppLogger.error('Failed to initialize notifications', error: e);
    }
  }

  /// Save FCM token to Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.debug('FCM token saved', context: {'userId': user.uid});
    } catch (e) {
      AppLogger.error('Failed to save FCM token', error: e);
    }
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('Foreground message received', context: {
      'title': message.notification?.title,
      'body': message.notification?.body,
    });

    // Show local notification (you can use flutter_local_notifications for this)
    // For now, we'll just log it
  }

  /// Handle background messages (when app is opened from notification)
  static void _handleBackgroundMessage(RemoteMessage message) {
    AppLogger.info('Background message opened', context: {
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
    });

    // Navigate to appropriate screen based on message data
    // This will be handled in main.dart with a global navigator key
  }

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      AppLogger.info('Subscribed to topic', context: {'topic': topic});
    } catch (e) {
      AppLogger.error('Failed to subscribe to topic', error: e);
    }
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      AppLogger.info('Unsubscribed from topic', context: {'topic': topic});
    } catch (e) {
      AppLogger.error('Failed to unsubscribe from topic', error: e);
    }
  }

  /// Delete FCM token (on logout)
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _db.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }
      AppLogger.info('FCM token deleted');
    } catch (e) {
      AppLogger.error('Failed to delete FCM token', error: e);
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.info('Background message received', context: {
    'title': message.notification?.title,
    'body': message.notification?.body,
  });
}
