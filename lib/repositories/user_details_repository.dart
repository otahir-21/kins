import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/models/user_model.dart';
import 'package:kins_app/services/bunny_cdn_service.dart';
import 'dart:io';

import '../models/user_profile_status.dart';

/// Lookup collection names for O(1) uniqueness checks (document ID = normalized value).
const String _usernamesCollection = 'usernames';
const String _emailsCollection = 'emails';
const String _phonesCollection = 'phones';

class UserDetailsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BunnyCDNService? _bunnyCDN;

  UserDetailsRepository({BunnyCDNService? bunnyCDN}) : _bunnyCDN = bunnyCDN;

  static String _normalizeUsername(String username) =>
      username.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static String _normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');

  /// Check if username is available (not taken by another user). Case-insensitive.
  /// [currentUserId] if set: treat as available when claimed by this user (own username).
  Future<bool> checkUsernameAvailable(String username,
      {String? currentUserId}) async {
    final norm = _normalizeUsername(username);
    if (norm.isEmpty || norm.length < 2) return false;
    try {
      final doc = await _firestore.collection(_usernamesCollection).doc(norm).get();
      if (!doc.exists) return true;
      final existingUserId = doc.data()?['userId'] as String?;
      return existingUserId == currentUserId;
    } catch (e, st) {
      debugPrint('❌ checkUsernameAvailable: $e');
      debugPrint('   If this is PERMISSION_DENIED, add usernames/emails/phones rules (see FIRESTORE_SECURITY_RULES.md)');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Check if email is available. Case-insensitive.
  Future<bool> checkEmailAvailable(String email,
      {String? currentUserId}) async {
    final norm = _normalizeEmail(email);
    if (norm.isEmpty || !norm.contains('@')) return false;
    try {
      final doc = await _firestore.collection(_emailsCollection).doc(norm).get();
      if (!doc.exists) return true;
      final existingUserId = doc.data()?['userId'] as String?;
      return existingUserId == currentUserId;
    } catch (e, st) {
      debugPrint('❌ checkEmailAvailable: $e');
      debugPrint('   If this is PERMISSION_DENIED, add usernames/emails/phones rules (see FIRESTORE_SECURITY_RULES.md)');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Check if phone is available (digits-only normalization). [currentUserId] = own phone is available.
  Future<bool> checkPhoneAvailable(String phone,
      {String? currentUserId}) async {
    final norm = _normalizePhone(phone);
    if (norm.length < 8) return false;
    try {
      final doc = await _firestore.collection(_phonesCollection).doc(norm).get();
      if (!doc.exists) return true;
      final existingUserId = doc.data()?['userId'] as String?;
      return existingUserId == currentUserId;
    } catch (e, st) {
      debugPrint('❌ checkPhoneAvailable: $e');
      debugPrint('   If this is PERMISSION_DENIED, add usernames/emails/phones rules (see FIRESTORE_SECURITY_RULES.md)');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Save user details to Firestore and claim username/email/phone in lookup collections.
  Future<void> saveUserDetails({
    required String userId,
    required String name,
    required String email,
    required DateTime dateOfBirth,
    String? username,
    String? phoneNumber,
  }) async {
    try {
      final userData = {
        'name': name,
        'email': email,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (username != null && username.trim().isNotEmpty) {
        userData['username'] = username.trim();
      }
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        userData['phoneNumber'] = phoneNumber.trim();
      }

      await _firestore.collection('users').doc(userId).set(
            userData,
            SetOptions(merge: true),
          );

      final batch = _firestore.batch();
      if (username != null) {
        final norm = _normalizeUsername(username);
        if (norm.length >= 2) {
          final ref = _firestore.collection(_usernamesCollection).doc(norm);
          batch.set(ref, {'userId': userId});
        }
      }
      final emailNorm = _normalizeEmail(email);
      if (emailNorm.isNotEmpty) {
        final ref = _firestore.collection(_emailsCollection).doc(emailNorm);
        batch.set(ref, {'userId': userId});
      }
      if (phoneNumber != null) {
        final phoneNorm = _normalizePhone(phoneNumber);
        if (phoneNorm.length >= 8) {
          final ref = _firestore.collection(_phonesCollection).doc(phoneNorm);
          batch.set(ref, {'userId': userId});
        }
      }
      await batch.commit();

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
        bio: data['bio'] is String ? data['bio'] as String? : null,
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

  /// Update bio on user document
  Future<void> updateBio({required String userId, required String bio}) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'bio': bio,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Bio updated');
    } catch (e) {
      debugPrint('❌ Failed to update bio: $e');
      rethrow;
    }
  }

  /// Save phone number to user document and claim in phones lookup (called after OTP verification).
  Future<void> savePhoneNumber({
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      final normalized = _normalizePhone(phoneNumber);
      await _firestore.collection('users').doc(userId).set({
        'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (normalized.length >= 8) {
        await _firestore.collection(_phonesCollection).doc(normalized).set({
          'userId': userId,
        });
      }
      debugPrint('✅ Phone number saved: $phoneNumber');
    } catch (e) {
      debugPrint('❌ Failed to save phone number: $e');
      rethrow;
    }
  }
}
