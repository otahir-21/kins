import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/models/kin_location_model.dart';

/// User location and visibility via backend API (GET /me, PUT /me/about).
/// No Firestore. Lat/lng and locationIsVisible stored in Mongo.
class LocationRepository {
  /// Save user location to backend via PUT /me/about.
  /// Uses reverse geocoding to fill city and country from lat/lng; sends them if backend accepts.
  Future<void> saveUserLocation({
    required String userId,
    required double latitude,
    required double longitude,
    required bool isVisible,
  }) async {
    try {
      // Clamp to valid ranges (backend: lat [-90,90], lng [-180,180])
      final lat = latitude.clamp(-90.0, 90.0);
      final lng = longitude.clamp(-180.0, 180.0);

      String? city;
      String? country;
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          city = p.locality?.trim().isNotEmpty == true ? p.locality : p.subAdministrativeArea;
          country = p.country;
        }
      } catch (e) {
        debugPrint('⚠️ Reverse geocoding failed (continuing without city/country): $e');
      }

      final body = <String, dynamic>{
        'latitude': lat,
        'longitude': lng,
        'locationIsVisible': isVisible,
      };
      if (city != null && city.isNotEmpty) body['city'] = city;
      if (country != null && country.isNotEmpty) body['country'] = country;

      await BackendApiClient.put('/me/about', body: body);
      debugPrint('✅ User location saved via PUT /me/about: $lat, $lng, visible=$isVisible');
    } catch (e) {
      debugPrint('❌ Failed to save user location: $e');
      rethrow;
    }
  }

  /// Update location visibility via PUT /me/about.
  Future<void> updateLocationVisibility({
    required String userId,
    required bool isVisible,
  }) async {
    try {
      await BackendApiClient.put('/me/about', body: {'locationIsVisible': isVisible});
      debugPrint('✅ Location visibility updated via PUT /me/about: $isVisible');
    } catch (e) {
      debugPrint('❌ Failed to update location visibility: $e');
      rethrow;
    }
  }

  /// Get user's location visibility from GET /me.
  /// Backend: locationIsVisible (default false).
  Future<bool> getUserLocationVisibility(String userId) async {
    try {
      final me = await BackendApiClient.get('/me');
      final user = me['user'] as Map<String, dynamic>? ?? me as Map<String, dynamic>;
      final loc = user['location'] as Map<String, dynamic>?;
      if (loc != null && loc.containsKey('isVisible')) {
        return loc['isVisible'] == true;
      }
      final visible = user['locationIsVisible'];
      if (visible is bool) return visible;
      return false;
    } catch (e) {
      debugPrint('❌ Failed to get location visibility: $e');
      return false;
    }
  }

  /// Get current user's location from GET /me (latitude, longitude from user or user.location).
  Future<KinLocationModel?> getUserLocation(String userId) async {
    try {
      final me = await BackendApiClient.get('/me');
      final user = me['user'] as Map<String, dynamic>? ?? me as Map<String, dynamic>;
      final lat = user['latitude'];
      final lng = user['longitude'];
      if (lat == null || lng == null) {
        final loc = user['location'] as Map<String, dynamic>?;
        if (loc == null) return null;
        final lat2 = loc['latitude'];
        final lng2 = loc['longitude'];
        if (lat2 == null || lng2 == null) return null;
        return KinLocationModel.fromBackend(userId, user);
      }
      return KinLocationModel.fromBackend(userId, user);
    } catch (e) {
      debugPrint('❌ Failed to get user location: $e');
      return null;
    }
  }

  /// Get nearby kins from backend GET /users/nearby.
  /// Query: latitude, longitude (optional; backend uses current user's location if omitted), radiusKm (1–500, default 50), limit (1–200, default 100).
  /// Response: { success: true, nearby: [ { id, name, username, displayName, profilePictureUrl, latitude, longitude, distanceKm, isFollowedByMe } ] }.
  Stream<List<KinLocationModel>> getNearbyKins({
    required double centerLat,
    required double centerLng,
    double radiusKm = 50.0,
    int limit = 100,
    String? motherhoodStatusFilter,
    String? nationalityFilter,
  }) async* {
    try {
      final path = '/users/nearby?latitude=$centerLat&longitude=$centerLng&radiusKm=${radiusKm.clamp(1.0, 500.0)}&limit=${limit.clamp(1, 200)}';
      final raw = await BackendApiClient.get(path);
      List<dynamic> list = raw['nearby'] is List ? (raw['nearby'] as List<dynamic>) : <dynamic>[];
      final kins = <KinLocationModel>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final kin = KinLocationModel.fromBackend(
            item['id']?.toString() ?? item['_id']?.toString() ?? '',
            item,
          );
          if (motherhoodStatusFilter != null && motherhoodStatusFilter.isNotEmpty) {
            if (kin.motherhoodStatus != motherhoodStatusFilter) continue;
          }
          if (nationalityFilter != null && nationalityFilter.isNotEmpty) {
            if (kin.nationality != nationalityFilter) continue;
          }
          kins.add(kin);
        } catch (e) {
          debugPrint('❌ Error parsing kin from nearby: $e');
        }
      }
      yield kins;
    } catch (e) {
      debugPrint('⚠️ getNearbyKins failed: $e');
      yield [];
    }
  }
}
