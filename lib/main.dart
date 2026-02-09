import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/theme/app_theme.dart';
import 'package:kins_app/core/utils/secure_storage_service.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/firebase_options.dart';
import 'package:kins_app/routes/app_router.dart';
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

  // When using Firebase Auth, sync current user to storage so app-wide currentUserId works
  if (AppConstants.useFirebaseAuth) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await StorageService.setString(AppConstants.keyUserId, user.uid);
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        await StorageService.setString(AppConstants.keyUserPhoneNumber, user.phoneNumber!);
      }
    }
  }

  // Initialize FCM for Android/iOS
  try {
    final fcmService = FCMService();
    await fcmService.initialize();
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
    const ProviderScope(
      child: KINSApp(),
    ),
  );
}

class KINSApp extends StatelessWidget {
  const KINSApp({super.key});

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
