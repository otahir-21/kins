import 'package:flutter/material.dart';
import 'package:kins_app/core/theme/app_theme.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/repositories/feed_repository.dart';
import 'package:kins_app/widgets/post_card_text.dart';
import 'package:kins_app/widgets/post_header.dart';
import 'package:kins_app/widgets/post_interaction_bar.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

/// Reusable feed post card - text, image/video, or poll.
/// Used by Discover and Profile screens.
class FeedPostCard extends StatefulWidget {
  final PostModel post;
  final FeedRepository feedRepo;
  final void Function(PostModel post) onComment;
  final void Function(PostModel post) onShare;
  final VoidCallback onMore;

  const FeedPostCard({
    super.key,
    required this.post,
    required this.feedRepo,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  bool _isLiked = false;
  bool _isCheckingLike = true;

  @override
  void initState() {
    super.initState();
    _checkLikeStatus();
  }

  Future<void> _checkLikeStatus() async {
    try {
      final isLiked = await widget.feedRepo.getLikeStatus(widget.post.id);
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
          _isCheckingLike = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isCheckingLike = false);
    }
  }

  Future<void> _handleLike() async {
    final wasLiked = _isLiked;
    setState(() => _isLiked = !wasLiked);
    try {
      if (wasLiked) {
        await widget.feedRepo.unlikePost(widget.post.id);
      } else {
        await widget.feedRepo.likePost(widget.post.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLiked = wasLiked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${wasLiked ? 'unlike' : 'like'} post'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingLike) return const SkeletonPostCardPlaceholder();

    if (widget.post.isPoll) {
      return _PollPostCard(
        post: widget.post,
        feedRepo: widget.feedRepo,
        isLiked: _isLiked,
        onLike: _handleLike,
        onComment: widget.onComment,
        onShare: widget.onShare,
        onMore: widget.onMore,
      );
    }

    final hasMedia = widget.post.type == PostType.image || widget.post.type == PostType.video;
    if (hasMedia) {
      return _MediaPostCard(
        post: widget.post,
        feedRepo: widget.feedRepo,
        onLike: _handleLike,
        onComment: widget.onComment,
        onShare: widget.onShare,
        onMore: widget.onMore,
      );
    }

    return PostCardText(
      post: widget.post,
      isLiked: _isLiked,
      onLike: _handleLike,
      onComment: widget.onComment,
      onShare: widget.onShare,
      onMore: widget.onMore,
    );
  }
}

class _MediaPostCard extends StatefulWidget {
  final PostModel post;
  final FeedRepository feedRepo;
  final VoidCallback onLike;
  final void Function(PostModel post) onComment;
  final void Function(PostModel post) onShare;
  final VoidCallback onMore;

  const _MediaPostCard({
    required this.post,
    required this.feedRepo,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });

  @override
  State<_MediaPostCard> createState() => _MediaPostCardState();
}

class _MediaPostCardState extends State<_MediaPostCard> {
  bool? _isLiked;
  int? _localLikesCount;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _checkLikeStatus();
  }

  Future<void> _checkLikeStatus() async {
    try {
      final isLiked = await widget.feedRepo.getLikeStatus(widget.post.id);
      if (mounted) setState(() => _isLiked = isLiked);
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);
    final wasLiked = _isLiked ?? false;
    final currentCount = _localLikesCount ?? widget.post.likesCount;
    setState(() {
      _isLiked = !wasLiked;
      _localLikesCount = wasLiked ? currentCount - 1 : currentCount + 1;
    });
    try {
      if (wasLiked) {
        await widget.feedRepo.unlikePost(widget.post.id);
      } else {
        await widget.feedRepo.likePost(widget.post.id);
      }
      if (mounted) setState(() => _isLiking = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _localLikesCount = currentCount;
          _isLiking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to ${wasLiked ? 'unlike' : 'like'} post'), backgroundColor: Colors.red));
      }
    }
  }

  String _getTimeAgo() {
    final diff = DateTime.now().difference(widget.post.createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  String _extractUsername() {
    final name = widget.post.authorName;
    final atIndex = name.indexOf('@');
    if (atIndex != -1 && atIndex < name.length - 1) return name.substring(atIndex);
    return '@${name.toLowerCase().replaceAll(' ', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final rawMediaUrl = widget.post.mediaUrl;
    final isPdfOrDocument = rawMediaUrl != null && (rawMediaUrl.toLowerCase().endsWith('.pdf') || rawMediaUrl.contains('/documents/'));
    final mediaUrl = (rawMediaUrl != null && rawMediaUrl.isNotEmpty && !isPdfOrDocument) ? rawMediaUrl : null;
    final hasImage = widget.post.type == PostType.image && mediaUrl != null;
    final text = widget.post.text ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(
            authorName: widget.post.authorName,
            username: _extractUsername(),
            timeAgo: _getTimeAgo(),
            avatarUrl: widget.post.authorPhotoUrl,
            onMore: widget.onMore,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 52),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text
                if (text.isNotEmpty) ...[
                  Text(
                    text,
                    style: Theme.of(context).extension<AppPostTypography>()?.postBodySmall ??
                        const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.4, color: Colors.black),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],
                // Image
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        mediaUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Icon(Icons.broken_image, size: 48, color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // InteractionBar
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: PostInteractionBar(
                    post: widget.post,
                    initialIsLiked: _isLiked ?? false,
                    onLike: (_) => _toggleLike(),
                    onComment: widget.onComment,
                    onShare: widget.onShare,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(
                  height: 1,
                  thickness: 0.8,
                  color: Color(0xFFE5E5E5),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    ],
  ),
);
  }
}

// ---------- Poll Post Card (matches spec exactly) ----------

const Color _pollOptionBg = Color(0xFFE9E9E9);

class _PollPostCard extends StatefulWidget {
  final PostModel post;
  final FeedRepository feedRepo;
  final bool isLiked;
  final VoidCallback onLike;
  final void Function(PostModel post) onComment;
  final void Function(PostModel post) onShare;
  final VoidCallback onMore;

  const _PollPostCard({
    required this.post,
    required this.feedRepo,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });

  @override
  State<_PollPostCard> createState() => _PollPostCardState();
}

class _PollPostCardState extends State<_PollPostCard> {
  String _getTimeAgo() {
    final diff = DateTime.now().difference(widget.post.createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  String _extractUsername() {
    final name = widget.post.authorName;
    final atIndex = name.indexOf('@');
    if (atIndex != -1 && atIndex < name.length - 1) return name.substring(atIndex);
    return '@${name.toLowerCase().replaceAll(' ', '')}';
  }

  void _handleLike() => widget.onLike();

  @override
  Widget build(BuildContext context) {
    final text = widget.post.text ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(
          authorName: widget.post.authorName,
          username: _extractUsername(),
          timeAgo: _getTimeAgo(),
          avatarUrl: widget.post.authorPhotoUrl,
          onMore: widget.onMore,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 52),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// POST TEXT
              if (text.isNotEmpty) ...[
                Text(
                  text,
                  style: Theme.of(context).extension<AppPostTypography>()?.pollQuestion ??
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4, color: Colors.black),
                ),
                const SizedBox(height: 18),
              ],

              /// POLL
              _PollOptionsContent(
                post: widget.post,
                feedRepo: widget.feedRepo,
              ),

              const SizedBox(height: 8),



              /// ENGAGEMENT
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: PostInteractionBar(
                  post: widget.post,
                  initialIsLiked: widget.isLiked,
                  onLike: (_) => _handleLike(),
                  onComment: widget.onComment,
                  onShare: widget.onShare,
                ),
              ),

              const SizedBox(height: 12),

              /// DIVIDER
              const Divider(
                height: 1,
                thickness: 0.8,
                color: Color(0xFFE5E5E5),
              ),
              const SizedBox(height: 12),

                ],
              ),
            ),
          ],
        ),
      ],
    ),
    );
  }
}

