import 'package:flutter/foundation.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/services/interaction_service.dart';

/// Backend API service for feed operations (no Firebase)
class FeedService {
  FeedService._();

  /// Get feed from backend API with pagination
  /// 
  /// Parameters:
  /// - page: Page number (default: 1)
  /// - limit: Items per page (default: 20, max: 100)
  /// 
  /// Returns: List of PostModel
  static Future<List<PostModel>> getFeed({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      if (limit > 100) limit = 100;
      if (page < 1) page = 1;

      debugPrint('🔵 GET /feed?page=$page&limit=$limit');
      
      final response = await BackendApiClient.get(
        '/feed?page=$page&limit=$limit',
        useAuth: true,
      );
      
      debugPrint('🔵 GET /feed response: $response');
      
      if (response['success'] != true) {
        final error = response['error'] ?? response['message'] ?? 'Failed to load feed';
        throw Exception(error);
      }
      
      // Backend returns 'feed' field, not 'posts'
      final feedData = response['feed'] as List<dynamic>?;
      if (feedData == null || feedData.isEmpty) {
        debugPrint('⚠️ No feed data in response');
        return [];
      }
      
      final postModels = feedData
          .map((json) => _parseFeedPost(json as Map<String, dynamic>))
          .toList();
      
      debugPrint('✅ Loaded ${postModels.length} posts from backend');
      return postModels;
    } catch (e) {
      debugPrint('❌ FeedService.getFeed error: $e');
      rethrow;
    }
  }
  
  /// Like a post - delegates to InteractionService
  static Future<void> likePost(String postId) async {
    await InteractionService.likePost(postId);
  }

  /// Unlike a post - delegates to InteractionService
  static Future<void> unlikePost(String postId) async {
    await InteractionService.unlikePost(postId);
  }

  /// Check if current user liked a post
  static Future<bool> getLikeStatus(String postId) async {
    return await InteractionService.getLikeStatus(postId);
  }
  
  /// Vote on a poll
  /// Vote on a poll
  /// 
  /// Returns updated poll data with vote counts and percentages
  static Future<Map<String, dynamic>> votePoll({
    required String postId,
    required int optionIndex,
  }) async {
    try {
      debugPrint('🔵 POST /posts/$postId/vote (optionIndex: $optionIndex)');
      
      final response = await BackendApiClient.post(
        '/posts/$postId/vote',
        body: {'optionIndex': optionIndex},
        useAuth: true,
      );
      
      if (response['success'] != true) {
        final error = response['error'] ?? response['message'] ?? 'Failed to vote';
        throw Exception(error);
      }
      
      debugPrint('✅ Voted on poll: $postId, option: $optionIndex');
      return response;
    } catch (e) {
      debugPrint('❌ FeedService.votePoll error: $e');
      rethrow;
    }
  }
  
  /// Parse feed post from backend response
  /// 
  /// Backend feed format differs from standard post format:
  /// - userId object instead of simple authorId
  /// - content instead of text
  /// - Different structure for polls
  static PostModel _parseFeedPost(Map<String, dynamic> json) {
    // Extract author info from userId object
    final userIdObj = json['userId'] as Map<String, dynamic>?;
    final authorId = userIdObj?['_id']?.toString() ?? json['_id']?.toString() ?? '';
    final authorName = userIdObj?['name']?.toString() ?? 'Anonymous';
    final authorPhotoUrl = userIdObj?['profilePictureUrl']?.toString();
    
    // Parse post type
    final typeStr = json['type']?.toString() ?? 'text';
    PostType postType;
    try {
      postType = PostType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => PostType.text,
      );
    } catch (_) {
      postType = PostType.text;
    }
    
    // Parse poll data if exists
    PollData? pollData;
    final pollJson = json['poll'] as Map<String, dynamic>?;
    if (pollJson != null) {
      final question = pollJson['question']?.toString() ?? '';
      final optionsList = pollJson['options'] as List<dynamic>? ?? [];
      final options = optionsList.asMap().entries.map((entry) {
        final opt = entry.value as Map<String, dynamic>;
        return PollOption(
          text: opt['text']?.toString() ?? '',
          index: entry.key,
          count: (opt['votes'] ?? 0) as int,
        );
      }).toList();
      
      // Extract votedUsers array from poll
      final votedUsersList = pollJson['votedUsers'] as List<dynamic>? ?? [];
      final votedUsers = votedUsersList.map((id) => id.toString()).toList();
      
      pollData = PollData(
        question: question,
        options: options,
        totalVotes: (pollJson['totalVotes'] ?? 0) as int,
        votedUsers: votedUsers,
      );
    }
    
