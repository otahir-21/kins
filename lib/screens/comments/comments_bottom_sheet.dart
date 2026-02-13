import 'package:flutter/material.dart';
import 'package:kins_app/models/comment_model.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/repositories/feed_repository.dart';

/// Comments bottom sheet for viewing and creating comments/replies
class CommentsBottomSheet extends StatefulWidget {
  final PostModel post;
  final FeedRepository feedRepository;

  const CommentsBottomSheet({
    super.key,
    required this.post,
    required this.feedRepository,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  
  // Reply state
  CommentModel? _replyingTo;
  
  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final comments = await widget.feedRepository.getPostComments(
        postId: widget.post.id,
        limit: 50,
      );
      
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final newComment = await widget.feedRepository.createComment(
        postId: widget.post.id,
        content: content,
        parentCommentId: _replyingTo?.id,
      );

      if (mounted) {
        _commentController.clear();
        _replyingTo = null;
        
        // Reload comments to show the new one
        await _loadComments();
        
        setState(() => _isSubmitting = false);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment posted!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startReply(CommentModel comment) {
    setState(() {
      _replyingTo = comment;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _toggleCommentLike(CommentModel comment) async {
    try {
      if (comment.isLikedByMe) {
        await widget.feedRepository.unlikeComment(comment.id);
      } else {
        await widget.feedRepository.likeComment(comment.id);
      }
      
      // Reload to get updated counts
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Comments list
          Expanded(
            child: _buildCommentsList(),
          ),
          
          // Reply indicator
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Text(
                    'Replying to ${_replyingTo!.userName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _cancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          
          // Comment input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      maxLines: null,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSubmitting
                        ? const SkeletonInline(size: 20)
                        : const Icon(Icons.send),
                    onPressed: _isSubmitting ? null : _submitComment,
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading) {
      return const SkeletonCommentList();
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadComments,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No comments yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to comment!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return _CommentItem(
          comment: comment,
          onLike: () => _toggleCommentLike(comment),
          onReply: () => _startReply(comment),
          feedRepository: widget.feedRepository,
        );
      },
    );
  }
}

/// Individual comment item widget
class _CommentItem extends StatefulWidget {
  final CommentModel comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final FeedRepository feedRepository;

  const _CommentItem({
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.feedRepository,
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  bool _showReplies = false;
  List<CommentModel> _replies = [];
  bool _loadingReplies = false;

  Future<void> _loadReplies() async {
    if (_loadingReplies) return;
    
    setState(() => _loadingReplies = true);

    try {
      final replies = await widget.feedRepository.getCommentReplies(
        commentId: widget.comment.id,
        limit: 20,
      );
      
      if (mounted) {
        setState(() {
          _replies = replies;
          _showReplies = true;
          _loadingReplies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingReplies = false);
      }
    }
  }

  void _toggleReplies() {
    if (_showReplies) {
      setState(() => _showReplies = false);
    } else {
      _loadReplies();
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 7) {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile picture
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.comment.userProfilePictureUrl != null
                    ? NetworkImage(widget.comment.userProfilePictureUrl!)
                    : null,
                child: widget.comment.userProfilePictureUrl == null
                    ? Text(
                        widget.comment.userName[0].toUpperCase(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and time
                    Row(
                      children: [
                        Text(
                          widget.comment.userName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(widget.comment.createdAt),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Comment text
                    Text(
                      widget.comment.content,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    
                    // Actions
                    Row(
                      children: [
                        // Like button
                        InkWell(
                          onTap: widget.onLike,
                          child: Row(
                            children: [
                              Icon(
                                widget.comment.isLikedByMe
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 16,
                                color: widget.comment.isLikedByMe
                                    ? Colors.red
                                    : Colors.grey[600],
                              ),
                              if (widget.comment.likesCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  widget.comment.likesCount.toString(),
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Reply button
                        InkWell(
                          onTap: widget.onReply,
                          child: Text(
                            'Reply',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        
                        // View replies button
                        if (widget.comment.repliesCount > 0) ...[
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: _toggleReplies,
                            child: Row(
                              children: [
                                Icon(
                                  _showReplies
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.comment.repliesCount} ${widget.comment.repliesCount == 1 ? 'reply' : 'replies'}',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Replies
        if (_showReplies && _replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 12),
            child: Column(
              children: _replies.map((reply) {
                return _ReplyItem(
                  reply: reply,
                  feedRepository: widget.feedRepository,
                );
              }).toList(),
            ),
          ),
        
        if (_loadingReplies)
          const Padding(
            padding: EdgeInsets.only(left: 48, bottom: 12),
            child: const SkeletonInline(size: 20),
          ),
      ],
    );
  }
}

/// Reply item (nested comment)
class _ReplyItem extends StatelessWidget {
  final CommentModel reply;
  final FeedRepository feedRepository;

  const _ReplyItem({
    required this.reply,
    required this.feedRepository,
  });

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile picture (smaller)
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.grey[300],
            backgroundImage: reply.userProfilePictureUrl != null
                ? NetworkImage(reply.userProfilePictureUrl!)
                : null,
            child: reply.userProfilePictureUrl == null
                ? Text(
                    reply.userName[0].toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          
          // Reply content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.userName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimestamp(reply.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.content,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
