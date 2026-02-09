import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/repositories/auth_repository.dart';

/// Deletes the user's Firebase Auth account (when using Firebase Auth),
/// all related Firestore data (user doc, subcollections, posts by user),
/// and clears local auth state.
class AccountDeletionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _batchSize = 100;

  /// Delete all documents in a collection (or subcollection). Runs in batches.
  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> ref) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    do {
      snapshot = await ref.limit(_batchSize).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == _batchSize);
  }

  /// Delete account: Firestore user data, then Firebase Auth user (if applicable), then sign out.
  Future<void> deleteAccount({
    required String userId,
    required AuthRepository authRepository,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      // 1. Delete user subcollections
      await _deleteCollection(userRef.collection('following'));
      await _deleteCollection(userRef.collection('followers'));
      await _deleteCollection(userRef.collection('documents'));
      await _deleteCollection(userRef.collection('notifications'));

      // 2. Delete posts by this user (in batches)
      QuerySnapshot<Map<String, dynamic>> postsSnapshot;
      do {
        postsSnapshot = await _firestore
            .collection('posts')
            .where('authorId', isEqualTo: userId)
            .limit(_batchSize)
            .get();
        if (postsSnapshot.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in postsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } while (postsSnapshot.docs.length == _batchSize);

      // 3. Delete the user document
      await userRef.delete();

      // 4. Delete Firebase Auth user when using Firebase Auth
      if (AppConstants.useFirebaseAuth) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.delete();
        }
      }

      // 5. Sign out and clear local storage
      await authRepository.signOut();

      debugPrint('✅ Account and data deleted for user: $userId');
    } catch (e) {
      debugPrint('❌ Account deletion error: $e');
      rethrow;
    }
  }
}
