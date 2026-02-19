import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/core/theme/app_theme.dart';
import 'package:kins_app/core/utils/secure_storage_service.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/firebase_options.dart';
import 'package:kins_app/routes/app_router.dart';
import 'package:kins_app/screens/chat/group_conversation_screen.dart';
import 'package:kins_app/services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Storage Service and secure storage (JWT)
  await StorageService.init();
  await SecureStorageService.init();

  // When using Firebase Auth and we don't have a backend JWT, sync Firebase user to storage
  if (AppConstants.useFirebaseAuth && SecureStorageService.getJwtTokenSync() == null) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await StorageService.setString(AppConstants.keyUserId, user.uid);
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        await StorageService.setString(AppConstants.keyUserPhoneNumber, user.phoneNumber!);
      }
    }
  }

  // On 401, redirect to login
  onUnauthorized = () => appRouter.go(AppConstants.routePhoneAuth);

  // Initialize FCM for Android/iOS; handle chat notification tap -> open conversation
  try {
    final fcmService = FCMService();
    await fcmService.initialize(onNotificationTap: _handleChatNotificationTap);
  } catch (e) {
    // Ignore APNS token errors (iOS requires Apple Developer account)
    if (e.toString().contains('apns-token-not-set')) {
      debugPrint('⚠️ APNS token not set (iOS requires Apple Developer account) - ignoring');
    } else {
      debugPrint('⚠️ FCM initialization error: $e');
    }
    // Continue app initialization even if FCM fails
  }
  
  runApp(
    ProviderScope(
      child: KINSApp(
        onChatNotificationTap: _handleChatNotificationTap,
      ),
    ),
  );
}

void _handleChatNotificationTap(Map<String, String> data) {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  final type = data['type'] ?? '';
  if (type == 'chat_1_1') {
    final cid = data['conversationId'] ?? '';
    if (cid.isNotEmpty) {
      context.push(
        AppConstants.chatConversationPath(cid),
        extra: {
          'otherUserId': data['senderId'] ?? '',
          'otherUserName': data['senderName'] ?? '',
          'otherUserAvatarUrl': data['senderProfilePicture'],
        },
      );
    }
  } else if (type == 'chat_group') {
    final gid = data['groupId'] ?? '';
    if (gid.isNotEmpty) {
      context.push(
        AppConstants.groupConversationPath(gid),
        extra: GroupConversationArgs(
          groupId: gid,
          name: data['groupName'] ?? 'Group',
          description: '',
          imageUrl: data['groupImageUrl'],
        ),
      );
    }
  }
}

class KINSApp extends StatefulWidget {
  const KINSApp({super.key, this.onChatNotificationTap});

  final void Function(Map<String, String> data)? onChatNotificationTap;

  @override
  State<KINSApp> createState() => _KINSAppState();
}

class _KINSAppState extends State<KINSApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.onChatNotificationTap != null) {
        FCMService.flushPendingNotificationTap(widget.onChatNotificationTap!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KINS',
      theme: AppTheme.lightTheme(platformIsIOS: Platform.isIOS),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
