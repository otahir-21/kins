import 'package:kins_app/models/google_profile_data.dart';
import 'package:kins_app/models/user_model.dart';

/// Result of Google Sign-In: user and optional profile data to pre-fill About You.
class GoogleSignInResult {
  const GoogleSignInResult({
    required this.user,
    this.googleProfile,
  });

  final UserModel user;
  final GoogleProfileData? googleProfile;
}
