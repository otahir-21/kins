import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/models/kin_location_model.dart';
import 'package:kins_app/services/location_service.dart';

class LocationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save user location to Firestore
  Future<void> saveUserLocation({
    required String userId,
    required double latitude,
    required double longitude,
    required bool isVisible,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'updatedAt': FieldValue.serverTimestamp(),
          'isVisible': isVisible,
        },
      }, SetOptions(merge: true));

      debugPrint('✅ User location saved: $latitude, $longitude');
    } catch (e) {
      debugPrint('❌ Failed to save user location: $e');
      rethrow;
    }
  }

  /// Update location visibility
  Future<void> updateLocationVisibility({
    required String userId,
    required bool isVisible,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'location.isVisible': isVisible,
        'location.updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Location visibility updated: $isVisible');
    } catch (e) {
      debugPrint('❌ Failed to update location visibility: $e');
      rethrow;
    }
  }

  /// Get nearby kins (visible users within radius)
  Stream<List<KinLocationModel>> getNearbyKins({
    required double centerLat,
    required double centerLng,
    double radiusKm = 50.0, // Default 50km radius
    String? motherhoodStatusFilter,
    String? nationalityFilter,
  }) {
    final locationService = LocationService();
    
    // Calculate bounding box for geohash query (simplified)
    // For production, consider using geohash or Firestore geoqueries
    // For now, we'll fetch all visible users and filter in the app
    
    return _firestore
        .collection('users')
        .where('location.isVisible', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final kins = <KinLocationModel>[];

      for (var doc in snapshot.docs) {
        try {
          final kin = KinLocationModel.fromFirestore(doc.id, doc.data());
          
          // Filter by distance
          final distance = locationService.calculateDistance(
            centerLat,
            centerLng,
            kin.latitude,
            kin.longitude,
          );
          if (distance > radiusKm) continue;

          // Filter by motherhood status
          if (motherhoodStatusFilter != null &&
              motherhoodStatusFilter.isNotEmpty) {
            if (kin.motherhoodStatus != motherhoodStatusFilter) continue;
          }

          // Filter by nationality
          if (nationalityFilter != null && nationalityFilter.isNotEmpty) {
            if (kin.nationality != nationalityFilter) continue;
          }

          kins.add(kin);
        } catch (e) {
          debugPrint('❌ Error parsing kin location: $e');
        }
      }

      return kins;
    });
  }

  /// Get user's location visibility status
  Future<bool> getUserLocationVisibility(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return true; // Default to visible

      final location = doc.data()?['location'] as Map<String, dynamic>?;
      return location?['isVisible'] ?? true;
    } catch (e) {
      debugPrint('❌ Failed to get location visibility: $e');
      return true; // Default to visible
    }
  }

  /// Get user's current location from Firestore
  Future<KinLocationModel?> getUserLocation(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      return KinLocationModel.fromFirestore(userId, doc.data()!);
    } catch (e) {
      debugPrint('❌ Failed to get user location: $e');
      return null;
    }
  }
}
