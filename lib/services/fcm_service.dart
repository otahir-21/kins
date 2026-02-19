import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/repositories/notification_repository.dart';
import 'package:kins_app/models/notification_model.dart';

/// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message received: ${message.messageId}');
  // Handle background message
}

/// Callback when user taps a notification (or opens app from notification).
/// [data] is message.data; for chat use type, conversationId/groupId, senderName, etc.
typedef OnNotificationTapCallback = void Function(Map<String, String> data);

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationRepository _repository = NotificationRepository();
  OnNotificationTapCallback? _onNotificationTap;

  /// If app was opened from a notification (terminated state), data is stored here until [flushPendingNotificationTap] is called with context.
  static Map<String, String>? pendingNotificationData;

  /// Initialize FCM and request permissions (Android/iOS only).
  /// [onNotificationTap] is called when user taps a notification (or opens from one); use for chat deep link.
  Future<void> initialize({OnNotificationTapCallback? onNotificationTap}) async {
    _onNotificationTap = onNotificationTap;
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

        // Check for initial notification (app opened from terminated state).
        // Store data so app can navigate after first frame (context not available yet).
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('📬 App opened from notification: ${initialMessage.messageId}');
          final data = initialMessage.data;
          if (data.isNotEmpty) {
            FCMService.pendingNotificationData =
                data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
          }
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
    final uid = currentUserId;
    if (uid.isNotEmpty) {
      try {
        await _repository.saveFCMToken(uid, token);
      } catch (e) {
        debugPrint('❌ Failed to save FCM token: $e');
      }
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message received: ${message.messageId}');
    
    final uid = currentUserId;
    if (uid.isNotEmpty && message.data.isNotEmpty) {
      _saveNotificationFromMessage(uid, message);
    }
  }

  /// Handle notification tap (background / foreground). For cold start, data is in [pendingNotificationData].
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.messageId}');
    final data = message.data;
    if (data.isEmpty) return;
    final map = data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    _onNotificationTap?.call(map);
  }

  /// Call from app after first frame when context is available (e.g. to handle cold start from notification).
  static void flushPendingNotificationTap(OnNotificationTapCallback onTap) {
    final pending = pendingNotificationData;
    if (pending != null) {
      pendingNotificationData = null;
      onTap(pending);
    }
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
