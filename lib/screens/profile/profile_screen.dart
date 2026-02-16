import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/providers/feed_provider.dart';
import 'package:kins_app/providers/post_provider.dart';
import 'package:kins_app/repositories/feed_repository.dart';
import 'package:kins_app/repositories/interest_repository.dart';
import 'package:kins_app/screens/comments/comments_bottom_sheet.dart';
import 'package:kins_app/widgets/feed_post_card.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';
import 'package:share_plus/share_plus.dart';

/// Profile screen: centered profile, stats, interest chips, merged posts (originals + reposts).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = true;
  String? _userName;
  String? _profilePhotoUrl;
  String? _bio;
  int _followersCount = 0;
  int _followingCount = 0;
  List<String> _interestNames = [];
  List<_MergedPost> _mergedPosts = [];
  int _repostsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchUser(uid),
        _fetchInterests(uid),
        _fetchPosts(uid),
      ]);
    } catch (e) {
      debugPrint('Profile load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchUser(String uid) async {
    try {
      final me = await BackendApiClient.get('/me');
      final user = me['user'] is Map<String, dynamic> ? me['user'] as Map<String, dynamic> : me;
      if (mounted) {
        setState(() {
          _userName = user['name']?.toString() ?? user['username']?.toString() ?? 'User';
          _profilePhotoUrl = user['profilePictureUrl']?.toString();
          _bio = user['bio']?.toString();
          _followersCount = (user['followerCount'] ?? 0) as int;
          _followingCount = (user['followingCount'] ?? 0) as int;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchInterests(String uid) async {
    try {
      final repo = InterestRepository();
      final allInterests = await repo.getInterests();

      // Try GET /me/interests - backend may return { interests: [{ id, name }, ...] } or { interestIds: [...] }
      final raw = await BackendApiClient.get('/me/interests');
      final list = raw['interests'] ?? raw['interestIds'] ?? raw['data'];
      if (list is List && list.isNotEmpty) {
        final names = <String>[];
        for (final e in list) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e as Map);
            final name = m['name']?.toString();
            if (name != null && name.isNotEmpty) names.add(name);
          } else if (e is String) {
            final match = allInterests.where((i) => i.id == e).firstOrNull;
            if (match != null) names.add(match.name);
          }
        }
        if (mounted) {
          setState(() => _interestNames = names);
          return;
        }
      }

      // Fallback: IDs from getUserInterests + lookup
      final selectedIds = await repo.getUserInterests(uid);
      final names = selectedIds
          .map((id) {
            final match = allInterests.where((i) => i.id == id).firstOrNull;
            return match?.name;
          })
          .whereType<String>()
          .toList();
      if (mounted) setState(() => _interestNames = names);
    } catch (_) {}
  }

  Future<void> _fetchPosts(String uid) async {
    try {
      final feedRepo = ref.read(feedRepositoryProvider);
      // Fetch user posts first; reposts may fail if backend doesn't support the endpoint
      final userPosts = await feedRepo.getMyPosts(page: 1, limit: 50);
      List<PostModel> reposts = [];
      try {
        reposts = await feedRepo.getRepostsByUserId(userId: uid, page: 1, limit: 50);
      } catch (_) {
        debugPrint('⚠️ Skipping reposts (endpoint may not exist)');
      }
      final merged = [
        ...userPosts.map((p) => _MergedPost(post: p, isRepost: false)),
        ...reposts.map((p) => _MergedPost(post: p, isRepost: true)),
      ]..sort((a, b) => b.post.createdAt.compareTo(a.post.createdAt));
      if (mounted) {
        setState(() {
          _mergedPosts = merged;
          _repostsCount = reposts.length;
        });
      }
    } catch (e) {
      debugPrint('Profile _fetchPosts error: $e');
      if (mounted) setState(() => _mergedPosts = []);
    }
  }

  static const Color _bgGrey = Color(0xFFF5F5F5);
  static const Color _textGrey = Color(0xFF8E8E93);
  static const Color _chipBg = Color(0xFFEAEAEA);
  static const Color _borderGrey = Color(0xFFE5E5E5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const SkeletonProfile()
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 10),
                    _buildProfileSection(),
                    const SizedBox(height: 20),
                    _buildName(),
                    const SizedBox(height: 8),
                    _buildBio(),
                    const SizedBox(height: 20),
                    _buildStats(),
                    const SizedBox(height: 15),
                    _buildInterestTags(),
                    const SizedBox(height: 16),
                    _buildPostsSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppConstants.routeCreatePost),
        backgroundColor: const Color(0xFF6B4C93),
        elevation: 2,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go(AppConstants.routeDiscover),
          child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
        ),
        GestureDetector(
          onTap: () async {
            await context.push(AppConstants.routeEditProfile);
            if (mounted) _loadAll();
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(0xffD9D9D9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: const Icon(Icons.edit_outlined, color: Colors.black, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: _profilePhotoUrl != null ? NetworkImage(_profilePhotoUrl!) : null,
          child: _profilePhotoUrl == null
              ? Icon(Icons.person, color: _textGrey, size: 56)
              : null,
        ),
      ),
    );
  }

  Widget _buildName() {
    return Center(
      child: Text(
        _userName ?? 'User',
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBio() {
    final bio = _bio?.trim().isNotEmpty == true ? _bio! : 'No bio';
    return Center(
      child: Text(
        bio,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: _textGrey,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statItem('$_followersCount', 'Followers', () => context.push(AppConstants.routeFollowers)),
        _statItem('$_followingCount', 'Following', () => context.push(AppConstants.routeFollowing)),
        _statItem('${_mergedPosts.where((m) => !m.isRepost).length}', 'Posts', null),
        _statItem('$_repostsCount', 'Reposts', null),
      ],
    );
  }

  Widget _statItem(String number, String label, VoidCallback? onTap) {
    final column = Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: _textGrey,
          ),
        ),
      ],
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: column);
    }
    return column;
  }

  Widget _buildInterestTags() {
    if (_interestNames.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _interestNames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final name = _interestNames[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _borderGrey, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        if (_mergedPosts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.post_add_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No posts yet', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.push(AppConstants.routeCreatePost),
                    icon: const Icon(Icons.add),
                    label: const Text('Create post'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._mergedPosts.map((m) => _buildPostItem(m)),
      ],
    );
  }

  Widget _buildPostItem(_MergedPost merged) {
    final feedRepo = ref.read(feedRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (merged.isRepost)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('Reposted', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
        FeedPostCard(
          post: merged.post,
          feedRepo: feedRepo,
          onComment: (post) => _onComment(post, feedRepo),
          onShare: (post) => _onShare(post, feedRepo),
          onMore: () => _onMore(merged.post, feedRepo),
        ),
      ],
    );
  }

  void _onComment(PostModel post, FeedRepository feedRepo) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsBottomSheet(post: post, feedRepository: feedRepo),
    ).then((_) => _loadAll());
  }

  Future<void> _onShare(PostModel post, FeedRepository feedRepo) async {
    final shareType = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.repeat), title: const Text('Repost to Kins'), onTap: () => Navigator.pop(ctx, 'repost')),
            ListTile(leading: const Icon(Icons.share), title: const Text('Share externally'), onTap: () => Navigator.pop(ctx, 'external')),
            ListTile(leading: const Icon(Icons.link), title: const Text('Copy link'), onTap: () => Navigator.pop(ctx, 'copy')),
          ],
        ),
      ),
    );
    if (shareType == null || !mounted) return;
    try {
      if (shareType == 'copy') {
        final text = post.text?.isNotEmpty == true ? post.text! : 'Check out this post on Kins!';
        await Clipboard.setData(ClipboardData(text: '${post.authorName}: $text'));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
      } else if (shareType == 'external') {
        await feedRepo.sharePost(postId: post.id, shareType: 'external');
        final text = post.text?.isNotEmpty == true ? post.text! : 'Check out this post on Kins!';
        await Share.share('${post.authorName}: $text', subject: 'Post from Kins');
        if (mounted) _loadAll();
      } else if (shareType == 'repost') {
        await feedRepo.sharePost(postId: post.id, shareType: 'repost');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reposted to your feed')));
          _loadAll();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red));
    }
  }

  void _onMore(PostModel post, FeedRepository feedRepo) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text('Delete', style: TextStyle(color: Colors.red.shade700)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(post, feedRepo);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(PostModel post, FeedRepository feedRepo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final postRepo = ref.read(postRepositoryProvider);
      await postRepo.deletePost(post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted')));
        _loadAll();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red));
    }
  }
}

class _MergedPost {
  final PostModel post;
  final bool isRepost;

  _MergedPost({required this.post, required this.isRepost});
}
