import 'package:flutter/foundation.dart';
import 'package:kins_app/core/network/backend_api_client.dart';

/// Service for post interactions: likes, comments, shares, views
/// All operations use MongoDB backend API (no Firebase)
class InteractionService {
  InteractionService._();

  // ========== LIKES ==========

  /// Like a post
  static Future<void> likePost(String postId) async {
    try {
      debugPrint('🔵 POST /posts/$postId/like');
      
      final response = await BackendApiClient.post(
        '/posts/$postId/like',
        useAuth: true,
      );
      
      if (response['success'] != true) {
        final error = response['error'] ?? response['message'] ?? 'Failed to like post';
        throw Exception(error);
      }
      
      debugPrint('✅ Post liked: $postId');
    } catch (e) {
      debugPrint('❌ InteractionService.likePost error: $e');
      rethrow;
    }
  }

  /// Unlike a post
  static Future<void> unlikePost(String postId) async {
    try {
      debugPrint('🔵 DELETE /posts/$postId/like');
      
      final response = await BackendApiClient.delete(
        '/posts/$postId/like',
        useAuth: true,
      );
      
      if (response['success'] != true) {
        final error = response['error'] ?? response['message'] ?? 'Failed to unlike post';
        throw Exception(error);
      }
      
      debugPrint('✅ Post unliked: $postId');
    } catch (e) {
      debugPrint('❌ InteractionService.unlikePost error: $e');
      rethrow;
    }
  }

  /// Get users who liked a post (paginated)
  static Future<Map<String, dynamic>> getPostLikes({
    required String postId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await BackendApiClient.get(
        '/posts/$postId/likes?page=$page&limit=$limit',
        useAuth: true,
      );
      
      return response;
    } catch (e) {
      debugPrint('❌ InteractionService.getPostLikes error: $e');
      rethrow;
    }
  }

  // ========== COMMENTS ==========

  /// Create a comment or reply
  static Future<Map<String, dynamic>> createComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      debugPrint('🔵 POST /posts/$postId/comments');
      
      final body = <String, dynamic>{
        'content': content,
      };
      if (parentCommentId != null) {
        body['parentCommentId'] = parentCommentId;
      }
      
      final response = await BackendApiClient.post(
        '/posts/$postId/comments',
        body: body,
        useAuth: true,
      );
      
      if (response['success'] != true) {
        final error = response['error'] ?? response['message'] ?? 'Failed to create comment';
        throw Exception(error);
      }
      
      debugPrint('✅ Comment created');
      return response;
    } catch (e) {
      debugPrint('❌ InteractionService.createComment error: $e');
      rethrow;
    }
  }

  /// Get comments for a post (top-level only)
  static Future<Map<String, dynamic>> getPostComments({
    required String postId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      debugPrint('🔵 GET /posts/$postId/comments?page=$page&limit=$limit');
      
      final response = await BackendApiClient.get(
        '/posts/$postId/comments?page=$page&limit=$limit',
        useAuth: true,
      );
      
      debugPrint('✅ Loaded comments for post $postId');
      return response;
    } catch (e) {
      debugPrint('❌ InteractionService.getPostComments error: $e');
      rethrow;
    }
  }

  /// Get replies for a comment
  static Future<Map<String, dynamic>> getCommentReplies({
    required String commentId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      debugPrint('🔵 GET /comments/$commentId/replies?page=$page&limit=$limit');
      
      final response = await BackendApiClient.get(
        '/comments/$commentId/replies?page=$page&limit=$limit',
        useAuth: true,
      );
      
      debugPrint('✅ Loaded replies for comment $commentId');
      return response;
    } catch (e) {
      debugPrint('❌ InteractionService.getCommentReplies error: $e');
      rethrow;
    }
  }

  /// Delete a comment (soft delete)
  static Future<void> deleteComment(String commentId) async {
    try {
      debugPrint('🔵 DELETE /comments/$commentId');
      
      final response = await BackendApiClient.delete(
        '/comments/$commentId',
        useAuth: true,
      );
      
      if (response['success'] != true) {
        final error = response['error'] ?? response['message'] ?? 'Failed to delete comment';
        throw Exception(error);
      }
      
      debugPrint('✅ Comment deleted: $commentId');
    } catch (e) {
      debugPrint('❌ InteractionService.deleteComment error: $e');
      rethrow;
    }
  }

  /// Like a comment
  static Future<void> likeComment(String commentId) async {
    try {
      debugPrint('🔵 POST /comments/$commentId/like');
      
      final response = await BackendApiClient.post(
        '/comments/$commentId/like',
        useAuth: true,
      );
      
      if (response['success'] != true) {
        final error = response['error'] ?? response['message'] ?? 'Failed to like comment';
        throw Exception(error);
      }
      
      debugPrint('✅ Comment liked: $commentId');
    } catch (e) {
      debugPrint('❌ InteractionService.likeComment error: $e');
      rethrow;
    }
  }

  /// Unlike a comment
  static Future<void> unlikeComment(String commentId) async {
    try {
      debugPrint('🔵 DELETE /comments/$commentId/like');
      
      final response = await BackendApiClient.delete(
        '/comments/$commentId/like',
        useAuth: true,
      );
      
      if (response['success'] != true) {
        final error = response['error'] ?? response['message'] ?? 'Failed to unlike comment';
        throw Exception(error);
      }
      
      debugPrint('✅ Comment unliked: $commentId');
    } catch (e) {
      debugPrint('❌ InteractionService.unlikeComment error: $e');
      rethrow;
    }
  }

  // ========== SHARES ==========

  /// Share a post
  static Future<Map<String, dynamic>> sharePost({
    required String postId,
    required String shareType, // "repost" | "external" | "direct_message"
    String? caption,
  }) async {
    try {
      debugPrint('🔵 POST /posts/$postId/share');
      
      final body = <String, dynamic>{
        'shareType': shareType,
      };
      if (caption != null && caption.isNotEmpty) {
        body['caption'] = caption;
      }
      
      final response = await BackendApiClient.post(
        '/posts/$postId/share',
        body: body,
        useAuth: true,
      );
      
      if (response['success'] != true) {
        final error = response['error'] ?? response['message'] ?? 'Failed to share post';
        throw Exception(error);
      }
      
      debugPrint('✅ Post shared: $postId ($shareType)');
      return response;
    } catch (e) {
      debugPrint('❌ InteractionService.sharePost error: $e');
      rethrow;
    }
  }

  /// Get users who shared a post
  static Future<Map<String, dynamic>> getPostShares({
    required String postId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await BackendApiClient.get(
        '/posts/$postId/shares?page=$page&limit=$limit',
        useAuth: true,
      );
      
      return response;
    } catch (e) {
      debugPrint('❌ InteractionService.getPostShares error: $e');
      rethrow;
    }
  }

  // ========== VIEWS ==========

  /// Increment view count for a post
  static Future<void> incrementView(String postId) async {
    try {
      // Silent operation - don't log to reduce noise
      await BackendApiClient.post(
        '/posts/$postId/view',
        useAuth: true,
      );
    } catch (e) {
      // Silently fail - views are not critical
      debugPrint('❌ InteractionService.incrementView error: $e');
    }
  }
}
