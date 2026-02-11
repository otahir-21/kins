import 'package:flutter/foundation.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/models/interest_model.dart';

/// Interests from backend API: GET /interests, GET /me/interests, POST /me/interests.
/// No Firebase Firestore.
class InterestRepository {
  /// Get all interests from GET /interests.
  /// API returns { "success": true, "interests": [...] } or { "data": [...] }, not a raw array.
  Future<List<InterestModel>> getInterests() async {
    try {
      final raw = await BackendApiClient.get('/interests', useAuth: false);
      final list = raw['interests'] ?? raw['data'];
      if (list is! List || list.isEmpty) {
        debugPrint('✅ GET /interests: no list (got keys: ${raw.keys.toList()})');
        return [];
      }
      final interests = list
          .where((e) => e is Map)
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            if (!m.containsKey('id') && m.containsKey('_id')) {
              m['id'] = m['_id'];
            }
            return InterestModel.fromMap(m);
          })
          .toList();
      interests.sort((a, b) => a.name.compareTo(b.name));
      debugPrint('✅ Loaded ${interests.length} interests from API');
      return interests;
    } catch (e) {
      debugPrint('❌ Failed to get interests: $e');
      rethrow;
    }
  }

  /// Save user's selected interests via POST /me/interests.
  Future<void> saveUserInterests({
    required String userId,
    required List<String> interestIds,
  }) async {
    try {
      await BackendApiClient.post(
        '/me/interests',
        body: {'interestIds': interestIds},
      );
      debugPrint('✅ User interests saved: ${interestIds.length} interests');
    } catch (e) {
      debugPrint('❌ Failed to save user interests: $e');
      rethrow;
    }
  }

  /// Get current user's selected interest IDs from GET /me/interests.
  Future<List<String>> getUserInterests(String userId) async {
    try {
      final raw = await BackendApiClient.get('/me/interests');
      final list = raw['interests'] ?? raw['interestIds'];
      if (list is List) return list.map((e) => e.toString()).toList();
      return [];
    } catch (e) {
      debugPrint('❌ Failed to get user interests: $e');
      return [];
    }
  }
}
