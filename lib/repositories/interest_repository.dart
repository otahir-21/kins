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
            final id = m['_id'] ?? m['id'];
            m['id'] = id != null ? id.toString() : '';
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
  /// API may return interests: [{ _id, name }, ...] or interestIds: ["id1", ...].
  Future<List<String>> getUserInterests(String userId) async {
    try {
      final raw = await BackendApiClient.get('/me/interests');
      final list = raw['interests'] ?? raw['interestIds'];
      if (list is! List || list.isEmpty) return [];
      return list.map((e) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e as Map);
          return (m['_id'] ?? m['id'])?.toString() ?? '';
        }
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      debugPrint('❌ Failed to get user interests: $e');
      return [];
    }
  }
}
