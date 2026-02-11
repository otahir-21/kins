import 'package:kins_app/models/auth_result.dart';
import 'package:kins_app/models/user_model.dart';

/// Common interface for auth. Implemented by [TwilioAuthRepository] and [FirebaseAuthRepository].
abstract class AuthRepositoryInterface {
  Future<void> sendOTP(String phoneNumber);
  Future<UserModel> verifyOTP(String phoneNumber, String otp);

  /// Google Sign-In (Firebase only). Returns null if not supported (e.g. Twilio backend).
  Future<GoogleSignInResult?> signInWithGoogle();

  Future<void> signOut();
  bool isAuthenticated();
  String? getStoredUserId();
  String? getStoredToken();
}
