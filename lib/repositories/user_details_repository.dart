import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/models/user_model.dart';
import 'package:kins_app/services/bunny_cdn_service.dart';
import 'dart:io';

import '../models/user_profile_status.dart';

class UserDetailsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BunnyCDNService? _bunnyCDN;

  UserDetailsRepository({BunnyCDNService? bunnyCDN}) : _bunnyCDN = bunnyCDN;

  /// Save user details to Firestore
  Future<void> saveUserDetails({
    required String userId,
    required String name,
    required String email,
    required DateTime dateOfBirth,
  }) async {
    try {
      final userData = {
        'name': name,
        'email': email,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).set(
        userData,
        SetOptions(merge: true),
      );

      debugPrint('✅ User details saved to Firestore: $userId');
    } catch (e) {
      debugPrint('❌ Failed to save user details: $e');
      rethrow;
    }
  }

  /// Upload document to Bunny CDN and save file info to Firestore
  Future<String> uploadDocument({
    required String userId,
    required File documentFile,
  }) async {
    if (_bunnyCDN == null) {
      throw Exception('Bunny CDN service not configured');
    }

    try {
      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${userId}_$timestamp.pdf';
      final uploadPath = 'documents/$fileName';

      // Upload to Bunny CDN
      final documentUrl = await _bunnyCDN!.uploadFile(
        file: documentFile,
        fileName: fileName,
        path: 'documents/',
      );

      // Save file info to Firestore
      final fileInfo = {
        'url': documentUrl,
        'fileName': fileName,
        'uploadedAt': FieldValue.serverTimestamp(),
        'size': await documentFile.length(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('documents')
          .add(fileInfo);

      debugPrint('✅ Document uploaded and file info saved: $documentUrl');
      return documentUrl;
    } catch (e) {
      debugPrint('❌ Failed to upload document: $e');
      rethrow;
    }
  }

  /// Get user details from Firestore
  Future<UserModel?> getUserDetails(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      final profilePic = data['profilePictureUrl'] ?? data['profilePicture'];
      return UserModel(
        uid: userId,
        phoneNumber: data['phoneNumber'] ?? '',
        name: data['name'],
        gender: data['gender'],
        documentUrl: data['documentUrl'],
        status: data['status'],
        createdAt: data['createdAt']?.toDate(),
        profilePictureUrl: profilePic is String ? profilePic : null,
      );
    } catch (e) {
      debugPrint('❌ Failed to get user details: $e');
      rethrow;
    }
  }

  /// Update user status (motherhood status)
  Future<void> updateUserStatus({
    required String userId,
    required String status,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ User status updated: $status');
    } catch (e) {
      debugPrint('❌ Failed to update user status: $e');
      rethrow;
    }
  }

  /// Find user by phone number and check profile completion status
  Future<UserProfileStatus> checkUserByPhoneNumber(String phoneNumber) async {
    try {
      // Query users collection by phone number
      final querySnapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('📱 Phone number not found: $phoneNumber');
        return UserProfileStatus(
          exists: false,
          phoneNumber: phoneNumber,
        );
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final userId = doc.id;

      // Check if profile is complete (name, email, dateOfBirth)
      final hasName = data['name'] != null && 
                      (data['name'] as String).trim().isNotEmpty;
      final hasEmail = data['email'] != null && 
                       (data['email'] as String).trim().isNotEmpty;
      final hasDateOfBirth = data['dateOfBirth'] != null;
      
      final hasProfile = hasName && hasEmail && hasDateOfBirth;

      // Check if interests exist and has at least one
      final interests = data['interests'] as List<dynamic>?;
      final hasInterests = interests != null && interests.isNotEmpty;

      debugPrint('📱 User found: $userId');
      debugPrint('   Profile complete: $hasProfile (name: $hasName, email: $hasEmail, DOB: $hasDateOfBirth)');
      debugPrint('   Interests: $hasInterests (count: ${interests?.length ?? 0})');

      return UserProfileStatus(
        exists: true,
        hasProfile: hasProfile,
        hasInterests: hasInterests,
        userId: userId,
        phoneNumber: phoneNumber,
      );
    } catch (e) {
      debugPrint('❌ Failed to check user by phone number: $e');
      // Return not found on error
      return UserProfileStatus(
        exists: false,
        phoneNumber: phoneNumber,
      );
    }
  }

  /// Save phone number to user document (called after OTP verification)
  Future<void> savePhoneNumber({
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Phone number saved: $phoneNumber');
    } catch (e) {
      debugPrint('❌ Failed to save phone number: $e');
      rethrow;
    }
  }
}
