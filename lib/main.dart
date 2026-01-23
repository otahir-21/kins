import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kins_app/firebase_options.dart';
import 'package:kins_app/core/theme/app_theme.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // OPTIONAL: Use Firebase Auth Emulator for development (bypasses reCAPTCHA)
  // Uncomment the lines below to use emulator:
  // if (kDebugMode) {
  //   try {
  //     await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  //     debugPrint('✅ Using Firebase Auth Emulator - reCAPTCHA will be bypassed');
  //   } catch (e) {
  //     debugPrint('⚠️ Auth Emulator not available: $e');
  //   }
  // }
  // Note: Requires Firebase Emulator Suite to be running
  // Run: firebase emulators:start --only auth
  
  // Initialize Storage Service
  await StorageService.init();
  
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
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
