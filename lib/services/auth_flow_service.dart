import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/models/google_profile_data.dart';
import 'package:kins_app/models/user_profile_status.dart';

/// Centralized post-auth navigation: same behavior for Phone OTP and Google Sign-In.
/// Feed = Discover screen (bottom nav Feed tab index 0).
class AuthFlowService {
  AuthFlowService._();

  /// Navigate after successful auth (phone OTP or Google) based on profile status.
  /// [googleProfile] when coming from Google Sign-In; passed to About You for pre-fill and lock.
  static void navigateAfterAuth(
    BuildContext context, {
    required UserProfileStatus profileStatus,
    GoogleProfileData? googleProfile,
  }) {
    if (!profileStatus.exists || profileStatus.needsProfile) {
      context.go(AppConstants.routeUserDetails, extra: googleProfile);
      return;
    }
    if (profileStatus.needsInterests) {
      context.go(AppConstants.routeInterests);
      return;
    }
    if (profileStatus.isComplete) {
      context.go(AppConstants.routeDiscover);
      return;
    }
    context.go(AppConstants.routeUserDetails, extra: googleProfile);
  }
}
