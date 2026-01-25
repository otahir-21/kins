import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Get FCM token and save to Firestore
  Future<String?> getFCMToken() async {
    try {
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _messaging.getToken();
        debugPrint('✅ FCM Token: $token');
        return token;
      } else {
        debugPrint('❌ Notification permission denied');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Failed to get FCM token: $e');
      return null;
    }
  }

  /// Save FCM token to user document
  Future<void> saveFCMToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ FCM token saved to Firestore');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token: $e');
      rethrow;
    }
  }

  /// Get all notifications for a user
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Get unread notification count
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      debugPrint('✅ Notification marked as read');
    } catch (e) {
      debugPrint('❌ Failed to mark notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Failed to mark all notifications as read: $e');
      rethrow;
    }
  }

  /// Save notification from FCM to Firestore
  Future<void> saveNotification({
    required String userId,
    required NotificationModel notification,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id)
          .set({
        'senderId': notification.senderId,
        'senderName': notification.senderName,
        'senderProfilePicture': notification.senderProfilePicture,
        'type': notification.type,
        'action': notification.action,
        'timestamp': FieldValue.serverTimestamp(),
        'relatedPostId': notification.relatedPostId,
        'postThumbnail': notification.postThumbnail,
        'read': false,
      });
      debugPrint('✅ Notification saved to Firestore');
    } catch (e) {
      debugPrint('❌ Failed to save notification: $e');
      rethrow;
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      debugPrint('✅ Notification deleted');
    } catch (e) {
      debugPrint('❌ Failed to delete notification: $e');
      rethrow;
    }
  }
}
