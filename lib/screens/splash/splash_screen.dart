import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/storage_service.dart';

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

    // 2. Check if user has an active session (JWT + userId from backend)
    final userId = StorageService.getString(AppConstants.keyUserId);
    final token = StorageService.getString(AppConstants.keyJwtToken);

    if (userId != null && userId.isNotEmpty && token != null && token.isNotEmpty) {
      context.go(AppConstants.routeHome);
    } else {
      context.go(AppConstants.routePhoneAuth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/logo/Logo-KINS.png',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            'KINS',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
