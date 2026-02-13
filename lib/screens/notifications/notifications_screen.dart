import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/models/notification_model.dart';
import 'package:kins_app/providers/notification_provider.dart';
import 'package:intl/intl.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = currentUserId;
    if (uid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    final notificationsState = ref.watch(notificationsProvider(uid));

    // Group notifications by date
    final groupedNotifications = _groupNotificationsByDate(
      notificationsState.notifications,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: notificationsState.isLoading
          ? const SkeletonNotificationList()
          : groupedNotifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(context, ref, uid, groupedNotifications),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No new notifications',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Map<String, List<NotificationModel>> groupedNotifications,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groupedNotifications.length,
      itemBuilder: (context, index) {
        final dateKey = groupedNotifications.keys.elementAt(index);
        final notifications = groupedNotifications[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            // Notifications for this date
            ...notifications.map((notification) => _buildNotificationItem(
                  context,
                  ref,
                  userId,
                  notification,
                )),
          ],
        );
      },
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    WidgetRef ref,
    String userId,
    NotificationModel notification,
  ) {
    return InkWell(
      onTap: () {
        // Mark as read when tapped
        if (!notification.read) {
          ref.read(notificationsProvider(userId).notifier).markAsRead(notification.id);
        }
        // Handle navigation based on notification type
        _handleNotificationTap(context, notification);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.read ? Colors.white : Colors.blue.shade50.withOpacity(0.3),
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF6B4C93),
                shape: BoxShape.circle,
              ),
              child: notification.senderProfilePicture != null
                  ? ClipOval(
                      child: Image.network(
                        notification.senderProfilePicture!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            // Notification content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: notification.senderName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ': '),
                        TextSpan(text: notification.action),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side element (post thumbnail or message button)
            _buildRightElement(context, notification),
          ],
        ),
      ),
    );
  }

  Widget _buildRightElement(BuildContext context, NotificationModel notification) {
    // Show post thumbnail for post-related notifications
    if (notification.type == 'liked_post' || notification.type == 'commented_post') {
      if (notification.postThumbnail != null) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              notification.postThumbnail!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image,
                  color: Colors.grey.shade400,
                  size: 24,
                );
              },
            ),
          ),
        );
      }
    }

    // Show message button for follow notifications
    if (notification.type == 'followed_you') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E8), // Beige
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Message',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _handleNotificationTap(BuildContext context, NotificationModel notification) {
    // Handle navigation based on notification type
    switch (notification.type) {
      case 'liked_post':
      case 'commented_post':
        // Navigate to post if postId is available
        if (notification.relatedPostId != null) {
          // TODO: Navigate to post detail screen
          debugPrint('Navigate to post: ${notification.relatedPostId}');
        }
        break;
      case 'followed_you':
        // Navigate to chat or message screen
        // TODO: Navigate to chat screen
        debugPrint('Navigate to chat with: ${notification.senderId}');
        break;
      case 'message':
        // Navigate to chat screen
        // TODO: Navigate to chat screen
        debugPrint('Navigate to message');
        break;
      default:
        break;
    }
  }

  Map<String, List<NotificationModel>> _groupNotificationsByDate(
    List<NotificationModel> notifications,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<NotificationModel>> grouped = {};

    for (final notification in notifications) {
      final notificationDate = DateTime(
        notification.timestamp.year,
        notification.timestamp.month,
        notification.timestamp.day,
      );

      String dateKey;
      if (notificationDate == today) {
        dateKey = 'Today';
      } else if (notificationDate == yesterday) {
        dateKey = 'Yesterday';
      } else {
        dateKey = DateFormat('MMMM d, yyyy').format(notification.timestamp);
      }

      grouped.putIfAbsent(dateKey, () => []).add(notification);
    }

    return grouped;
  }
}
