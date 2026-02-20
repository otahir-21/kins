class AppConstants {
  // Shared Preferences Keys
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyUserPhoneNumber = 'user_phone_number';
  static const String keyUserId = 'user_id';
  static const String keyJwtToken = 'jwt_token';
  /// Set to true after signing in to Firebase with custom token for chat. Clear on token error to re-fetch.
  static const String keyFirebaseChatSignedIn = 'firebase_chat_signed_in';

  // Backend API (override with --dart-define or env)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://kins-crm.vercel.app',
  );
  /// Base URL for v1 REST API (auth, me, interests). All data from MongoDB.
  static const String apiV1BaseUrl = String.fromEnvironment(
    'API_V1_BASE_URL',
    defaultValue: 'https://kins-crm.vercel.app/api/v1',
  );
  static const String sendOtpPath = '/auth/send-otp';
  static const String verifyOtpPath = '/auth/verify-otp';

  /// Path for Firebase custom token (group chat). Backend must return { "token": "..." }.
  /// Override if your backend uses a different path, e.g. --dart-define=FIREBASE_TOKEN_PATH=/auth/firebase-token
  static const String firebaseTokenPath = String.fromEnvironment(
    'FIREBASE_TOKEN_PATH',
    defaultValue: '/me/firebase-token',
  );

  /// When true: use Firebase Phone Auth. When false: use Twilio backend (send-otp/verify-otp).
  static const bool useFirebaseAuth = bool.fromEnvironment(
    'USE_FIREBASE_AUTH',
    defaultValue: true,
  );

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
  static const String routeNewChat = '/chat/new-chat';
  static const String routeCreateGroup = '/create-group';
  static const String routeGroupSettings = '/group-settings';
  /// Path for 1:1 conversation; use [chatConversationPath(chatId)] to build.
  static String chatConversationPath(String chatId) => '/chat/$chatId';
  /// Path for group conversation; use [groupConversationPath(groupId)] to build.
  static String groupConversationPath(String groupId) => '/chat/group/$groupId';
  static const String routeProfile = '/profile';
  static const String routeEditProfile = '/edit-profile';
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
  static const String routeSurveys = '/surveys';
  static String surveyDetailPath(String surveyId) => '/surveys/$surveyId';
}
