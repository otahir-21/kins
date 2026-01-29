import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kins_app/repositories/notification_repository.dart';
import 'package:kins_app/models/notification_model.dart';

/// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message received: ${message.messageId}');
  // Handle background message
}

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationRepository _repository = NotificationRepository();

  /// Initialize FCM and request permissions (Android/iOS only)
  Future<void> initialize() async {
    try {
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted');

        // Get FCM token (ignore APNS errors on iOS)
        try {
          final token = await _messaging.getToken();
          if (token != null) {
            debugPrint('✅ FCM Token: $token');
            _saveTokenToFirestore(token);
          }
        } catch (e) {
          // Ignore APNS token errors (iOS requires Apple Developer account)
          if (e.toString().contains('apns-token-not-set')) {
            debugPrint('⚠️ APNS token not set (iOS requires Apple Developer account) - continuing without FCM token');
          } else {
            debugPrint('⚠️ Failed to get FCM token: $e');
          }
        }

        // Listen for token refresh (ignore APNS errors)
        _messaging.onTokenRefresh.listen((newToken) {
          debugPrint('🔄 FCM Token refreshed: $newToken');
          _saveTokenToFirestore(newToken);
        }, onError: (e) {
          // Ignore APNS token errors
          if (e.toString().contains('apns-token-not-set')) {
            debugPrint('⚠️ APNS token not set - ignoring token refresh error');
          } else {
            debugPrint('⚠️ Token refresh error: $e');
          }
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        // Handle notification taps
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check for initial notification (app opened from terminated state)
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('📬 App opened from notification: ${initialMessage.messageId}');
          // Handle initial notification if needed
        }
      } else {
        debugPrint('❌ Notification permission denied');
      }
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
      // Don't throw - allow app to continue without FCM
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _repository.saveFCMToken(user.uid, token);
      } catch (e) {
        debugPrint('❌ Failed to save FCM token: $e');
      }
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message received: ${message.messageId}');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && message.data.isNotEmpty) {
      _saveNotificationFromMessage(user.uid, message);
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.messageId}');
    // Navigate to appropriate screen based on notification data
    // This will be handled by the app's navigation system
  }

  /// Save notification from FCM message to Firestore
  Future<void> _saveNotificationFromMessage(
    String userId,
    RemoteMessage message,
  ) async {
    try {
      final data = message.data;
      final notification = NotificationModel(
        id: data['notificationId'] ?? message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: data['senderId'] ?? '',
        senderName: data['senderName'] ?? 'Unknown',
        senderProfilePicture: data['senderProfilePicture'],
        type: data['type'] ?? 'unknown',
        action: data['action'] ?? message.notification?.body ?? '',
        timestamp: message.sentTime ?? DateTime.now(),
        relatedPostId: data['relatedPostId'],
        postThumbnail: data['postThumbnail'],
        read: false,
      );

      await _repository.saveNotification(
        userId: userId,
        notification: notification,
      );
    } catch (e) {
      debugPrint('❌ Failed to save notification from message: $e');
    }
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}
