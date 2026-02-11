import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/models/google_profile_data.dart';
import 'package:kins_app/screens/splash/splash_screen.dart';
import 'package:kins_app/screens/onboarding/onboarding_screen.dart';
import 'package:kins_app/screens/auth/phone_auth_screen.dart';
import 'package:kins_app/screens/auth/otp_verification_screen.dart';
import 'package:kins_app/screens/user_details/user_details_screen.dart';
import 'package:kins_app/screens/user_details/user_details_success_screen.dart';
import 'package:kins_app/screens/home/home_screen.dart';
import 'package:kins_app/screens/dummy/dummy_screen.dart' hide ProfileScreen, SettingsScreen;
import 'package:kins_app/screens/notifications/notifications_screen.dart';
import 'package:kins_app/screens/map/nearby_kins_screen.dart';
import 'package:kins_app/screens/interests/interests_screen.dart';
import 'package:kins_app/screens/discover/discover_screen.dart';
import 'package:kins_app/screens/create_post/create_post_screen.dart';
import 'package:kins_app/screens/chat/chat_screen.dart';
import 'package:kins_app/screens/chat/conversation_screen.dart';
import 'package:kins_app/screens/membership/membership_screen.dart';
import 'package:kins_app/screens/profile/profile_screen.dart';
import 'package:kins_app/screens/profile/settings_menu_screen.dart';
import 'package:kins_app/screens/profile/account_settings_screen.dart';
import 'package:kins_app/screens/profile/edit_tags_screen.dart';
import 'package:kins_app/screens/profile/followers_screen.dart';
import 'package:kins_app/screens/profile/following_screen.dart';

final appRouter = GoRouter(
  initialLocation: AppConstants.routeSplash,
  redirect: (context, state) {
    if (shouldRedirectToLogin) {
      shouldRedirectToLogin = false;
      return AppConstants.routePhoneAuth;
    }
    return null;
  },
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
      path: AppConstants.routeUserDetails,
      name: 'user-details',
      builder: (context, state) {
        final googleProfile = state.extra is GoogleProfileData
            ? state.extra as GoogleProfileData
            : null;
        return UserDetailsScreen(googleProfile: googleProfile);
      },
    ),
    GoRoute(
      path: AppConstants.routeUserDetailsSuccess,
      name: 'user-details-success',
      builder: (context, state) => const UserDetailsSuccessScreen(),
    ),
    GoRoute(
      path: AppConstants.routeHome,
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppConstants.routeMarketplace,
      name: 'marketplace',
      builder: (context, state) => const MarketplaceScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAskExpert,
      name: 'ask-expert',
      builder: (context, state) => const AskExpertScreen(),
    ),
    GoRoute(
      path: AppConstants.routeJoinGroup,
      name: 'join-group',
      builder: (context, state) => const JoinGroupScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAddAction,
      name: 'add-action',
      builder: (context, state) => const AddActionScreen(),
    ),
    GoRoute(
      path: AppConstants.routeCompass,
      name: 'compass',
      builder: (context, state) => const CompassScreen(),
    ),
    GoRoute(
      path: AppConstants.routeChat,
      name: 'chat',
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: '/chat/:chatId',
      name: 'chat-conversation',
      builder: (context, state) {
        final chatId = state.pathParameters['chatId'] ?? '';
        final extra = state.extra as Map<String, dynamic>?;
        return ConversationScreen(
          chatId: chatId,
          otherUserName: extra?['otherUserName'] as String?,
          otherUserAvatarUrl: extra?['otherUserAvatarUrl'] as String?,
        );
      },
    ),
    GoRoute(
      path: AppConstants.routeProfile,
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppConstants.routeSettings,
      name: 'settings',
      builder: (context, state) => const SettingsMenuScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAccountSettings,
      name: 'account-settings',
      builder: (context, state) => const AccountSettingsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeEditTags,
      name: 'edit-tags',
      builder: (context, state) => const EditTagsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeFollowers,
      name: 'followers',
      builder: (context, state) => const FollowersScreen(),
    ),
    GoRoute(
      path: AppConstants.routeFollowing,
      name: 'following',
      builder: (context, state) => const FollowingScreen(),
    ),
    GoRoute(
      path: AppConstants.routeNotifications,
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeNearbyKins,
      name: 'nearby-kins',
      builder: (context, state) => const NearbyKinsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeInterests,
      name: 'interests',
      builder: (context, state) => const InterestsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAwards,
      name: 'awards',
      builder: (context, state) => const AwardsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeMembership,
      name: 'membership',
      builder: (context, state) => const MembershipScreen(),
    ),
    GoRoute(
      path: AppConstants.routeDiscover,
      name: 'discover',
      builder: (context, state) => const DiscoverScreen(),
    ),
    GoRoute(
      path: AppConstants.routeCreatePost,
      name: 'create-post',
      builder: (context, state) => const CreatePostScreen(),
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
