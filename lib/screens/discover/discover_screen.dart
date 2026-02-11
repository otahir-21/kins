import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/models/interest_model.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/providers/feed_provider.dart';
import 'package:kins_app/providers/interest_provider.dart';
import 'package:kins_app/providers/post_provider.dart';
import 'package:kins_app/repositories/feed_repository.dart';
import 'package:kins_app/services/account_deletion_service.dart';
import 'package:kins_app/services/backend_auth_service.dart';
import 'package:kins_app/widgets/floating_nav_overlay.dart';
import 'package:kins_app/screens/comments/comments_bottom_sheet.dart';
import 'package:kins_app/widgets/post_card_text.dart';


class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _selectedInterestId; // null means 'All'
  String? _userName;
  String? _userLocation;
  String? _profilePictureUrl;
  
  // Feed state (backend API, no Firebase)
  List<PostModel> _allPosts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  // Interests from MongoDB
  List<InterestModel> _allInterests = [];
  Set<String> _userInterestIds = {};
  bool _loadingInterests = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
    _loadInterests();
    _loadFeed(isRefresh: true); // Load with refresh to include user's own posts
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh feed when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _loadFeed(isRefresh: true);
    }
  }

  /// Load user profile from backend /me API
  Future<void> _loadUserProfile() async {
    try {
      final response = await BackendAuthService.getProfileStatus();
      if (!mounted || !response.exists) return;
      
      // Get full user details from /me API
      final me = await BackendApiClient.get('/me');
      final user = me['user'] is Map<String, dynamic> 
          ? me['user'] as Map<String, dynamic> 
          : me;
      
      if (mounted) {
        setState(() {
          _userName = user['name']?.toString() ?? user['username']?.toString() ?? 'User';
          _userLocation = 'Dubai, UAE'; // Can be extracted from user data if available
          _profilePictureUrl = user['profilePictureUrl']?.toString();
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load user profile: $e');
    }
  }

  /// Load all interests and user's interests from MongoDB backend
  Future<void> _loadInterests() async {
    try {
      final uid = currentUserId;
      final interestRepo = ref.read(interestRepositoryProvider);
      
      // Load all interests
      final interests = await interestRepo.getInterests();
      
      // Load user's interests
      Set<String> userInterests = {};
      if (uid.isNotEmpty) {
        final userInterestsList = await interestRepo.getUserInterests(uid);
        userInterests = userInterestsList.toSet();
      }
      
      if (mounted) {
        setState(() {
          _allInterests = interests;
          _userInterestIds = userInterests;
          _loadingInterests = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load interests: $e');
      if (mounted) {
        setState(() {
          _loadingInterests = false;
        });
      }
    }
  }

  /// Load feed from backend API
  /// Also loads user's own posts and merges them into the feed
  Future<void> _loadFeed({bool isRefresh = false}) async {
    if (_isLoading || _isLoadingMore) return;
    
    setState(() {
      if (isRefresh) {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
        _error = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final feedRepo = ref.read(feedRepositoryProvider);
      
      // Fetch both main feed and user's own posts
      final feedPosts = await feedRepo.getFeed(
        page: isRefresh ? 1 : _currentPage,
        limit: 20,
      );
      
      // On refresh or initial load, also get user's own posts (first page only)
      List<PostModel> myPosts = [];
      if (isRefresh || _currentPage == 1) {
        try {
          myPosts = await feedRepo.getMyPosts(page: 1, limit: 20);
          debugPrint('✅ Loaded ${myPosts.length} of my posts to merge with feed');
        } catch (e) {
          debugPrint('⚠️ Failed to load my posts: $e');
        }
      }
      
      // Merge and sort by date (most recent first)
      List<PostModel> allPosts = [...feedPosts, ...myPosts];
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Debug: Print all posts
      debugPrint('📋 ========== ALL POSTS (${allPosts.length}) ==========');
      for (var post in allPosts) {
        debugPrint('  📄 ID: ${post.id}');
        debugPrint('     Type: ${post.type.name}');
        debugPrint('     Author: ${post.authorName}');
        debugPrint('     Content: ${post.text?.substring(0, post.text!.length > 50 ? 50 : post.text!.length) ?? "N/A"}');
        debugPrint('     Media: ${post.mediaUrl ?? "N/A"}');
        debugPrint('     ---');
      }
      debugPrint('📋 ========================================');

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _allPosts = allPosts;
            _currentPage = 1;
          } else {
            _allPosts.addAll(feedPosts);
          }
          _hasMore = feedPosts.length >= 20;
          _isLoading = false;
          _isLoadingMore = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load feed: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  /// Load more posts (pagination)
  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    
    setState(() {
      _currentPage++;
    });
    
    await _loadFeed();
  }

  /// Handle scroll for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// Filter posts by search and interest
  List<PostModel> _filterPosts(List<PostModel> posts) {
    var list = posts;
    
    // Filter by search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((p) {
        final text = (p.text ?? '').toLowerCase();
        final author = (p.authorName).toLowerCase();
        return text.contains(query) || author.contains(query);
      }).toList();
    }
    
    // Filter by selected interest
    if (_selectedInterestId != null) {
      list = list.where((p) => p.topics.contains(_selectedInterestId)).toList();
    }
    
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final feedRepo = ref.watch(feedRepositoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      body: FloatingNavOverlay(
        currentIndex: 0,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildFilterChips(),
              Expanded(
                child: _buildFeedContent(feedRepo),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push(AppConstants.routeCreatePost);
          // Refresh feed if post was created successfully
          if (result == true && mounted) {
            _loadFeed(isRefresh: true);
          }
        },
        backgroundColor: const Color(0xFF6A1A5D),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: const _DiscoverFabLocation(),
    );
  }

  /// Build feed content with loading, error, and empty states
  Widget _buildFeedContent(FeedRepository feedRepo) {
    // Show loading on first load
    if (_isLoading && _allPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show error state
    if (_error != null && _allPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Failed to load feed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!.length > 100 ? 'Please try again' : _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadFeed(isRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final posts = _filterPosts(_allPosts);

    // Show empty state
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _allPosts.isEmpty ? 'No posts yet' : 'No matching posts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _allPosts.isEmpty
                  ? 'Be the first to share something!'
                  : 'Try a different search or topic',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // Show feed with pull-to-refresh and pagination
    return RefreshIndicator(
      onRefresh: () => _loadFeed(isRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: posts.length + (_hasMore ? 1 : 0),
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          if (index >= posts.length) {
            // Loading indicator at bottom
            return _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          return _buildPostCardFromModel(posts[index], feedRepo);
        },
        cacheExtent: 1000, // Optimize scroll performance
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: Colors.white,
      child: Builder(
        builder: (context) => Row(
          children: [
            // Drawer/Menu Button
            IconButton(
              icon: Icon(Icons.menu, color: Colors.grey.shade700, size: 24),
              onPressed: () => Scaffold.of(context).openDrawer(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _profilePictureUrl != null
                ? NetworkImage(_profilePictureUrl!)
                : null,
            child: _profilePictureUrl == null
                ? Icon(Icons.person, size: 20, color: Colors.grey.shade400)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _userName ?? 'Discover',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _userLocation ?? 'Dubai, UAE',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'kins',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6A1A5D),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.grey.shade700, size: 24),
            onPressed: () => context.push(AppConstants.routeNotifications),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade400,
          ),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          filled: true,
          fillColor: const Color(0xFFF5F5F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    if (_loadingInterests) {
      return Container(
        height: 40,
        margin: const EdgeInsets.only(bottom: 8),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Sort interests: user's interests first, then alphabetically
    final sortedInterests = [..._allInterests];
    sortedInterests.sort((a, b) {
      final aIsUserInterest = _userInterestIds.contains(a.id);
      final bIsUserInterest = _userInterestIds.contains(b.id);
      
      if (aIsUserInterest && !bIsUserInterest) return -1;
      if (!aIsUserInterest && bIsUserInterest) return 1;
      return a.name.compareTo(b.name);
    });

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: sortedInterests.length + 1, // +1 for "All"
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" filter chip
            final selected = _selectedInterestId == null;
            return GestureDetector(
              onTap: () => setState(() => _selectedInterestId = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF6A1A5D).withOpacity(0.08) : Colors.white,
                  border: Border.all(
                    color: selected ? const Color(0xFF6A1A5D).withOpacity(0.3) : Colors.grey.shade200,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child:                   Text(
                    'All',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? const Color(0xFF6A1A5D) : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            );
          }

          final interest = sortedInterests[index - 1];
          final selected = _selectedInterestId == interest.id;
          final isUserInterest = _userInterestIds.contains(interest.id);

          return GestureDetector(
            onTap: () => setState(() => _selectedInterestId = interest.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected 
                    ? const Color(0xFF6A1A5D).withOpacity(0.08)
                    : (isUserInterest ? const Color(0xFF6A1A5D).withOpacity(0.02) : Colors.white),
                border: Border.all(
                  color: selected 
                      ? const Color(0xFF6A1A5D).withOpacity(0.3)
                      : (isUserInterest ? const Color(0xFF6A1A5D).withOpacity(0.15) : Colors.grey.shade200),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUserInterest) ...[
                    Icon(
                      Icons.star,
                      size: 14,
                      color: selected ? const Color(0xFF6A1A5D) : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    interest.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? const Color(0xFF6A1A5D) : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer() {
    final uid = currentUserId;
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
                      title: 'Delete account',
                      isDestructive: true,
                      onTap: () async {
                        Navigator.pop(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete account'),
                            content: const Text(
                              'This will permanently delete your account and all your data from our servers. This action cannot be undone.\n\nAre you sure you want to continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Delete account'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !context.mounted) return;
                        try {
                          final service = AccountDeletionService();
                          await service.deleteAccount(
                            userId: uid,
                            authRepository: authRepository,
                          );
                          if (context.mounted) context.go(AppConstants.routeSplash);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete account: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
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
    bool isDestructive = false,
  }) {
    final useRed = isLogout || isDestructive;
    return ListTile(
      title:       Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: useRed ? Colors.red : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: useRed ? Colors.red : Colors.grey.shade400),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
    );
  }


  Widget _buildPostCardFromModel(PostModel post, FeedRepository feedRepo) {
    Widget postWidget;
    
    if (post.isPoll) {
      postWidget = _buildPollCard(post, feedRepo);
    } else {
      postWidget = _PostCardWrapper(
        key: ValueKey(post.id),
        post: post,
        feedRepo: feedRepo,
        onComment: () => _onCommentPost(context, post, feedRepo),
        onShare: () => _onSharePost(context, post, feedRepo),
        onMore: () => _showPostMoreMenu(context, post, feedRepo),
      );
    }
    
    // Add divider after each post
    return Column(
      children: [
        postWidget,
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey.shade200,
        ),
      ],
    );
  }

  Widget _buildPollCard(PostModel post, FeedRepository feedRepo) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: _PollCardContent(post: post, feedRepo: feedRepo),
    );
  }

  Future<void> _onLikePost(BuildContext context, PostModel post, FeedRepository feedRepo) async {
    try {
      await feedRepo.likePost(post.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liked'), duration: Duration(seconds: 1)),
        );
      }
      // Refresh feed to show updated like count
      _loadFeed(isRefresh: true);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not like: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onCommentPost(BuildContext context, PostModel post, FeedRepository feedRepo) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsBottomSheet(
        post: post,
        feedRepository: feedRepo,
      ),
    ).then((_) {
      // Refresh feed to show updated comment counts
      _loadFeed(isRefresh: true);
    });
  }

  Future<void> _onSharePost(BuildContext context, PostModel post, FeedRepository feedRepo) async {
    // Show share options dialog
    final shareType = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Repost to Kins'),
              onTap: () => Navigator.pop(ctx, 'repost'),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share externally'),
              onTap: () => Navigator.pop(ctx, 'external'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
          ],
        ),
      ),
    );

    if (shareType == null || !context.mounted) return;

    try {
      if (shareType == 'copy') {
        // Just copy to clipboard (no API call)
        final text = post.text?.isNotEmpty == true
            ? post.text!
            : 'Check out this post on Kins!';
        final shareText = '${post.authorName}: $text';
        await Clipboard.setData(ClipboardData(text: shareText));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        }
      } else if (shareType == 'external') {
        // Track share in backend
        await feedRepo.sharePost(postId: post.id, shareType: 'external');
        
        // Use share_plus to share externally
        final text = post.text?.isNotEmpty == true
            ? post.text!
            : 'Check out this post on Kins!';
        final shareText = '${post.authorName}: $text';
        await Share.share(shareText, subject: 'Post from Kins');
        
        // Refresh feed to show updated share count
        _loadFeed(isRefresh: true);
      } else if (shareType == 'repost') {
        // Track repost in backend
        await feedRepo.sharePost(postId: post.id, shareType: 'repost');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reposted to your feed')),
          );
        }
        
        // Refresh feed to show updated share count
        _loadFeed(isRefresh: true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMyPosts() async {
    try {
      final feedRepo = ref.read(feedRepositoryProvider);
      final myPosts = await feedRepo.getMyPosts(page: 1, limit: 20);
      
      if (!mounted) return;
      
      if (myPosts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You haven\'t created any posts yet')),
        );
        return;
      }
      
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
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
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'My Posts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${myPosts.length} posts',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Posts list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: myPosts.length,
                  itemBuilder: (context, index) {
                    return _buildPostCardFromModel(myPosts[index], feedRepo);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: $e')),
        );
      }
    }
  }

  void _showPostMoreMenu(BuildContext context, PostModel post, FeedRepository feedRepo) {
    final uid = currentUserId;
    final isOwnPost = post.authorId == uid;
    
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag indicator
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              
              // Delete option (only for own posts)
              if (isOwnPost)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.black),
                  title: const Text('Delete', style: TextStyle(color: Colors.black)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onDeletePost(context, post);
                  },
                ),
              
              // Save option
              ListTile(
                leading: const Icon(Icons.bookmark_outline, color: Colors.black),
                title: const Text('Save', style: TextStyle(color: Colors.black)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved to your saved posts')),
                    );
                  }
                },
              ),
              
              // Report option
              ListTile(
                leading: Icon(Icons.outlined_flag, color: Colors.red.shade600),
                title: Text('Report', style: TextStyle(color: Colors.red.shade600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _onReportPost(context, post);
                },
              ),
              
              const SizedBox(height: 8),
            ],
          ),
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

  Future<void> _onDeletePost(BuildContext context, PostModel post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm != true || !context.mounted) return;
    
    try {
      final postRepo = ref.read(postRepositoryProvider);
      await postRepo.deletePost(post.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')),
        );
        // Remove from local list and refresh feed
        setState(() {
          _allPosts.removeWhere((p) => p.id == post.id);
        });
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

/// Wrapper for PostCardText that manages like state
class _PostCardWrapper extends StatefulWidget {
  final PostModel post;
  final FeedRepository feedRepo;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMore;

  const _PostCardWrapper({
    super.key,
    required this.post,
    required this.feedRepo,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });

  @override
  State<_PostCardWrapper> createState() => _PostCardWrapperState();
}

class _PostCardWrapperState extends State<_PostCardWrapper> {
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
      debugPrint('❌ Failed to check like status: $e');
      if (mounted) {
        setState(() => _isCheckingLike = false);
      }
    }
  }

  Future<void> _handleLike() async {
    final wasLiked = _isLiked;

    // Optimistic update
    setState(() => _isLiked = !wasLiked);

    try {
      if (wasLiked) {
        await widget.feedRepo.unlikePost(widget.post.id);
      } else {
        await widget.feedRepo.likePost(widget.post.id);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() => _isLiked = wasLiked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${wasLiked ? 'unlike' : 'like'} post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingLike) {
      // Show placeholder while checking like status
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Use PostCardText for text-only posts, _PostCard for image/video posts
    final hasMedia = widget.post.type == PostType.image || widget.post.type == PostType.video;
    
    if (hasMedia) {
      // Use the old _PostCard widget which has image/video support
      return _PostCard(
        post: widget.post,
        feedRepo: widget.feedRepo,
        onLike: _handleLike,
        onComment: widget.onComment,
        onShare: widget.onShare,
        onMore: widget.onMore,
      );
    }

    // Use PostCardText for text posts (matches Figma design)
    return PostCardText(
      post: widget.post,
      isLiked: _isLiked,
      onLike: _handleLike,
      onComment: widget.onComment,
      onRepost: widget.onShare,
      onMore: widget.onMore,
    );
  }
}

/// Old post card widget - DEPRECATED, kept for reference
class _PostCard extends StatefulWidget {
  final PostModel post;
  final FeedRepository feedRepo;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMore;

  const _PostCard({
    super.key,
    required this.post,
    required this.feedRepo,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with SingleTickerProviderStateMixin {
  bool? _isLiked;
  int? _localLikesCount;
  bool _isLiking = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _likeScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _likeAnimationController, curve: Curves.easeInOut),
    );
    _checkLikeStatus();
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkLikeStatus() async {
    try {
      final isLiked = await widget.feedRepo.getLikeStatus(widget.post.id);
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to check like status: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    // Animate like button
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });

    setState(() => _isLiking = true);

    final wasLiked = _isLiked ?? false;
    final currentCount = _localLikesCount ?? widget.post.likesCount;

    // Optimistic update
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
      
      if (mounted) {
        setState(() => _isLiking = false);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _localLikesCount = currentCount;
          _isLiking = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${wasLiked ? 'unlike' : 'like'} post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final postTime = widget.post.createdAt;
    final diff = now.difference(postTime);
    
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  String _extractUsername() {
    // Extract username from author name (e.g., "Jawaher @jawaherabdelhamid")
    final name = widget.post.authorName;
    final atIndex = name.indexOf('@');
    if (atIndex != -1 && atIndex < name.length - 1) {
      return name.substring(atIndex);
    }
    return '@${name.toLowerCase().replaceAll(' ', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final rawMediaUrl = widget.post.mediaUrl;
    final isPdfOrDocument = rawMediaUrl != null &&
        (rawMediaUrl.toLowerCase().endsWith('.pdf') || rawMediaUrl.contains('/documents/'));
    final mediaUrl = (rawMediaUrl != null && rawMediaUrl.isNotEmpty && !isPdfOrDocument)
        ? rawMediaUrl
        : null;
    final hasImage = widget.post.type == PostType.image && mediaUrl != null;
    final hasVideo = widget.post.type == PostType.video && mediaUrl != null;
    final hasMedia = hasImage || hasVideo;

    final rawAvatar = widget.post.authorPhotoUrl;
    final authorAvatar = (rawAvatar != null &&
            rawAvatar.isNotEmpty &&
            !rawAvatar.toLowerCase().endsWith('.pdf') &&
            !rawAvatar.contains('/documents/'))
        ? rawAvatar
        : null;
    final authorName = widget.post.authorName;
    final text = widget.post.text ?? '';
    final likesCount = _localLikesCount ?? widget.post.likesCount;
    final commentsCount = widget.post.commentsCount;
    final shareCount = widget.post.sharesCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: authorAvatar != null ? NetworkImage(authorAvatar) : null,
                child: authorAvatar == null
                    ? Icon(Icons.person, size: 20, color: Colors.grey.shade400)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            authorName,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getTimeAgo(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _extractUsername(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                        height: 1.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_horiz, color: Colors.grey.shade600, size: 20),
                onPressed: widget.onMore,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          
          // Post text
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade800,
                height: 1.5,
              ),
            ),
          ],
          
          // Media (image/video)
          if (hasMedia) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 400),
                width: double.infinity,
                color: Colors.grey.shade100,
                child: mediaUrl != null && mediaUrl.isNotEmpty
                    ? (mediaUrl.startsWith('assets/')
                        ? Image.asset(
                            mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.image, size: 48, color: Colors.grey)),
                          )
                        : Image.network(
                            mediaUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 800, // Optimize memory usage
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (_, error, __) {
                              debugPrint('❌ Feed image load failed: $mediaUrl — $error');
                              return Center(
                                child: Icon(Icons.broken_image, size: 48, color: Colors.grey.shade300),
                              );
                            },
                          ))
                    : (hasVideo
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 300,
                                color: Colors.grey.shade200,
                              ),
                              Icon(Icons.play_circle_outline, size: 64, color: Colors.grey.shade600),
                            ],
                          )
                        : Center(child: Icon(Icons.image, size: 48, color: Colors.grey.shade300))),
              ),
            ),
          ],
          
          // Action buttons
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionButton(
                icon: (_isLiked ?? false) ? Icons.favorite : Icons.favorite_border,
                iconColor: (_isLiked ?? false) ? const Color(0xFFE53935) : Colors.black,
                count: likesCount,
                onTap: _toggleLike,
                scaleAnimation: _likeScaleAnimation,
              ),
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                iconColor: Colors.black,
                count: commentsCount,
                onTap: widget.onComment,
              ),
              _ActionButton(
                icon: Icons.repeat,
                iconColor: Colors.black,
                count: shareCount,
                onTap: widget.onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Action button widget for post interactions (like, comment, share)
/// Matches PostCardText design
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final int count;
  final VoidCallback onTap;
  final Animation<double>? scaleAnimation;

  const _ActionButton({
    required this.icon,
    this.iconColor,
    required this.count,
    required this.onTap,
    this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.black;
    
    final button = InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );

    // Apply scale animation if provided (for like button)
    if (scaleAnimation != null) {
      return ScaleTransition(
        scale: scaleAnimation!,
        child: button,
      );
    }

    return button;
  }
}

class _PollCardContent extends ConsumerStatefulWidget {
  final PostModel post;
  final FeedRepository feedRepo;

  const _PollCardContent({required this.post, required this.feedRepo});

  @override
  ConsumerState<_PollCardContent> createState() => _PollCardContentState();
}

class _PollCardContentState extends ConsumerState<_PollCardContent> {
  bool _hasVoted = false;
  bool _isVoting = false;
  bool _isLoadingResults = true;
  PollData? _updatedPollData;

  @override
  void initState() {
    super.initState();
    _loadPollResults();
  }

  Future<void> _loadPollResults() async {
    try {
      setState(() => _isLoadingResults = true);
      
      // First, check locally from poll data if available
      final poll = widget.post.poll;
      if (poll != null && poll.votedUsers.isNotEmpty) {
        // Get current user ID from storage
        final userId = await StorageService.getString(AppConstants.keyUserId);
        final hasVoted = userId != null && poll.votedUsers.contains(userId);
        
        if (mounted) {
          setState(() {
            _hasVoted = hasVoted;
            _isLoadingResults = false;
          });
        }
        return;
      }
      
      // Fallback: Try to get from backend if votedUsers is empty
      // (This will fail if backend endpoint is not implemented, which is OK)
      try {
        final pollData = await widget.feedRepo.getPollResults(widget.post.id);
        
        if (mounted && pollData != null) {
          final userVoted = pollData['userVoted'] == true;
          
          // Parse updated poll data if available
          if (userVoted) {
            final options = (pollData['options'] as List<dynamic>?)?.asMap().entries.map((entry) {
              final opt = entry.value as Map<String, dynamic>;
              return PollOption(
                text: opt['text']?.toString() ?? '',
                index: entry.key,
                count: (opt['votes'] ?? 0) as int,
              );
            }).toList() ?? [];
            
            _updatedPollData = PollData(
              question: pollData['question']?.toString() ?? widget.post.poll?.question ?? '',
              options: options,
              totalVotes: (pollData['totalVotes'] ?? 0) as int,
            );
          }
          
          setState(() {
            _hasVoted = userVoted;
            _isLoadingResults = false;
          });
        } else if (mounted) {
          setState(() => _isLoadingResults = false);
        }
      } catch (e) {
        // Backend endpoint not available - just use local data
        debugPrint('⚠️ Poll results endpoint not available, using local data');
        if (mounted) setState(() => _isLoadingResults = false);
      }
    } catch (e) {
      debugPrint('❌ Failed to load poll results: $e');
      if (mounted) setState(() => _isLoadingResults = false);
    }
  }

  Future<void> _vote(int optionIndex) async {
    if (_isVoting || _hasVoted) return;
    
    setState(() => _isVoting = true);
    
    try {
      final response = await widget.feedRepo.votePoll(
        postId: widget.post.id,
        optionIndex: optionIndex,
      );
      
      // Parse updated poll data from response
      final pollDataFromResponse = response['poll'] as Map<String, dynamic>?;
      if (pollDataFromResponse != null) {
        final options = (pollDataFromResponse['options'] as List<dynamic>?)?.asMap().entries.map((entry) {
          final opt = entry.value as Map<String, dynamic>;
          return PollOption(
            text: opt['text']?.toString() ?? '',
            index: (opt['index'] ?? entry.key) as int,
            count: (opt['votes'] ?? 0) as int,
          );
        }).toList() ?? [];
        
        _updatedPollData = PollData(
          question: pollDataFromResponse['question']?.toString() ?? widget.post.poll?.question ?? '',
          options: options,
          totalVotes: (pollDataFromResponse['totalVotes'] ?? 0) as int,
        );
      }
      
      if (mounted) {
        setState(() {
          _hasVoted = true;
          _isVoting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote recorded!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Poll vote error: $e');
      if (mounted) {
        setState(() => _isVoting = false);
        
        String errorMessage = 'Failed to vote';
        if (e.toString().contains('Already voted')) {
          errorMessage = 'You have already voted on this poll';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final postTime = widget.post.createdAt;
    final diff = now.difference(postTime);
    
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  String _extractUsername() {
    final name = widget.post.authorName;
    final atIndex = name.indexOf('@');
    if (atIndex != -1 && atIndex < name.length - 1) {
      return name.substring(atIndex);
    }
    return '@${name.toLowerCase().replaceAll(' ', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final poll = _updatedPollData ?? post.poll;
    if (poll == null) return const SizedBox.shrink();

    final totalVotes = poll.totalVotes;
    final hasVoted = _hasVoted;
    final rawAvatar = post.authorPhotoUrl;
    final authorAvatar = (rawAvatar != null &&
            rawAvatar.isNotEmpty &&
            !rawAvatar.toLowerCase().endsWith('.pdf') &&
            !rawAvatar.contains('/documents/'))
        ? rawAvatar
        : null;

    // Show loading while checking poll status
    if (_isLoadingResults) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: authorAvatar != null ? NetworkImage(authorAvatar) : null,
                child: authorAvatar == null
                    ? Icon(Icons.person, size: 20, color: Colors.grey.shade400)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _extractUsername(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          poll.question,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade800,
            height: 1.5,
          ),
        ),
          const SizedBox(height: 16),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Author row
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: authorAvatar != null ? NetworkImage(authorAvatar) : null,
              child: authorAvatar == null
                  ? Icon(Icons.person, size: 20, color: Colors.grey.shade400)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.authorName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getTimeAgo(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _extractUsername(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Poll question
        Text(
          poll.question,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade800,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        
        // Poll options
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (hasVoted)
                ...poll.options.asMap().entries.map((e) {
                  final count = e.value.count;
                  final pct = totalVotes > 0 ? (count / totalVotes) : 0.0;
                  final pctText = '${(pct * 100).round()}%';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                e.value.text,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              pctText,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.white,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6A1A5D)),
                            minHeight: 6,
                          ),
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
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: Text(
                          e.value.text,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

/// Positions the FAB a bit higher so it aligns better with the floating bottom nav.
class _DiscoverFabLocation extends FloatingActionButtonLocation {
  const _DiscoverFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    const double endPadding = 16;
    const double bottomPadding = 148;
    final double x = geometry.scaffoldSize.width -
        geometry.floatingActionButtonSize.width -
        endPadding;
    final double y = geometry.contentBottom -
        geometry.floatingActionButtonSize.height -
        bottomPadding;
    return Offset(x, y);
  }
}
