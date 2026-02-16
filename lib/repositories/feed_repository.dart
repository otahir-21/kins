import 'package:flutter/foundation.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/models/comment_model.dart';
import 'package:kins_app/services/feed_service.dart';
import 'package:kins_app/services/interaction_service.dart';

/// Repository for feed operations using backend API (NO FIREBASE)
class FeedRepository {
  FeedRepository();

  static const int defaultLimit = 20;
  static const int maxLimit = 100;

  /// Get feed with pagination
  Future<List<PostModel>> getFeed({
    int page = 1,
    int limit = defaultLimit,
  }) async {
    try {
      if (limit > maxLimit) limit = maxLimit;
      if (page < 1) page = 1;

      final posts = await FeedService.getFeed(page: page, limit: limit);
      return posts;
    } catch (e) {
      debugPrint('❌ FeedRepository.getFeed error: $e');
      rethrow;
    }
  }

  // ========== LIKES ==========

  /// Like a post
  Future<void> likePost(String postId) async {
    try {
      await InteractionService.likePost(postId);
    } catch (e) {
      debugPrint('❌ FeedRepository.likePost error: $e');
      rethrow;
    }
  }

  /// Unlike a post
  Future<void> unlikePost(String postId) async {
    try {
      await InteractionService.unlikePost(postId);
    } catch (e) {
      debugPrint('❌ FeedRepository.unlikePost error: $e');
      rethrow;
    }
  }

  // ========== COMMENTS ==========

  /// Create a comment or reply
  Future<CommentModel> createComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final response = await InteractionService.createComment(
        postId: postId,
        content: content,
        parentCommentId: parentCommentId,
      );
      
      final commentJson = response['comment'] as Map<String, dynamic>;
      return CommentModel.fromJson(commentJson);
    } catch (e) {
      debugPrint('❌ FeedRepository.createComment error: $e');
      rethrow;
    }
  }

  /// Get comments for a post (top-level only)
  Future<List<CommentModel>> getPostComments({
    required String postId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await InteractionService.getPostComments(
        postId: postId,
        page: page,
        limit: limit,
      );
      
      final comments = response['comments'] as List<dynamic>? ?? [];
      return comments
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ FeedRepository.getPostComments error: $e');
      return [];
    }
  }

  /// Get replies for a comment
  Future<List<CommentModel>> getCommentReplies({
    required String commentId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await InteractionService.getCommentReplies(
        commentId: commentId,
        page: page,
        limit: limit,
      );
      
      final replies = response['comments'] as List<dynamic>? ?? 
                      response['replies'] as List<dynamic>? ?? [];
      return replies
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ FeedRepository.getCommentReplies error: $e');
      return [];
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      await InteractionService.deleteComment(commentId);
    } catch (e) {
      debugPrint('❌ FeedRepository.deleteComment error: $e');
      rethrow;
    }
  }

  /// Like a comment
  Future<void> likeComment(String commentId) async {
    try {
      await InteractionService.likeComment(commentId);
    } catch (e) {
      debugPrint('❌ FeedRepository.likeComment error: $e');
      rethrow;
    }
  }

  /// Unlike a comment
  Future<void> unlikeComment(String commentId) async {
    try {
      await InteractionService.unlikeComment(commentId);
    } catch (e) {
      debugPrint('❌ FeedRepository.unlikeComment error: $e');
      rethrow;
    }
  }

  // ========== SHARES ==========

  /// Share a post
  Future<void> sharePost({
    required String postId,
    required String shareType,
    String? caption,
  }) async {
    try {
      await InteractionService.sharePost(
        postId: postId,
        shareType: shareType,
        caption: caption,
      );
    } catch (e) {
      debugPrint('❌ FeedRepository.sharePost error: $e');
      rethrow;
    }
  }

  // ========== POLLS ==========

  /// Vote on a poll
  /// Returns updated poll data with vote counts and percentages
  Future<Map<String, dynamic>> votePoll({
    required String postId,
    required int optionIndex,
  }) async {
    try {
      return await FeedService.votePoll(postId: postId, optionIndex: optionIndex);
    } catch (e) {
      debugPrint('❌ FeedRepository.votePoll error: $e');
      rethrow;
    }
  }

  // ========== VIEWS ==========

  /// Increment view count (silent operation)
  Future<void> incrementView(String postId) async {
    try {
      await InteractionService.incrementView(postId);
    } catch (e) {
      // Silently fail - views are not critical
    }
  }

  // ========== MY POSTS ==========

  /// Get posts by user ID (user's original posts)
  /// Endpoint: GET /posts?userId=userId
  Future<List<PostModel>> getPostsByUserId({
    required String userId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      return await FeedService.getPostsByUserId(
        userId: userId,
        page: page,
        limit: limit,
      );
    } catch (e) {
      debugPrint('❌ FeedRepository.getPostsByUserId error: $e');
      return [];
    }
  }

  /// Get posts reposted by user
  /// Endpoint: GET /posts?repostedBy=userId
  Future<List<PostModel>> getRepostsByUserId({
    required String userId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      return await FeedService.getRepostsByUserId(
        userId: userId,
        page: page,
        limit: limit,
      );
    } catch (e) {
      debugPrint('❌ FeedRepository.getRepostsByUserId error: $e');
      return [];
    }
  }

  /// Get user's own posts with pagination
  /// 
  /// Note: Your own posts don't appear in the main feed by design.
  /// Use this method to retrieve posts created by the logged-in user.
  Future<List<PostModel>> getMyPosts({
    int page = 1,
    int limit = defaultLimit,
  }) async {
    try {
      if (limit > maxLimit) limit = maxLimit;
      if (page < 1) page = 1;

      // FeedService now returns parsed PostModel objects
      return await FeedService.getMyPosts(page: page, limit: limit);
    } catch (e) {
      debugPrint('❌ FeedRepository.getMyPosts error: $e');
      rethrow;
    }
  }
}

