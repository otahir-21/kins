import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/models/interest_model.dart';

class InterestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all active interests from Firestore
  Future<List<InterestModel>> getInterests() async {
    try {
      // Query only active interests, ordered by name
      final snapshot = await _firestore
          .collection('interests')
          .where('isActive', isEqualTo: true)
          .orderBy('name', descending: false)
          .get();

      final interests = snapshot.docs
          .map((doc) => InterestModel.fromFirestore(doc.id, doc.data()))
          .toList();

      debugPrint('✅ Loaded ${interests.length} active interests from Firestore');
      return interests;
    } catch (e) {
      debugPrint('❌ Failed to get interests: $e');
      
      // Fallback: try without orderBy if it fails (in case index is missing)
      try {
        final snapshot = await _firestore
            .collection('interests')
            .where('isActive', isEqualTo: true)
            .get();

        final interests = snapshot.docs
            .map((doc) => InterestModel.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)); // Sort manually

        debugPrint('✅ Loaded ${interests.length} active interests (fallback)');
        return interests;
      } catch (fallbackError) {
        debugPrint('❌ Fallback also failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Save user's selected interests
  Future<void> saveUserInterests({
    required String userId,
    required List<String> interestIds,
  }) async {
    try {
      // Use set with merge to ensure document exists, or update if it does
      await _firestore.collection('users').doc(userId).set({
        'interests': interestIds,
        'interestsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ User interests saved: ${interestIds.length} interests');
      debugPrint('📝 Saved interest IDs: $interestIds');
    } catch (e) {
      debugPrint('❌ Failed to save user interests: $e');
      rethrow;
    }
  }

  /// Get user's selected interests
  Future<List<String>> getUserInterests(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return [];

      final data = doc.data();
      final interests = data?['interests'] as List<dynamic>?;
      
      if (interests == null) return [];
      
      return interests.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('❌ Failed to get user interests: $e');
      return [];
    }
  }
}
