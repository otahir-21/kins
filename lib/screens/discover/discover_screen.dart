import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/responsive/responsive.dart';
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
import 'package:kins_app/services/backend_auth_service.dart';
import 'package:kins_app/widgets/confirm_dialog.dart';
import 'package:kins_app/widgets/floating_nav_overlay.dart';
import 'package:kins_app/widgets/kins_logo.dart';
import 'package:kins_app/screens/comments/comments_bottom_sheet.dart';
import 'package:kins_app/widgets/feed_post_card.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';
import 'package:kins_app/providers/notification_provider.dart';


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
      
      final city = user['city']?.toString();
      final country = user['country']?.toString();
      final location = (city != null && city.isNotEmpty) || (country != null && country.isNotEmpty)
          ? [if (city != null && city.isNotEmpty) city, if (country != null && country.isNotEmpty) country].join(', ')
          : null;

      if (mounted) {
        setState(() {
          _userName = user['name']?.toString() ?? user['username']?.toString() ?? 'User';
          _userLocation = location;
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
      
      // Fetch all posts from GET /posts?page=&limit= (posts from all users)
      final feedPosts = await feedRepo.getFeed(
        page: isRefresh ? 1 : _currentPage,
        limit: 20,
      );
      
      // Use posts as-is (already sorted by backend or we sort)
      List<PostModel> allPosts = List.from(feedPosts);
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
      backgroundColor: _headerBg,
      drawer: _buildDrawer(),
      body: FloatingNavOverlay(
        currentIndex: 0,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildInterestTagsRow(),
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
        mini: true,
        shape: const CircleBorder(),
        backgroundColor: Colors.grey.shade200,
        child: const Icon(Icons.add, color: Colors.black, size: 22),
      ),
      floatingActionButtonLocation: const _DiscoverFabLocation(),
    );
  }

  /// Build feed content with loading, error, and empty states
  Widget _buildFeedContent(FeedRepository feedRepo) {
    // Show loading on first load
    if (_isLoading && _allPosts.isEmpty) {
      return const SkeletonFeedList();
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
        padding: EdgeInsets.fromLTRB(
          Responsive.screenPaddingH(context),
          0,
          Responsive.screenPaddingH(context),
          1,
        ),
        itemCount: posts.length + (_hasMore ? 1 : 0),
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          if (index >= posts.length) {
            // Loading indicator at bottom
            return _isLoadingMore
                ? Padding(
                    padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
                    child: const SkeletonFeedItem(),
                  )
                : const SizedBox.shrink();
          }
          return _buildPostCardFromModel(posts[index], feedRepo);
        },
        cacheExtent: 1000, // Optimize scroll performance
      ),
    );
  }

  static const Color _headerBg = Colors.white;
  static const Color _greyMeta = Color(0xFF8E8E93);
  static const Color _borderGrey = Color(0xFFE5E5E5);

  Widget _buildHeader() {
    final uid = currentUserId;
    final notificationState = uid.isNotEmpty
        ? ref.watch(notificationsProvider(uid))
        : null;
    final unreadCount = notificationState?.unreadCount ?? 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),

      child: Column(
        children: [
          // 1) Top Header Row
          Builder(
            builder: (context) => Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 30,
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
                // CENTER: Avatar + Name + Location (pinned to left of center area).
                // Avoid Flexible inside Row(mainAxisSize: min) to prevent semantics.parentDataDirty assertion.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () async {
                        await context.push(AppConstants.routeProfile);
                        if (mounted) _loadUserProfile();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 35,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                              image: _profilePictureUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_profilePictureUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profilePictureUrl == null
                                ? Icon(Icons.person, size: 20, color: Colors.grey.shade400)
                                : null,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _userName ?? 'Discover',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 15),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_userLocation != null && _userLocation!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 14,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Icon(Icons.location_on_outlined, size: 12, color: _greyMeta),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          _userLocation!,
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(context, 12),
                                            color: _greyMeta,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // RIGHT: Notification bell (56x56 circle)
                GestureDetector(
                  onTap: () => context.push(AppConstants.routeNotifications),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 35,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_outlined, size: 18, color: Colors.black87),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          // 2) Search Bar
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _borderGrey, width: 1),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        color: Colors.grey.shade600,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  )
                ),
                const SizedBox(width: 12),
                Image.asset(
                  'assets/logo/Logo-KINS.png',
                  errorBuilder: (_, __, ___) => Text('KINS', style: TextStyle(fontSize: Responsive.fontSize(context, 15), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// Interest tags row - category chips for filtering posts by interest.
  Widget _buildInterestTagsRow() {
    if (_loadingInterests) {
      return const SkeletonFilterChips();
    }

    // Always show all available interests for filtering (user can tap to filter feed)
    final chipsList = List<InterestModel>.from(_allInterests)..sort((a, b) => a.name.compareTo(b.name));

    if (chipsList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: _headerBg,
      padding: EdgeInsets.fromLTRB(
        Responsive.screenPaddingH(context), 0,
        Responsive.screenPaddingH(context), 5,
      ),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2),
          itemCount: chipsList.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              final selected = _selectedInterestId == null;
              return _buildChip('All', selected, () => setState(() => _selectedInterestId = null));
            }
            final interest = chipsList[index - 1];
            final selected = _selectedInterestId == interest.id;
            return _buildChip(interest.name, selected, () => setState(() => _selectedInterestId = interest.id));
          },
        ),
      ),
    );
  }

  /// Same as select your interest: Container with maxWidth constraint, Row + Flexible(Text), no fixed width.
  static const Color _chipSelectedColor = Color(0xFF7a084e);
  static const double _chipRadius = 20;

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_chipRadius),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? _chipSelectedColor : Colors.white,
            borderRadius: BorderRadius.circular(_chipRadius),
            border: Border.all(
              color: selected ? _chipSelectedColor : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  KinsLogo(
                    width: Responsive.scale(context, 96),
                    height: Responsive.scale(context, 70),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(title: 'Saved Posts', icon: Icons.bookmark_border, onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(
                      title: 'Account Settings',
                      icon: Icons.person_outline,
                      onTap: () async {
                        Navigator.pop(context);
                        await context.push(AppConstants.routeSettings);
                        if (mounted) {
                          _loadUserProfile();
                          _loadInterests();
                        }
                      },
                    ),
                    _buildDrawerItem(title: 'Request Verification', icon: Icons.verified_outlined, onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(title: 'Terms of Service', icon: Icons.description_outlined, onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(title: 'Community Guidelines', icon: Icons.rule_outlined, onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(title: 'Privacy Policy', icon: Icons.privacy_tip_outlined, onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(title: 'About Us', icon: Icons.info_outline, onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(title: 'Contact Us', icon: Icons.contact_support_outlined, onTap: () => Navigator.pop(context)),
                    const Divider(height: 1),
                    _buildDrawerItem(
                      title: 'Log out',
                      icon: Icons.exit_to_app,
                      isLogout: true,
                      onTap: () async {
                        final shouldLogout = await showConfirmDialog<bool>(
                          context: context,
                          title: 'Log out',
                          message: 'Are you sure you want to log out?',
                          confirmLabel: 'Log out',
                          destructive: true,
                          icon: Icons.logout,
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
    required IconData icon,
    required VoidCallback onTap,
    bool isLogout = false,
    bool isDestructive = false,
  })
  {
    final useRed = isLogout || isDestructive;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          dense: true,
          leading: Icon(icon, color: useRed ? Colors.red : Colors.black87, size: 24),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: Responsive.fontSize(context, 14),
              color: useRed ? Colors.red : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: useRed ? Colors.red : Colors.grey,
          ),
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.screenPaddingH(context),
            vertical: 0,
          ),
        ),
      ],
    );
  }


  Widget _buildPostCardFromModel(PostModel post, FeedRepository feedRepo) {
    return FeedPostCard(
      key: ValueKey(post.id),
      post: post,
      feedRepo: feedRepo,
      onComment: (p) => _onCommentPost(context, p, feedRepo),
      onShare: (p) => _onSharePost(context, p, feedRepo),
      onMore: () => _showPostMoreMenu(context, post, feedRepo),
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
                padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
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
                  padding: EdgeInsets.fromLTRB(
                    Responsive.screenPaddingH(context),
                    8,
                    Responsive.screenPaddingH(context),
                    8,
                  ),
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
        margin: EdgeInsets.all(Responsive.screenPaddingH(context)),
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
    final report = await showConfirmDialog<bool>(
      context: context,
      title: 'Report post',
      message: 'Are you sure you want to report this post? Our team will review it.',
      confirmLabel: 'Report',
      destructive: true,
      icon: Icons.flag_outlined,
    );
    if (report == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you for helping keep Kins safe.')),
      );
      // TODO: persist report to Firestore reports collection if needed
    }
  }

  Future<void> _onDeletePost(BuildContext context, PostModel post) async {
    final confirm = await showConfirmDialog<bool>(
      context: context,
      title: 'Delete post?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline,
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

/// Positions the FAB a bit higher so it aligns better with the floating bottom nav.
class _DiscoverFabLocation extends FloatingActionButtonLocation {
  const _DiscoverFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    const double endPadding = 16;
    const double bottomPadding = 110;
    final double x = geometry.scaffoldSize.width -
        geometry.floatingActionButtonSize.width -
        endPadding;
    final double y = geometry.contentBottom -
        geometry.floatingActionButtonSize.height -
        bottomPadding;
    return Offset(x, y);
  }
}
