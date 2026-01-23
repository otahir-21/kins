import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/onboarding_provider.dart';
import 'package:kins_app/repositories/auth_repository.dart';

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

    final onboardingCompleted = ref.read(onboardingProvider);
    final authRepository = AuthRepository();
    final isAuthenticated = authRepository.isAuthenticated();

    if (!onboardingCompleted) {
      context.go(AppConstants.routeOnboarding);
    } else if (!isAuthenticated) {
      context.go(AppConstants.routePhoneAuth);
    } else {
      context.go(AppConstants.routeOtpVerified);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Name
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'KINS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}