    // Parse media URL
    final media = json['media'] as List<dynamic>?;
    String? mediaUrl;
    if (media != null && media.isNotEmpty) {
      // Check if it's an array of strings (Bunny CDN URLs) or array of objects
      if (media.first is String) {
        mediaUrl = media.first.toString();
        debugPrint('📸 Image post detected: ID=${json['_id']}, URL=$mediaUrl');
      } else {
        final firstMedia = media.first as Map<String, dynamic>?;
        mediaUrl = firstMedia?['url']?.toString();
        debugPrint('📸 Image post detected: ID=${json['_id']}, URL=$mediaUrl');
      }
    }
    
    // Parse topics/interests (store IDs for filtering)
    final interests = json['interests'] as List<dynamic>?;
    final topics = interests?.map((i) {
      if (i is Map<String, dynamic>) {
        // Store the interest ID, not the name, for filtering to work
        return i['_id']?.toString() ?? i['id']?.toString() ?? '';
      }
      return i.toString();
    }).where((t) => t.isNotEmpty).toList() ?? [];
    
    // Parse dates
    DateTime createdAt;
    try {
      createdAt = json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now();
    } catch (_) {
      createdAt = DateTime.now();
    }
    
    return PostModel(
      id: json['_id']?.toString() ?? '',
      authorId: authorId,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      type: postType,
      text: json['content']?.toString(),
      mediaUrl: mediaUrl,
      thumbnailUrl: null,
      topics: topics,
      likesCount: (json['likesCount'] ?? 0) as int,
      commentsCount: (json['commentsCount'] ?? 0) as int,
      createdAt: createdAt,
      updatedAt: null,
      poll: pollData,
    );
  }
  
  /// Get poll results and check if user voted
  /// 
  /// Returns poll data including userVoted status.
  /// Note: userVotedOption is -1 because backend doesn't track which specific option user voted for.
  static Future<Map<String, dynamic>?> getPollResults(String postId) async {
    try {
      debugPrint('🔵 GET /posts/$postId/poll');
      
      final response = await BackendApiClient.get(
        '/posts/$postId/poll',
        useAuth: true,
      );
      
      if (response['success'] != true) {
        debugPrint('⚠️ Poll results not found or error');
        return null;
      }
      
      final pollData = response['poll'] as Map<String, dynamic>?;
      final userVoted = pollData?['userVoted'] == true;
      final totalVotes = pollData?['totalVotes'] ?? 0;
      debugPrint('✅ Poll results: userVoted=$userVoted, totalVotes=$totalVotes');
      
      return pollData;
    } catch (e) {
      debugPrint('❌ FeedService.getPollResults error: $e');
      return null;
    }
  }
  
  /// Legacy method - kept for backward compatibility
  /// Use getPollResults() instead for better poll information
  static Future<int?> getUserVote(String postId) async {
    final pollData = await getPollResults(postId);
    if (pollData == null) return null;
    
    final userVoted = pollData['userVoted'] == true;
    if (!userVoted) return null;
    
    // Return -1 to indicate user voted but we don't know which option
    // Backend doesn't track specific option per user (limitation)
    return -1;
  }

  /// Get user's own posts
  /// 
  /// Note: Your own posts don't appear in the main feed by design.
  /// Use this endpoint to see posts you've created.
  /// 
  /// Parameters:
  /// - page: Page number (default: 1)
  /// - limit: Items per page (default: 20)
  static Future<List<PostModel>> getMyPosts({int page = 1, int limit = 20}) async {
    try {
      debugPrint('🔵 GET /posts/my?page=$page&limit=$limit');
      final response = await BackendApiClient.get(
        '/posts/my?page=$page&limit=$limit',
        useAuth: true,
      );

      if (response['success'] != true) {
        debugPrint('⚠️ Failed to get my posts');
        return [];
      }

      final posts = response['posts'] as List<dynamic>?;
      if (posts == null || posts.isEmpty) {
        debugPrint('✅ No posts found');
        return [];
      }

      debugPrint('✅ Loaded ${posts.length} of my posts');
      
      // Parse using _parseFeedPost since /posts/my returns same format as /feed
      final postModels = posts
          .map((json) => _parseFeedPost(json as Map<String, dynamic>))
          .toList();
      
      debugPrint('✅ Parsed ${postModels.length} of my posts');
      return postModels;
    } catch (e) {
      debugPrint('❌ FeedService.getMyPosts error: $e');
      return [];
    }
  }
}
