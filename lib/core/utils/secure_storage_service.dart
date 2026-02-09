import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kins_app/core/constants/app_constants.dart';

/// Secure storage for JWT. Uses [FlutterSecureStorage] and an in-memory cache
/// so [getJwtTokenSync] can be used from sync code (e.g. auth_utils, splash).
class SecureStorageService {
  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static FlutterSecureStorage? _storage;
  static String? _cachedToken;

  static Future<void> init() async {
    _storage = const FlutterSecureStorage(aOptions: _androidOptions);
    _cachedToken = await _storage!.read(key: AppConstants.keyJwtToken);
  }

  /// Write JWT (e.g. after verify-otp). Updates cache.
  static Future<void> setJwt(String token) async {
    await _storage?.write(key: AppConstants.keyJwtToken, value: token);
    _cachedToken = token;
  }

  /// Delete JWT (e.g. on sign out). Clears cache.
  static Future<void> deleteJwt() async {
    await _storage?.delete(key: AppConstants.keyJwtToken);
    _cachedToken = null;
  }

  /// Sync getter for JWT (returns cached value). Call [init] at app startup.
  static String? getJwtTokenSync() => _cachedToken;
}
