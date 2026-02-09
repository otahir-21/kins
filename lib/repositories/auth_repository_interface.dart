import 'package:kins_app/models/user_model.dart';

/// Common interface for phone auth. Implemented by [TwilioAuthRepository] and [FirebaseAuthRepository].
abstract class AuthRepositoryInterface {
  Future<void> sendOTP(String phoneNumber);
  Future<UserModel> verifyOTP(String phoneNumber, String otp);
  Future<void> signOut();
  bool isAuthenticated();
  String? getStoredUserId();
  String? getStoredToken();
}
