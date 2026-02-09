import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/widgets/kins_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for 2 seconds for splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 1. Show walkthrough/onboarding first if user hasn't seen it
    final onboardingCompleted =
        StorageService.getBool(AppConstants.keyOnboardingCompleted) ?? false;
    if (!onboardingCompleted) {
      context.go(AppConstants.routeOnboarding);
      return;
    }

    // 2. Check if user has an active session
    final hasSession = AppConstants.useFirebaseAuth
        ? FirebaseAuth.instance.currentUser != null
        : () {
            final userId = StorageService.getString(AppConstants.keyUserId);
            final token = StorageService.getString(AppConstants.keyJwtToken);
            return (userId != null && userId.isNotEmpty) &&
                (token != null && token.isNotEmpty);
          }();

    if (hasSession) {
      context.go(AppConstants.routeDiscover);
    } else {
      context.go(AppConstants.routePhoneAuth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: KinsLogo(width: 200, height: 200),
    );
  }
}
