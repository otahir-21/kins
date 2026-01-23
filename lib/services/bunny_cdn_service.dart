import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service for uploading files to Bunny CDN
/// 
/// Required configuration:
/// - storageZoneName: Your Bunny CDN storage zone name
/// - apiKey: Your Bunny CDN API key (Storage Zone Password)
/// - cdnHostname: Your CDN hostname (e.g., "your-zone.b-cdn.net")
class BunnyCDNService {
  final String storageZoneName;
  final String apiKey;
  final String cdnHostname;

  BunnyCDNService({
    required this.storageZoneName,
    required this.apiKey,
    required this.cdnHostname,
  });

  /// Upload a file to Bunny CDN
  /// 
  /// [file] - The file to upload
  /// [fileName] - Optional custom file name. If not provided, uses original file name
  /// [path] - Optional path in storage (e.g., "documents/")
  /// 
  /// Returns the public URL of the uploaded file
  Future<String> uploadFile({
    required File file,
    String? fileName,
    String path = '',
  }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final name = fileName ?? file.path.split('/').last;
      
      // Ensure path doesn't start or end with slash
      String cleanPath = path.trim();
      if (cleanPath.isNotEmpty && !cleanPath.endsWith('/')) {
        cleanPath = '$cleanPath/';
      }
      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }
      
      final uploadPath = cleanPath.isEmpty ? name : '$cleanPath$name';
      
      // Determine the correct storage API endpoint based on region
      // Extract region from cdnHostname if it's a regional endpoint
      String storageEndpoint = 'storage.bunnycdn.com';
      if (cdnHostname.contains('storage.bunnycdn.com')) {
        // Extract region prefix (e.g., 'syd' from 'syd.storage.bunnycdn.com')
        final parts = cdnHostname.split('.');
        if (parts.length >= 3 && parts[0] != 'storage') {
          // Regional endpoint like syd.storage.bunnycdn.com
          storageEndpoint = cdnHostname;
        }
      }
      
      // Construct URL - ensure no double slashes
      final urlString = 'https://$storageEndpoint/$storageZoneName/$uploadPath'
          .replaceAll(RegExp(r'/+'), '/')
          .replaceAll(':/', '://');
      final url = Uri.parse(urlString);

      debugPrint('📤 Uploading file to Bunny CDN');
      debugPrint('   Storage Zone: $storageZoneName');
      debugPrint('   Path: $uploadPath');
      debugPrint('   URL: $urlString');
      debugPrint('   API Key length: ${apiKey.length}');
      debugPrint('   File size: ${fileBytes.length} bytes');

      // Bunny CDN Storage API requires AccessKey header with the storage zone password
      final headers = {
        'AccessKey': apiKey,
        'Content-Type': 'application/octet-stream',
      };

      debugPrint('   Headers: AccessKey=${apiKey.substring(0, 8)}...');

      final response = await http.put(
        url,
        headers: headers,
        body: fileBytes,
      );

      debugPrint('   Response Status: ${response.statusCode}');
      debugPrint('   Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Construct public URL
        // For Bunny CDN storage zones, public URLs are typically:
        // - If using pull zone: https://{pullZoneHostname}/{path}
        // - If using storage directly: https://{storageZoneName}.b-cdn.net/{path}
        // The provided hostname might be for API access only
        // For public access, you may need to use: https://{storageZoneName}.b-cdn.net/{path}
        final publicUrl = cdnHostname.contains('storage.bunnycdn.com')
            ? 'https://$storageZoneName.b-cdn.net/$uploadPath'
            : 'https://$cdnHostname/$uploadPath';
        debugPrint('✅ File uploaded successfully: $publicUrl');
        return publicUrl;
      } else {
        debugPrint('❌ Upload failed: ${response.statusCode} - ${response.body}');
        throw Exception(
          'Failed to upload file: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Bunny CDN upload error: $e');
      rethrow;
    }
  }

  /// Delete a file from Bunny CDN
  Future<void> deleteFile(String filePath) async {
    try {
      // Determine the correct storage API endpoint based on region
      String storageEndpoint = 'storage.bunnycdn.com';
      if (cdnHostname.contains('storage.bunnycdn.com')) {
        final parts = cdnHostname.split('.');
        if (parts.length >= 3 && parts[0] != 'storage') {
          storageEndpoint = cdnHostname;
        }
      }
      
      final url = Uri.parse(
        'https://$storageEndpoint/$storageZoneName/$filePath',
      );

      final response = await http.delete(
        url,
        headers: {
          'AccessKey': apiKey,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 404) {
        debugPrint('✅ File deleted successfully: $filePath');
      } else {
        debugPrint('❌ Delete failed: ${response.statusCode} - ${response.body}');
        throw Exception(
          'Failed to delete file: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Bunny CDN delete error: $e');
      rethrow;
    }
  }
}
