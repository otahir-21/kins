// Barrel: shared auth interface and implementations.
// Use [AuthRepository] (typedef) in app code; provider returns [TwilioAuthRepository] or [FirebaseAuthRepository] by config.

export 'package:kins_app/repositories/auth_repository_interface.dart';
export 'package:kins_app/repositories/twilio_auth_repository.dart';
export 'package:kins_app/repositories/firebase_auth_repository.dart';

import 'package:kins_app/repositories/auth_repository_interface.dart';

/// Alias for [AuthRepositoryInterface] so existing code using [AuthRepository] still compiles.
typedef AuthRepository = AuthRepositoryInterface;
