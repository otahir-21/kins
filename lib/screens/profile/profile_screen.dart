import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/providers/post_provider.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/providers/follow_provider.dart';
import 'package:kins_app/repositories/post_repository.dart';

/// Profile screen: header (avatar, name, description), stats (Followers, Following, Posts, Reposts),
/// tags, posts feed, FAB +, settings icon.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _userName;
  String? _profilePhotoUrl;
  String? _bio;
  List<String> _tags = [];
  int _repostsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    try {
      final userRepo = ref.read(userDetailsRepositoryProvider);
      final user = await userRepo.getUserDetails(uid);
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.exists ? doc.data() : null;
      final interests = data?['interests'] as List<dynamic>?;
      final tagList = interests != null
          ? interests.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : <String>['IVF', 'Working Mum', 'Breastfeeding'];

      if (mounted) {
        setState(() {
          _userName = user?.name ?? data?['name'] ?? 'User';
          _profilePhotoUrl = user?.profilePictureUrl ?? data?['profilePictureUrl']?.toString();
          _bio = user?.bio ?? (data?['bio'] is String ? data!['bio'] as String? : null);
          _tags = tagList;
        });
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) setState(() { _tags = ['IVF', 'Working Mum', 'Breastfeeding']; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserId;
    final postRepo = ref.watch(postRepositoryProvider);
    final followersAsync = ref.watch(myFollowerCountStreamProvider);
    final followingAsync = ref.watch(myFollowingCountStreamProvider);
    final followersCount = followersAsync.valueOrNull ?? 0;
    final followingCount = followingAsync.valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppConstants.routeDiscover),
        ),
        title: const Text('Kins around profile', style: TextStyle(color: Colors.black, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.grey.shade700),
            onPressed: () => context.push(AppConstants.routeSettings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 20),
            StreamBuilder<List<PostModel>>(
              stream: postRepo.getPostsByAuthor(uid),
              builder: (context, postSnapshot) {
                final posts = postSnapshot.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStats(followersCount, followingCount, posts.length),
                    const SizedBox(height: 16),
                    _buildTags(),
                    const SizedBox(height: 24),
                    Text('Posts (${posts.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildPostsContent(postSnapshot, postRepo, uid, posts),
                  ],
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppConstants.routeCreatePost),
        backgroundColor: const Color(0xFF6B4C93),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPostsContent(
    AsyncSnapshot<List<PostModel>> snapshot,
    PostRepository postRepo,
    String uid,
    List<PostModel> posts,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (posts.isEmpty) {
                  return Padding(
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
                  );
                }
    return Column(
      children: posts.map((post) => _buildPostCard(post, postRepo)).toList(),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: const Color(0xFF6B4C93).withOpacity(0.2),
          backgroundImage: _profilePhotoUrl != null ? NetworkImage(_profilePhotoUrl!) : null,
          child: _profilePhotoUrl == null
              ? const Icon(Icons.person, color: Color(0xFF6B4C93), size: 44)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userName ?? 'User',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _bio?.trim().isNotEmpty == true ? _bio! : 'Add a short bio in Edit tags',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(int followersCount, int followingCount, int postsCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statTap('$followersCount', 'Followers', () => context.push(AppConstants.routeFollowers)),
        _statTap('$followingCount', 'Following', () => context.push(AppConstants.routeFollowing)),
        _statTap('$postsCount', 'Posts', null),
        _statTap('$_repostsCount', 'Reposts', null),
      ],
    );
  }

  Widget _statTap(String value, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildTags() {
    return GestureDetector(
      onTap: () async {
        await context.push(AppConstants.routeEditTags);
        if (mounted) _loadUser();
      },
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _tags.map((tag) => Chip(
          label: Text(tag),
          backgroundColor: const Color(0xFF6B4C93).withOpacity(0.15),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        )).toList(),
      ),
    );
  }

  Widget _buildPostCard(PostModel post, PostRepository postRepo) {
    final text = post.text ?? '';
    final mediaUrl = post.mediaUrl;
    final hasMedia = mediaUrl != null && mediaUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMedia)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                mediaUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 220, color: Colors.grey.shade200, child: const Center(child: Icon(Icons.image))),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF6B4C93).withOpacity(0.2),
                      backgroundImage: post.authorPhotoUrl != null ? NetworkImage(post.authorPhotoUrl!) : null,
                      child: post.authorPhotoUrl == null ? const Icon(Icons.person, color: Color(0xFF6B4C93), size: 20) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                  ],
                ),
                if (text.isNotEmpty) ...[const SizedBox(height: 8), Text(text, style: const TextStyle(fontSize: 14))],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.favorite_border, size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${post.likesCount}', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(width: 16),
                    Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${post.commentsCount}', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(width: 16),
                    Icon(Icons.send_outlined, size: 20, color: Colors.grey.shade600),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _onDeletePost(post, postRepo),
                      child: Text('Delete', style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
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

  Future<void> _onDeletePost(PostModel post, PostRepository postRepo) async {
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
      // Use backend API to delete post
      await postRepo.deletePost(post.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')),
        );
        // StreamBuilder will automatically refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}
