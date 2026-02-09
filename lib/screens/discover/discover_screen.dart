import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/providers/post_provider.dart';
import 'package:kins_app/repositories/post_repository.dart';

/// Filter topic chips (match create post topics)
const List<String> _filterTopics = [
  'All',
  'IVF',
  'Sleep',
  'Teething',
  'Lorem',
  'Pregnancy',
  'Newborn',
  'Toddler',
];

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTopic = 'All';
  String? _userName;
  String? _userLocation;
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.exists ? doc.data() : null;
      final location = data?['location']?['city'] ?? 'Dubai, UAE';
      final profilePicUrl = data?['profilePictureUrl'] ?? data?['profilePicture'];
      final name = data?['name'] ?? 'User';
      if (mounted) {
        setState(() {
          _userName = name;
          _userLocation = location;
          _profilePictureUrl = profilePicUrl;
        });
      }
    } catch (e) {
      debugPrint('Discover: failed to load user: $e');
    }
  }

  List<PostModel> _filterPosts(List<PostModel> posts) {
    var list = posts;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((p) {
        final text = (p.text ?? '').toLowerCase();
        final author = (p.authorName).toLowerCase();
        return text.contains(query) || author.contains(query);
      }).toList();
    }
    if (_selectedTopic != null && _selectedTopic != 'All') {
      list = list.where((p) => p.topics.contains(_selectedTopic)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final postRepo = ref.watch(postRepositoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterChips(),
            Expanded(
              child: StreamBuilder<List<PostModel>>(
                stream: postRepo.getFeed(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final allPosts = snapshot.data ?? (snapshot.hasError ? <PostModel>[] : <PostModel>[]);
                  final posts = _filterPosts(allPosts);
                  if (posts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.explore_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            allPosts.isEmpty ? 'No posts yet' : 'No matching posts',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            allPosts.isEmpty
                                ? 'Be the first to share something!'
                                : 'Try a different search or topic',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      await postRepo.getFeedOnce();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: posts.length,
                      itemBuilder: (context, index) => _buildPostCardFromModel(posts[index], postRepo),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppConstants.routeCreatePost),
        child: const Icon(Icons.add),
        backgroundColor: const Color(0xFF6A1A5D),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _profilePictureUrl != null
                        ? NetworkImage(_profilePictureUrl!)
                        : null,
                    child: _profilePictureUrl == null
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _userName ?? 'Discover',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _userLocation ?? 'Dubai, UAE',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'kins',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6A1A5D),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
            onPressed: () => context.push(AppConstants.routeNotifications),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _filterTopics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final topic = _filterTopics[index];
          final selected = (_selectedTopic ?? 'All') == topic;
          return FilterChip(
            label: Text(topic),
            selected: selected,
            onSelected: (v) {
              if (v == true) {
                setState(() => _selectedTopic = topic);
              }
            },
            selectedColor: const Color(0xFF6A1A5D).withOpacity(0.3),
            checkmarkColor: const Color(0xFF6A1A5D),
          );
        },
      ),
    );
  }

  Widget _buildDrawer() {
    final authRepository = ref.read(authRepositoryProvider);
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(title: 'Saved Posts', onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(
                      title: 'Account Settings',
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppConstants.routeSettings);
                      },
                    ),
                    _buildDrawerItem(title: 'Terms of Service', onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(title: 'Privacy Policy', onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(title: 'About Us', onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(title: 'Contact Us', onTap: () => Navigator.pop(context)),
                    const Divider(height: 1),
                    _buildDrawerItem(
                      title: 'Log out',
                      isLogout: true,
                      onTap: () async {
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );
                        if (shouldLogout == true && context.mounted) {
                          Navigator.pop(context);
                          try {
                            await authRepository.signOut();
                            if (context.mounted) context.go(AppConstants.routeSplash);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to logout: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? Colors.red : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: isLogout ? Colors.red : Colors.grey.shade400),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(0, Icons.home_outlined, Icons.home, AppConstants.routeHome),
              _buildBottomNavItem(1, Icons.explore_outlined, Icons.explore, AppConstants.routeDiscover),
              _buildBottomNavItem(2, Icons.chat_bubble_outline, Icons.chat_bubble, AppConstants.routeChat),
              _buildBottomNavItem(3, Icons.card_membership_outlined, Icons.card_membership, AppConstants.routeMembership),
              _buildBottomNavItem(4, Icons.shopping_bag_outlined, Icons.shopping_bag, AppConstants.routeMarketplace),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, IconData activeIcon, String route) {
    const int discoverIndex = 1;
    final isActive = index == discoverIndex;
    return GestureDetector(
      onTap: () {
        if (route == AppConstants.routeHome) {
          context.go(AppConstants.routeHome);
        } else if (route != AppConstants.routeDiscover) {
          context.push(route);
        }
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6A1A5D) : Colors.grey.shade200,
          shape: BoxShape.circle,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF6A1A5D).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          isActive ? activeIcon : icon,
          color: isActive ? Colors.white : Colors.black87,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildPostCardFromModel(PostModel post, PostRepository postRepo) {
    if (post.isPoll) return _buildPollCard(post, postRepo);

    final rawMediaUrl = post.mediaUrl;
    final isPdfOrDocument = rawMediaUrl != null &&
        (rawMediaUrl.toLowerCase().endsWith('.pdf') || rawMediaUrl.contains('/documents/'));
    final mediaUrl = (rawMediaUrl != null && rawMediaUrl.isNotEmpty && !isPdfOrDocument)
        ? rawMediaUrl
        : null;
    final hasImage = post.type == PostType.image && mediaUrl != null;
    final hasVideo = post.type == PostType.video && mediaUrl != null;
    final hasMedia = hasImage || hasVideo;

    final rawAvatar = post.authorPhotoUrl;
    final authorAvatar = (rawAvatar != null &&
            rawAvatar.isNotEmpty &&
            !rawAvatar.toLowerCase().endsWith('.pdf') &&
            !rawAvatar.contains('/documents/'))
        ? rawAvatar
        : null;
    final authorName = post.authorName;
    final text = post.text ?? '';
    final likesCount = post.likesCount;
    final commentsCount = post.commentsCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMedia)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: mediaUrl != null && mediaUrl.isNotEmpty
                        ? (mediaUrl.startsWith('assets/')
                            ? Image.asset(
                                mediaUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.image, size: 64, color: Colors.grey)),
                              )
                            : Image.network(
                                mediaUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorBuilder: (_, error, __) {
                                  debugPrint('❌ Feed image load failed: $mediaUrl — $error');
                                  return const Center(
                                    child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                  );
                                },
                              ))
                        : (hasVideo
                            ? const Center(child: Icon(Icons.videocam, size: 64, color: Colors.grey))
                            : const Center(child: Icon(Icons.image, size: 64, color: Colors.grey))),
                  ),
                ),
                if (hasVideo)
                  const Positioned.fill(
                    child: Center(
                      child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white70),
                    ),
                  ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      _buildInteractionButton(
                        Icons.favorite_border,
                        () => _onLikePost(context, post, postRepo),
                      ),
                      const SizedBox(height: 8),
                      _buildInteractionButton(
                        Icons.chat_bubble_outline,
                        () => _onCommentPost(context, post),
                      ),
                      const SizedBox(height: 8),
                      _buildInteractionButton(
                        Icons.share_outlined,
                        () => _onSharePost(context, post),
                      ),
                      const SizedBox(height: 8),
                      _buildInteractionButton(
                        Icons.more_vert,
                        () => _showPostMoreMenu(context, post, postRepo),
                      ),
                    ],
                  ),
                ),
                if (text.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: authorAvatar != null ? NetworkImage(authorAvatar) : null,
                      child: authorAvatar == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                if (text.isNotEmpty && !hasMedia) ...[
                  const SizedBox(height: 8),
                  Text(text, style: const TextStyle(fontSize: 14)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _onLikePost(context, post, postRepo),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('$likesCount', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _onCommentPost(context, post),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('$commentsCount', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollCard(PostModel post, PostRepository postRepo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _PollCardContent(post: post, postRepo: postRepo),
      ),
    );
  }

  Future<void> _onLikePost(BuildContext context, PostModel post, PostRepository postRepo) async {
    try {
      await postRepo.incrementLikes(post.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liked'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not like: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onCommentPost(BuildContext context, PostModel post) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Comments',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'Comments are coming soon. You\'ll be able to reply to this post here.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSharePost(BuildContext context, PostModel post) async {
    final text = post.text?.isNotEmpty == true
        ? post.text!
        : 'Check out this post on Kins!';
    final shareText = '${post.authorName}: $text';
    try {
      await Share.share(
        shareText,
        subject: 'Post from Kins',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: shareText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ),
        );
      }
    }
  }

  void _showPostMoreMenu(BuildContext context, PostModel post, PostRepository postRepo) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(ctx);
                _onReportPost(context, post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(ctx);
                _onSharePost(context, post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Save'),
              onTap: () {
                Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saved to your saved posts')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onReportPost(BuildContext context, PostModel post) async {
    final report = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report post'),
        content: const Text(
          'Are you sure you want to report this post? Our team will review it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (report == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you for helping keep Kins safe.')),
      );
      // TODO: persist report to Firestore reports collection if needed
    }
  }

  Widget _buildInteractionButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _PollCardContent extends ConsumerStatefulWidget {
  final PostModel post;
  final PostRepository postRepo;

  const _PollCardContent({required this.post, required this.postRepo});

  @override
  ConsumerState<_PollCardContent> createState() => _PollCardContentState();
}

class _PollCardContentState extends ConsumerState<_PollCardContent> {
  int? _votedOptionIndex;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _loadVote();
  }

  Future<void> _loadVote() async {
    final userId = currentUserId;
    if (userId.isEmpty) return;
    final option = await widget.postRepo.getUserVote(widget.post.id, userId);
    if (mounted) setState(() => _votedOptionIndex = option);
  }

  Future<void> _vote(int optionIndex) async {
    if (_isVoting || _votedOptionIndex != null) return;
    final userId = currentUserId;
    if (userId.isEmpty) return;
    setState(() => _isVoting = true);
    try {
      await widget.postRepo.votePoll(
        postId: widget.post.id,
        userId: userId,
        optionIndex: optionIndex,
      );
      if (mounted) setState(() => _votedOptionIndex = optionIndex);
    } catch (e) {
      debugPrint('Poll vote error: $e');
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final poll = post.poll;
    if (poll == null) return const SizedBox.shrink();

    final totalVotes = poll.totalVotes;
    final hasVoted = _votedOptionIndex != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 20, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Text(
              post.authorName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          poll.question,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        if (hasVoted)
          ...poll.options.asMap().entries.map((e) {
            final count = e.value.count;
            final pct = totalVotes > 0 ? (count / totalVotes) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.value.text, style: const TextStyle(fontSize: 14)),
                      Text('$count', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6A1A5D)),
                  ),
                ],
              ),
            );
          }),
        if (!hasVoted)
          ...poll.options.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isVoting ? null : () => _vote(e.key),
                  child: Text(e.value.text),
                ),
              ),
            );
          }),
      ],
    );
  }
}
