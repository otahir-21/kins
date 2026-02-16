import 'package:flutter/material.dart';
import 'package:kins_app/core/theme/app_theme.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/repositories/feed_repository.dart';
import 'package:kins_app/widgets/post_card_text.dart';
import 'package:kins_app/widgets/post_header.dart';
import 'package:kins_app/widgets/post_interaction_bar.dart';
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
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
  }

  @override
  void didUpdateWidget(covariant FeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isLiked = widget.post.isLiked;
      _likesCount = widget.post.likesCount;
    }
  }

  PostModel get _displayPost =>
      widget.post.copyWith(isLiked: _isLiked, likesCount: _likesCount);

  Future<void> _handleLike() async {
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !wasLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    try {
      if (wasLiked) {
        await widget.feedRepo.unlikePost(widget.post.id);
      } else {
        await widget.feedRepo.likePost(widget.post.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likesCount = widget.post.likesCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${wasLiked ? 'unlike' : 'like'} post'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.isPoll) {
      return _PollPostCard(
        post: _displayPost,
        feedRepo: widget.feedRepo,
        onLike: _handleLike,
        onComment: widget.onComment,
        onShare: widget.onShare,
        onMore: widget.onMore,
      );
    }

    final hasMedia = widget.post.type == PostType.image || widget.post.type == PostType.video;
    if (hasMedia) {
      return _MediaPostCard(
        post: _displayPost,
        feedRepo: widget.feedRepo,
        onLike: _handleLike,
        onComment: widget.onComment,
        onShare: widget.onShare,
        onMore: widget.onMore,
      );
    }

    return PostCardText(
      post: _displayPost,
      onLike: _handleLike,
      onComment: widget.onComment,
      onShare: widget.onShare,
      onMore: widget.onMore,
    );
  }
}

class _MediaPostCard extends StatelessWidget {
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

  static String _getTimeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  static String _extractUsername(String authorName) {
    final atIndex = authorName.indexOf('@');
    if (atIndex != -1 && atIndex < authorName.length - 1) return authorName.substring(atIndex);
    return '@${authorName.toLowerCase().replaceAll(' ', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final rawMediaUrl = post.mediaUrl;
    final isPdfOrDocument = rawMediaUrl != null && (rawMediaUrl.toLowerCase().endsWith('.pdf') || rawMediaUrl.contains('/documents/'));
    final mediaUrl = (rawMediaUrl != null && rawMediaUrl.isNotEmpty && !isPdfOrDocument) ? rawMediaUrl : null;
    final hasImage = post.type == PostType.image && mediaUrl != null;
    final text = post.text ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(
            authorName: post.authorName,
            username: _extractUsername(post.authorName),
            timeAgo: _getTimeAgo(post.createdAt),
            avatarUrl: post.authorPhotoUrl,
            onMore: onMore,
          ),
          Transform.translate(
            offset: const Offset(0, -12),
            child: Row(
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
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 6),
                ],
                // InteractionBar
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: PostInteractionBar(
                    post: post,
                    onLike: (_) => onLike(),
                    onComment: onComment,
                    onShare: onShare,
                  ),
                ),
                const SizedBox(height: 6),
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
    ),
  ],
      ),
    );
  }
}

// ---------- Poll Post Card (matches spec exactly) ----------

const Color _pollOptionBg = Color(0xFFE9E9E9);

class _PollPostCard extends StatelessWidget {
  final PostModel post;
  final FeedRepository feedRepo;
  final VoidCallback onLike;
  final void Function(PostModel post) onComment;
  final void Function(PostModel post) onShare;
  final VoidCallback onMore;

  const _PollPostCard({
    required this.post,
    required this.feedRepo,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });

  static String _getTimeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  static String _extractUsername(String authorName) {
    final atIndex = authorName.indexOf('@');
    if (atIndex != -1 && atIndex < authorName.length - 1) return authorName.substring(atIndex);
    return '@${authorName.toLowerCase().replaceAll(' ', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final text = post.text ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(
            authorName: post.authorName,
            username: _extractUsername(post.authorName),
            timeAgo: _getTimeAgo(post.createdAt),
            avatarUrl: post.authorPhotoUrl,
            onMore: onMore,
          ),
          Transform.translate(
            offset: const Offset(0, -12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 52),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (text.isNotEmpty) ...[
                      Text(
                        text,
                        style: Theme.of(context).extension<AppPostTypography>()?.pollQuestion ??
                            const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4, color: Colors.black),
                      ),
                      const SizedBox(height: 9),
                    ],
                    _PollOptionsContent(
                      post: post,
                      feedRepo: feedRepo,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: PostInteractionBar(
                        post: post,
                        onLike: (_) => onLike(),
                        onComment: onComment,
                        onShare: onShare,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Divider(
                      height: 1,
                      thickness: 0.8,
                      color: Color(0xFFE5E5E5),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
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
  bool _isVoting = false;
  PollData? _updatedPollData; // After user votes, hold response poll data
  int? _selectedOptionIndex; // Which option user voted for (for check icon)

  /// Read from post.userVote and post.pollResults - no API call.
  bool get _hasVoted => _selectedOptionIndex != null || widget.post.userVote != null;

  int? get _effectiveSelectedIndex => _selectedOptionIndex ?? widget.post.userVote;

  /// Effective poll data: from API response after vote, or built from post.pollResults / post.poll
  PollData get _effectivePoll {
    if (_updatedPollData != null) return _updatedPollData!;
    final post = widget.post;
    final poll = post.poll;
    if (post.pollResults != null && post.pollResults!.isNotEmpty) {
      final options = post.pollResults!
          .map((r) => PollOption(text: r.text, index: r.index, count: r.votes))
          .toList();
      final totalVotes = options.fold<int>(0, (s, o) => s + o.count);
      return PollData(
        question: poll?.question ?? '',
        options: options,
        totalVotes: totalVotes,
      );
    }
    return poll ?? PollData(question: '', options: [], totalVotes: 0);
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
        setState(() { _selectedOptionIndex = optionIndex; _isVoting = false; });
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
    final poll = _effectivePoll;
    if (poll.options.isEmpty) return const SizedBox.shrink();
    final total = (poll.totalVotes > 0 ? poll.totalVotes : 1).toDouble();

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
              isSelected: _effectiveSelectedIndex == entry.key,
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
