import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/models/user_model.dart';
import 'package:kins_app/services/bunny_cdn_service.dart';
import 'dart:io';

class UserDetailsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BunnyCDNService? _bunnyCDN;

  UserDetailsRepository({BunnyCDNService? bunnyCDN}) : _bunnyCDN = bunnyCDN;

  /// Save user details to Firestore
  Future<void> saveUserDetails({
    required String userId,
    required String name,
    required String gender,
    String? documentUrl,
  }) async {
    try {
      final userData = {
        'name': name,
        'gender': gender,
        'documentUrl': documentUrl,
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
      return UserModel(
        uid: userId,
        phoneNumber: data['phoneNumber'] ?? '',
        name: data['name'],
        gender: data['gender'],
        documentUrl: data['documentUrl'],
        createdAt: data['createdAt']?.toDate(),
      );
    } catch (e) {
      debugPrint('❌ Failed to get user details: $e');
      rethrow;
    }
  }
}
