import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/secure_storage_service.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/services/auth_flow_service.dart';
import 'package:kins_app/services/backend_auth_service.dart';
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

    // 2. If JWT exists, call GET /me and navigate by backend onboarding state (not local state)
    final token = SecureStorageService.getJwtTokenSync();
    if (token == null || token.isEmpty) {
      context.go(AppConstants.routePhoneAuth);
      return;
    }

    try {
      final profileStatus = await BackendAuthService.getProfileStatus();
      if (!mounted) return;
      if (profileStatus.exists && profileStatus.isComplete) {
        context.go(AppConstants.routeDiscover);
        return;
      }
      if (profileStatus.exists && profileStatus.needsInterests) {
        context.go(AppConstants.routeInterests);
        return;
      }
      AuthFlowService.navigateAfterAuth(context, profileStatus: profileStatus);
    } catch (_) {
      if (!mounted) return;
      context.go(AppConstants.routePhoneAuth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: KinsLogo(width: 200, height: 200),
      ),
    );
  }
}