class _PollOptionsContent extends StatefulWidget {
  final PostModel post;
  final FeedRepository feedRepo;

  const _PollOptionsContent({required this.post, required this.feedRepo});

  @override
  State<_PollOptionsContent> createState() => _PollOptionsContentState();
}

class _PollOptionsContentState extends State<_PollOptionsContent> {
  bool _hasVoted = false;
  bool _isVoting = false;
  bool _isLoadingResults = true;
  PollData? _updatedPollData;
  int? _selectedOptionIndex; // Which option user voted for (for check icon)

  @override
  void initState() {
    super.initState();
    _loadPollResults();
  }

  Future<void> _loadPollResults() async {
    try {
      setState(() => _isLoadingResults = true);
      final poll = widget.post.poll;
      if (poll != null && poll.votedUsers.isNotEmpty) {
        final userId = StorageService.getString(AppConstants.keyUserId);
        final hasVoted = userId != null && poll.votedUsers.contains(userId);
        if (mounted) setState(() { _hasVoted = hasVoted; _isLoadingResults = false; });
        return;
      }
      try {
        final pollData = await widget.feedRepo.getPollResults(widget.post.id);
        if (mounted && pollData != null) {
          final userVoted = pollData['userVoted'] == true;
          if (userVoted) {
            final optionsList = (pollData['options'] as List<dynamic>?) ?? [];
            final options = optionsList.asMap().entries.map((entry) {
              final opt = entry.value as Map<String, dynamic>;
              return PollOption(text: opt['text']?.toString() ?? '', index: entry.key, count: (opt['votes'] ?? 0) as int);
            }).toList();
            _updatedPollData = PollData(question: pollData['question']?.toString() ?? widget.post.poll?.question ?? '', options: options, totalVotes: (pollData['totalVotes'] ?? 0) as int);
          }
          setState(() { _hasVoted = userVoted; _isLoadingResults = false; });
        } else if (mounted) {
          setState(() => _isLoadingResults = false);
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingResults = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingResults = false);
    }
  }

  Future<void> _vote(int optionIndex) async {
    if (_isVoting || _hasVoted) return;
    setState(() => _isVoting = true);
    try {
      final response = await widget.feedRepo.votePoll(postId: widget.post.id, optionIndex: optionIndex);
      final pollDataFromResponse = response['poll'] as Map<String, dynamic>?;
      if (pollDataFromResponse != null) {
        final optionsList = (pollDataFromResponse['options'] as List<dynamic>?) ?? [];
        final options = optionsList.asMap().entries.map((entry) {
          final opt = entry.value as Map<String, dynamic>;
          return PollOption(text: opt['text']?.toString() ?? '', index: (opt['index'] ?? entry.key) as int, count: (opt['votes'] ?? 0) as int);
        }).toList();
        _updatedPollData = PollData(question: pollDataFromResponse['question']?.toString() ?? widget.post.poll?.question ?? '', options: options, totalVotes: (pollDataFromResponse['totalVotes'] ?? 0) as int);
      }
      if (mounted) {
        setState(() { _hasVoted = true; _selectedOptionIndex = optionIndex; _isVoting = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vote recorded!'), duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVoting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().contains('Already voted') ? 'You have already voted' : 'Failed to vote'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = _updatedPollData ?? widget.post.poll;
    if (poll == null) return const SizedBox.shrink();
    final total = (poll.totalVotes > 0 ? poll.totalVotes : 1).toDouble();

    if (_isLoadingResults) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (poll.question.trim().isNotEmpty) ...[
          Text(
            poll.question,
            style: Theme.of(context).extension<AppPostTypography>()?.pollQuestion ??
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4, color: Colors.black),
          ),
          const SizedBox(height: 14),
        ],
        ...poll.options.asMap().entries.map((entry) => _PollOptionRow(
              option: entry.value,
              total: total,
              hasVoted: _hasVoted,
              isSelected: _selectedOptionIndex == entry.key,
              onTap: _hasVoted ? null : () => _vote(entry.key),
            )),
      ],
    );
  }
}

class _PollOptionRow extends StatefulWidget {
  final PollOption option;
  final double total;
  final bool hasVoted;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PollOptionRow({
    required this.option,
    required this.total,
    required this.hasVoted,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<_PollOptionRow> createState() => _PollOptionRowState();
}

class _PollOptionRowState extends State<_PollOptionRow> with SingleTickerProviderStateMixin {
  late AnimationController _fillController;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    final pct = widget.total > 0 ? widget.option.count / widget.total : 0.0;
    _fillAnimation = Tween<double>(begin: 0, end: pct).animate(CurvedAnimation(parent: _fillController, curve: Curves.easeOut));
    if (widget.hasVoted) _fillController.forward();
  }

  @override
  void didUpdateWidget(covariant _PollOptionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasVoted && !_fillController.isAnimating && !_fillController.isCompleted) {
      _fillController.forward();
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.total > 0 ? (widget.option.count / widget.total) * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: widget.hasVoted ? _buildVotedState() : _buildNotVotedState(),
              ),
            ),
            if (widget.hasVoted) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                child: Center(
                  child: Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: Theme.of(context).extension<AppPostTypography>()?.pollOption ??
                        const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// STATE 1: User has NOT voted - transparent bg, border only, no fill/percentage/check
  Widget _buildNotVotedState() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        widget.option.text,
        style: Theme.of(context).extension<AppPostTypography>()?.pollOption ??
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// STATE 2: User HAS voted - pill with fill bar, check icon if selected
  /// Fill bar width = vote percentage (12% votes → 12% fill; 100% → full)
  Widget _buildVotedState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Background pill (light grey)
            Container(
              height: 44,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _pollOptionBg,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            // Fill bar (darker grey) - width matches vote %
            AnimatedBuilder(
              animation: _fillAnimation,
              builder: (_, __) {
                final w = constraints.maxWidth * _fillAnimation.value.clamp(0.0, 1.0);
                final full = _fillAnimation.value >= 0.999;
                return Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6D6D6),
                      borderRadius: full
                          ? BorderRadius.circular(22)
                          : const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              bottomLeft: Radius.circular(22),
                            ),
                    ),
                  ),
                );
              },
            ),
            // Text + check icon overlay - left-aligned, clipped within gray bg
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.option.text,
                        style: Theme.of(context).extension<AppPostTypography>()?.pollOption ??
                            const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isSelected)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check, size: 18, color: Colors.black),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
