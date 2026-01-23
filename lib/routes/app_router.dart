import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/screens/splash/splash_screen.dart';
import 'package:kins_app/screens/onboarding/onboarding_screen.dart';
import 'package:kins_app/screens/auth/phone_auth_screen.dart';
import 'package:kins_app/screens/auth/otp_verification_screen.dart';
import 'package:kins_app/screens/auth/otp_verified_screen.dart';
import 'package:kins_app/screens/user_details/user_details_screen.dart';
import 'package:kins_app/screens/user_details/user_details_success_screen.dart';

final appRouter = GoRouter(
  initialLocation: AppConstants.routeSplash,
  errorBuilder: (context, state) {
    // Handle unknown routes (Firebase deep links are handled by catch-all route)
    return const SplashScreen();
  },
  routes: [
    GoRoute(
      path: AppConstants.routeSplash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppConstants.routeOnboarding,
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppConstants.routePhoneAuth,
      name: 'phone-auth',
      builder: (context, state) => const PhoneAuthScreen(),
    ),
    GoRoute(
      path: AppConstants.routeOtpVerification,
      name: 'otp-verification',
      builder: (context, state) {
        final phoneNumber = state.uri.queryParameters['phone'] ?? '';
        return OtpVerificationScreen(phoneNumber: phoneNumber);
      },
    ),
    GoRoute(
      path: AppConstants.routeOtpVerified,
      name: 'otp-verified',
      builder: (context, state) => const OtpVerifiedScreen(),
    ),
    GoRoute(
      path: AppConstants.routeUserDetails,
      name: 'user-details',
      builder: (context, state) => const UserDetailsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeUserDetailsSuccess,
      name: 'user-details-success',
      builder: (context, state) => const UserDetailsSuccessScreen(),
    ),
    // Catch-all route for Firebase deep links and unknown paths
    GoRoute(
      path: '/:path(.*)',
      redirect: (context, state) {
        final location = state.uri.toString();
        // If it's a Firebase deep link, redirect to phone auth screen
        // The phone auth screen will check for verification ID and handle navigation
        if (location.contains('firebaseauth') || 
            location.contains('firebaseapp.com') ||
            state.uri.scheme.startsWith('app-')) {
          // Redirect to phone auth - it will check for verification ID
          return AppConstants.routePhoneAuth;
        }
        // For other unknown paths, go to splash
        return AppConstants.routeSplash;
      },
    ),
  ],
);
