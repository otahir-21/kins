import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/services/bunny_cdn_service.dart';
import 'package:kins_app/core/network/backend_api_client.dart';

class PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BunnyCDNService? _bunnyCDN;

  static const String _postsCollection = 'posts';
  static const String _votesSubcollection = 'votes';
  static const int _feedLimit = 50;

  PostRepository({BunnyCDNService? bunnyCDN}) : _bunnyCDN = bunnyCDN;

  /// Create a post (text, image, video, or poll)
  /// 
  /// Uses MongoDB backend API
  /// For image/video posts: sends actual file to backend (backend uploads to Bunny CDN)
  /// For text/poll posts: uses JSON
  Future<String> createPost({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required PostType type,
    String? text,
    File? mediaFile,
    bool isVideo = false,
    PollData? poll,
    List<String> topics = const [],
  }) async {
    try {
      debugPrint('🔵 POST /posts (type: ${type.name})');

      // For image/video posts, use multipart/form-data with actual file
      if ((type == PostType.image || type == PostType.video) && mediaFile != null) {
        return await _createMediaPost(
          type: type,
          mediaFile: mediaFile,
          isVideo: isVideo,
          text: text,
          topics: topics,
        );
      }

      // For text/poll posts, use JSON
      return await _createJsonPost(
        type: type,
        text: text,
        poll: poll,
        topics: topics,
      );
    } catch (e) {
      debugPrint('❌ PostRepository.createPost error: $e');
      rethrow;
    }
  }

  /// Create image/video post using multipart/form-data
  Future<String> _createMediaPost({
    required PostType type,
    required File mediaFile,
    required bool isVideo,
    String? text,
    required List<String> topics,
  }) async {
    final fields = <String, String>{
      'type': type.name,
    };

    // Add interests with array indexing (interestIds[0], interestIds[1], etc.)
    for (int i = 0; i < topics.length; i++) {
      fields['interestIds[$i]'] = topics[i];
    }

    // Add content
    if (text != null && text.isNotEmpty) {
      fields['content'] = text;
    }

    // Prepare file for upload
    final files = <http.MultipartFile>[];
    final fileName = mediaFile.path.split('/').last;
    final mimeType = isVideo
        ? http.MediaType('video', fileName.endsWith('.mov') ? 'quicktime' : 'mp4')
        : http.MediaType('image', 'jpeg');

    files.add(await http.MultipartFile.fromPath(
      'media', // Field name must be 'media'
      mediaFile.path,
      contentType: mimeType,
    ));

    debugPrint('📤 POST multipart fields: $fields');
    debugPrint('📤 Uploading file: $fileName');
    debugPrint('📤 Interests: $topics');

    final response = await BackendApiClient.postMultipart(
      '/posts',
      fields: fields,
      files: files,
      useAuth: true,
    );

    if (response['success'] != true) {
      final error = response['error'] ?? response['message'] ?? 'Failed to create post';
      throw Exception(error);
    }

    final postData = response['post'] as Map<String, dynamic>?;
    final postId = postData?['_id']?.toString() ?? postData?['id']?.toString() ?? '';

    debugPrint('✅ Media post created: $postId');
    return postId;
  }

  /// Create text/poll post using JSON
  Future<String> _createJsonPost({
    required PostType type,
    String? text,
    PollData? poll,
    required List<String> topics,
  }) async {
    final body = <String, dynamic>{
      'type': type.name,
      'interestIds': topics,
    };

    if (text != null && text.isNotEmpty) {
      body['content'] = text;
    }

    if (type == PostType.poll && poll != null) {
      body['poll'] = {
        'question': poll.question,
        'options': poll.options.map((opt) => {'text': opt.text}).toList(),
      };
    }

    debugPrint('📤 POST JSON: $body');

    final response = await BackendApiClient.post(
      '/posts',
      body: body,
      useAuth: true,
    );

    if (response['success'] != true) {
      final error = response['error'] ?? response['message'] ?? 'Failed to create post';
      throw Exception(error);
    }

    final postData = response['post'] as Map<String, dynamic>?;
    final postId = postData?['_id']?.toString() ?? postData?['id']?.toString() ?? '';

    debugPrint('✅ Text/poll post created: $postId');
    return postId;
  }

  /// Get feed stream (recent posts)
  Stream<List<PostModel>> getFeed({int limit = _feedLimit}) {
    return _firestore
        .collection(_postsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PostModel.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Get feed once (for initial load / refresh)
  Future<List<PostModel>> getFeedOnce({int limit = _feedLimit}) async {
    final snap = await _firestore
        .collection(_postsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((doc) => PostModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Get posts by author (for profile feed). Sorted by createdAt in memory to avoid composite index.
  Stream<List<PostModel>> getPostsByAuthor(String authorId, {int limit = 50}) {
    return _firestore
        .collection(_postsCollection)
        .where('authorId', isEqualTo: authorId)
        .limit(limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => PostModel.fromFirestore(doc.id, doc.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Get user's vote for a poll (optionIndex or null)
  Future<int?> getUserVote(String postId, String userId) async {
    final doc = await _firestore
        .collection(_postsCollection)
        .doc(postId)
        .collection(_votesSubcollection)
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data();
    return data?['optionIndex'] as int?;
  }

  /// Vote on a poll (one vote per user)
  Future<void> votePoll({
    required String postId,
    required String userId,
    required int optionIndex,
  }) async {
    await _firestore.runTransaction((tx) async {
      final voteRef = _firestore
          .collection(_postsCollection)
          .doc(postId)
          .collection(_votesSubcollection)
          .doc(userId);
      final postRef = _firestore.collection(_postsCollection).doc(postId);

      final voteDoc = await tx.get(voteRef);
      if (voteDoc.exists) {
        throw Exception('Already voted');
      }

      tx.set(voteRef, {
        'optionIndex': optionIndex,
        'votedAt': FieldValue.serverTimestamp(),
      });

      final postDoc = await tx.get(postRef);
      if (!postDoc.exists) throw Exception('Post not found');
      final data = postDoc.data()!;
      final poll = data['poll'] as Map<String, dynamic>?;
      if (poll == null) throw Exception('Not a poll post');

      final options = List<Map<String, dynamic>>.from(poll['options'] as List);
      if (optionIndex < 0 || optionIndex >= options.length) throw Exception('Invalid option');
      final opt = Map<String, dynamic>.from(options[optionIndex]);
      opt['count'] = ((opt['count'] ?? 0) as int) + 1;
      options[optionIndex] = opt;

      final totalVotes = ((poll['totalVotes'] ?? 0) as int) + 1;
      tx.update(postRef, {
        'poll': {'question': poll['question'], 'options': options, 'totalVotes': totalVotes, 'endTime': poll['endTime']},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    debugPrint('✅ Voted on poll $postId option $optionIndex');
  }

  /// Increment likes (optional - for like button)
  Future<void> incrementLikes(String postId) async {
    await _firestore.collection(_postsCollection).doc(postId).update({
      'likesCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a post using backend API
  /// 
  /// Endpoint: DELETE /posts/:postId
  /// Returns: {success: true, message: "Post deleted successfully"}
  Future<void> deletePost(String postId) async {
    try {
      debugPrint('🔵 DELETE /posts/$postId');
      
      final response = await BackendApiClient.delete(
        '/posts/$postId',
        useAuth: true,
      );

      if (response['success'] != true) {
        final error = response['error'] ?? response['message'] ?? 'Failed to delete post';
        throw Exception(error);
      }

      debugPrint('✅ Post deleted: $postId');
    } catch (e) {
      debugPrint('❌ PostRepository.deletePost error: $e');
      rethrow;
    }
  }
}
