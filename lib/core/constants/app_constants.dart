class AppConstants {
  // Shared Preferences Keys
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyUserPhoneNumber = 'user_phone_number';
  static const String keyUserId = 'user_id';
  
  // Routes
  static const String routeSplash = '/';
  static const String routeOnboarding = '/onboarding';
  static const String routePhoneAuth = '/phone-auth';
  static const String routeOtpVerification = '/otp-verification';
  static const String routeOtpVerified = '/otp-verified';
  static const String routeUserDetails = '/user-details';
  static const String routeUserDetailsSuccess = '/user-details-success';
  static const String routeHome = '/home';
  static const String routeMarketplace = '/marketplace';
  static const String routeAskExpert = '/ask-expert';
  static const String routeJoinGroup = '/join-group';
  static const String routeAddAction = '/add-action';
  static const String routeCompass = '/compass';
  static const String routeChat = '/chat';
  /// Path for 1:1 conversation; use [chatConversationPath(chatId)] to build.
  static String chatConversationPath(String chatId) => '/chat/$chatId';
  static const String routeProfile = '/profile';
  static const String routeSettings = '/settings';
  static const String routeAccountSettings = '/account-settings';
  static const String routeEditTags = '/edit-tags';
  static const String routeFollowers = '/followers';
  static const String routeFollowing = '/following';
  static const String routeNotifications = '/notifications';
  static const String routeNearbyKins = '/nearby-kins';
  static const String routeInterests = '/interests';
  static const String routeAwards = '/awards';
  static const String routeMembership = '/membership';
  static const String routeDiscover = '/discover';
  static const String routeCreatePost = '/create-post';
}
