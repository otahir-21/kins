import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/services/bunny_cdn_service.dart';

class PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BunnyCDNService? _bunnyCDN;

  static const String _postsCollection = 'posts';
  static const String _votesSubcollection = 'votes';
  static const int _feedLimit = 50;

  PostRepository({BunnyCDNService? bunnyCDN}) : _bunnyCDN = bunnyCDN;

  /// Create a post (text, image, video, or poll)
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
    String? mediaUrl;
    String? thumbnailUrl;

    if ((type == PostType.image || type == PostType.video) && mediaFile != null && _bunnyCDN != null) {
      final path = isVideo ? 'posts/videos/' : 'posts/images/';
      final ext = mediaFile.path.split('.').last;
      final name = '${authorId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      mediaUrl = await _bunnyCDN!.uploadFile(
        file: mediaFile,
        fileName: name,
        path: path,
      );
      debugPrint('✅ Media uploaded: $mediaUrl');
    }

    final ref = _firestore.collection(_postsCollection).doc();
    final postData = {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'type': type.name,
      'text': text ?? '',
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'topics': topics,
      'likesCount': 0,
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (poll != null) 'poll': poll.toMap(),
    };

    await ref.set(postData);
    debugPrint('✅ Post created: ${ref.id}');
    return ref.id;
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
}
