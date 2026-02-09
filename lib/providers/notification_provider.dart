import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/repositories/notification_repository.dart';
import 'package:kins_app/models/notification_model.dart';

// Notification Repository Provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// Notifications State
class NotificationsState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// Notifications Notifier
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationRepository _repository;
  final String _userId;

  NotificationsNotifier(this._repository, this._userId)
      : super(NotificationsState()) {
    _loadNotifications();
    _loadUnreadCount();
  }

  void _loadNotifications() {
    _repository.getNotifications(_userId).listen((notifications) {
      state = state.copyWith(notifications: notifications);
    });
  }

  void _loadUnreadCount() {
    _repository.getUnreadCount(_userId).listen((count) {
      state = state.copyWith(unreadCount: count);
    });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(_userId, notificationId);
    } catch (e) {
      debugPrint('❌ Failed to mark notification as read: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead(_userId);
    } catch (e) {
      debugPrint('❌ Failed to mark all notifications as read: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(_userId, notificationId);
    } catch (e) {
      debugPrint('❌ Failed to delete notification: $e');
      state = state.copyWith(error: e.toString());
    }
  }
}

// Notifications Provider
final notificationsProvider =
    StateNotifierProvider.family<NotificationsNotifier, NotificationsState, String>(
  (ref, userId) {
    final repository = ref.watch(notificationRepositoryProvider);
    return NotificationsNotifier(repository, userId);
  },
);

// FCM Token Provider
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return await repository.getFCMToken();
});
