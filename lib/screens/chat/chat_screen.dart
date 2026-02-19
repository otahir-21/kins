import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/routes/app_router.dart';
import 'package:kins_app/models/chat_model.dart';
import 'package:kins_app/providers/chat_provider.dart';
import 'package:kins_app/providers/notification_provider.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/repositories/groups_repository.dart';
import 'package:kins_app/services/follow_service.dart';
import 'package:kins_app/screens/chat/group_conversation_screen.dart';
import 'package:kins_app/services/firebase_chat_auth_service.dart';
import 'package:kins_app/widgets/app_drawer.dart';
import 'package:kins_app/widgets/app_header.dart';
import 'package:kins_app/widgets/fab_location.dart';
import 'package:kins_app/widgets/floating_nav_overlay.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

/// Chat screen with Groups / Chats / Marketplace tabs, search, and list UI
/// matching the design (header, segmented control, search bar, chat list, FAB, bottom nav).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with RouteAware {
  int _selectedSegment = 0; // 0: Groups, 1: Chats, 2: Marketplace
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String? _userName;
  String? _userLocation;
  String? _profilePictureUrl;

  List<GroupListItem> _groups = [];
  bool _groupsLoading = true;
  String? _groupsError;
  Timer? _searchDebounce;
  bool _routeObserverSubscribed = false;
  bool _firebaseChatReady = false;
  bool _firebaseChatSigningIn = false;
  String? _firebaseChatError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadUserProfile();
    _loadGroups();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void> && !_routeObserverSubscribed) {
      _routeObserverSubscribed = true;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // User returned to this screen (e.g. from Group Setting or Discover); refresh groups list.
    if (_selectedSegment == 0) _loadGroups();
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce?.cancel();
    if (_selectedSegment != 0) return;
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _selectedSegment == 0) _loadGroups();
    });
  }

  Future<void> _loadGroups() async {
    if (_selectedSegment != 0) return;
    if (!mounted) return;
    setState(() {
      _groupsLoading = true;
      _groupsError = null;
    });
    try {
      final search = _searchController.text.trim();
      final res = await GroupsRepository.getGroups(
        search: search.isEmpty ? null : search,
        page: 1,
        limit: 20,
      );
      if (mounted && _selectedSegment == 0) {
        setState(() {
          _groups = res.groups;
          _groupsLoading = false;
          _groupsError = null;
        });
      }
    } catch (e) {
      if (mounted && _selectedSegment == 0) {
        setState(() {
          _groups = [];
          _groupsLoading = false;
          _groupsError = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '');
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final me = await BackendApiClient.get('/me');
      final user = me['user'] is Map<String, dynamic>
          ? me['user'] as Map<String, dynamic>
          : me;
      final city = user['city']?.toString();
      final country = user['country']?.toString();
      final location =
          (city != null && city.isNotEmpty) ||
              (country != null && country.isNotEmpty)
          ? [
              if (city != null && city.isNotEmpty) city,
              if (country != null && country.isNotEmpty) country,
            ].join(', ')
          : null;
      if (mounted) {
        setState(() {
          _userName =
              user['name']?.toString() ??
              user['username']?.toString() ??
              'Chats';
          _userLocation = location;
          _profilePictureUrl = user['profilePictureUrl']?.toString();
        });
      }
    } catch (e) {
      debugPrint('ChatScreen: failed to load user profile: $e');
    }
  }

  @override
  void dispose() {
    if (_routeObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  static const List<String> _tabTitles = ['Groups', 'Chats', 'Marketplace'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(
        onAfterSettings: () {
          if (mounted) _loadUserProfile();
        },
      ),
      body: Builder(
        builder: (scaffoldContext) => FloatingNavOverlay(
          currentIndex: 1,
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(scaffoldContext)),
                SliverToBoxAdapter(child: _buildTabSelector()),
                SliverToBoxAdapter(child: _buildSearchBar()),
                _selectedSegment == 0
                    ? _buildGroupsSliver()
                    : _selectedSegment == 1
                    ? _buildChatsSliver()
                    : _buildMarketplaceSliver(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onFabPressed,
        mini: true,
        shape: const CircleBorder(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        child: const Icon(Icons.add, size: 22),
      ),
      floatingActionButtonLocation: const KinsFabLocation(),
    );
  }

  Widget _buildHeader(BuildContext scaffoldContext) {
    final uid = currentUserId;
    final notificationState = uid.isNotEmpty
        ? ref.watch(notificationsProvider(uid))
        : null;
    final unreadCount = notificationState?.unreadCount ?? 0;

    return AppHeader(
      leading: AppHeader.drawerButton(scaffoldContext),
      name: _userName ?? 'Chats',
      subtitle: _userLocation,
      profileImageUrl: _profilePictureUrl,
      onTitleTap: () => context.push(AppConstants.routeProfile),
      trailing: GestureDetector(
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
              child: const Icon(
                Icons.notifications_outlined,
                size: 18,
                color: Colors.black87,
              ),
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
    );
  }

  static const Color _tabIndicatorColor = Color(0xFF7A084D);

  Widget _buildTabSelector() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _tabTitles.asMap().entries.map((entry) {
          final index = entry.key;
          final title = entry.value;
          final isSelected = _selectedSegment == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedSegment = index);
              if (index == 0) {
                _loadGroups();
              } else if (index == 1 && !_firebaseChatReady && !_firebaseChatSigningIn) {
                _ensureFirebaseForChats();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 18) * 0.7,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected ? Colors.black : Colors.grey,
                    ),
                  ),
                  SizedBox(height: Responsive.spacing(context, 6)),
                  if (isSelected)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 2,
                      color: _tabIndicatorColor,
                    )
                  else
                    const SizedBox(height: 2),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.screenPaddingH(context),
        vertical: Responsive.spacing(context, 8),
      ),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
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
                  filled: true,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Image.asset(
              'assets/logo/Logo-KINS.png',
              errorBuilder: (_, __, ___) => Text(
                'KINS',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 15),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsSliver() {
    if (_groupsLoading && _groups.isEmpty) {
      return SliverPadding(
        padding: EdgeInsets.only(bottom: Responsive.spacing(context, 24)),
        sliver: SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 32)),
            child: Center(
              child: CircularProgressIndicator(color: const Color(0xFF7A084D)),
            ),
          ),
        ),
      );
    }
    if (_groupsError != null && _groups.isEmpty) {
      return SliverPadding(
        padding: EdgeInsets.only(bottom: Responsive.spacing(context, 24)),
        sliver: SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 32)),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _groupsError!,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.spacing(context, 12)),
                  TextButton(
                    onPressed: _loadGroups,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_groups.isEmpty) {
      return SliverPadding(
        padding: EdgeInsets.only(bottom: Responsive.spacing(context, 24)),
        sliver: SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 32)),
            child: Center(
              child: Text(
                'No groups yet. Tap + to create one.',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 15),
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.only(bottom: Responsive.spacing(context, 24)),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final group = _groups[index];
          return GroupCard(
            groupId: group.id,
            name: group.name,
            description: group.description,
            members: group.memberCount,
            imageUrl: group.imageUrl,
            onTap: () {
              context.push(
                AppConstants.groupConversationPath(group.id),
                extra: GroupConversationArgs(
                  groupId: group.id,
                  name: group.name,
                  description: group.description,
                  imageUrl: group.imageUrl,
                ),
              );
            },
            onJoin: () {
              // TODO: Join group
            },
          );
        }, childCount: _groups.length),
      ),
    );
  }

  Future<void> _ensureFirebaseForChats() async {
    if (_firebaseChatReady || _firebaseChatSigningIn) return;
    setState(() {
      _firebaseChatSigningIn = true;
      _firebaseChatError = null;
    });
    try {
      await FirebaseChatAuthService.ensureFirebaseSignedIn();
      if (mounted) {
        setState(() {
          _firebaseChatReady = true;
          _firebaseChatSigningIn = false;
          _firebaseChatError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _firebaseChatSigningIn = false;
          _firebaseChatError = e.toString();
        });
      }
    }
  }

  Widget _buildChatsSliver() {
    final myUid = currentUserId;
    if (_selectedSegment == 1 && !_firebaseChatReady) {
      if (!_firebaseChatSigningIn && _firebaseChatError == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFirebaseForChats());
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: _firebaseChatError != null
              ? Padding(
                  padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load chats',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 16),
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _firebaseChatError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() => _firebaseChatError = null);
                          _ensureFirebaseForChats();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final chatsAsync = ref.watch(myChatsStreamProvider);
    return SliverFillRemaining(
      hasScrollBody: true,
      child: chatsAsync.when(
        data: (chats) {
          final searchQuery = _searchController.text.toLowerCase();
          final filtered = searchQuery.isEmpty
              ? chats
              : chats
                    .where(
                      (c) =>
                          c.lastMessageText.toLowerCase().contains(searchQuery),
                    )
                    .toList();
          if (filtered.isEmpty) {
            return Center(
              child: Text(
                chats.isEmpty
                    ? 'No chats yet. Tap + to start a conversation.'
                    : 'No matching chats.',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 15),
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.screenPaddingH(context),
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final chat = filtered[index];
              return _ChatListRow(chat: chat, myUid: myUid);
            },
          );
        },
        loading: () => const SkeletonChatList(),
        error: (e, st) {
          debugPrint('Chat list error: $e');
          debugPrint('Stack: $st');
          final msg = e.toString();
          final isIndex =
              msg.contains('index') ||
              msg.contains('Index') ||
              msg.contains('create_composite');
          final isPermission =
              msg.contains('PERMISSION_DENIED') || msg.contains('permission');
          String hint = '';
          if (isIndex) {
            hint =
                "\n\nFix: Copy the 'https://console.firebase.google.com/...' link from the debug console above, open it in a browser, then click 'Create index'. Use Collection group scope if you created one manually.";
          }
          if (isPermission)
            hint =
                '\n\nAdd Firestore rules for "conversations" in Firebase Console → Firestore → Rules (see docs/FIREBASE_GROUP_CHAT_RULES.md § 1:1).';
          return Center(
            child: Padding(
              padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 18),
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg + hint,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 13),
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMarketplaceSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Marketplace',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buy & sell with other kins',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onFabPressed() {
    if (_selectedSegment == 0) {
      context.push(AppConstants.routeCreateGroup);
    } else if (_selectedSegment == 1) {
      context.push(AppConstants.routeNewChat);
    } else {
      // Marketplace
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marketplace coming soon')));
    }
  }

  void _showNewChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _NewChatSheet(
        myUid: currentUserId,
        onStarted: () => Navigator.pop(context),
      ),
    );
  }
}

/// Row that loads other user's name/avatar and opens conversation on tap.
class _ChatListRow extends ConsumerWidget {
  final ChatConversation chat;
  final String myUid;

  const _ChatListRow({required this.chat, required this.myUid});

  static String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat.jm().format(date);
    }
    if (date.year == now.year && date.month == now.month && now.day - date.day == 1) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 14) return 'a week ago';
    if (date.year == now.year) return DateFormat.MMMd().format(date);
    return DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserId = chat.otherParticipantId(myUid);
    if (kDebugMode && otherUserId.isEmpty) {
      debugPrint('⚠️ [ChatListRow] otherUserId is empty for conversation ${chat.id} participantIds=${chat.participantIds} myUid=$myUid');
    }
    final otherUserAsync = ref.watch(otherUserByIdProvider(otherUserId));
    final name = otherUserAsync.valueOrNull?.displayNameForChat ?? 'User';
    final avatarUrl = otherUserAsync.valueOrNull?.profilePictureUrl;
    final timeStr = _formatTime(chat.lastMessageAt);

    return _ChatListTile(
      name: name,
      lastMessage: chat.lastMessageText,
      time: timeStr,
      unreadCount: chat.unreadCountFor(myUid),
      avatarUrl: avatarUrl,
      onTap: () {
        context.push(
          AppConstants.chatConversationPath(chat.id),
          extra: {
            'otherUserId': otherUserId,
            'otherUserName': name,
            'otherUserAvatarUrl': avatarUrl,
          },
        );
      },
    );
  }
}

class _ChatListTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _ChatListTile({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF6B4C93).withOpacity(0.2),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: const Color(0xFF6B4C93),
                        fontWeight: FontWeight.w600,
                        fontSize: Responsive.fontSize(context, 20),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 16),
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    color: Colors.grey.shade600,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B4C93),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: Responsive.fontSize(context, 12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable group card with image, name, description, member avatars, and Join button.
class GroupCard extends StatelessWidget {
  final String groupId;
  final String name;
  final String description;
  final int members;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback onJoin;

  const GroupCard({
    super.key,
    this.groupId = '',
    required this.name,
    required this.description,
    required this.members,
    this.imageUrl,
    this.onTap,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      margin: EdgeInsets.symmetric(
        horizontal: Responsive.screenPaddingH(context),
        vertical: Responsive.spacing(context, 5),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.scale(context, 24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            // offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    height: Responsive.scale(context, 140),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: Responsive.scale(context, 140),
                    width: double.infinity,
                    color: const Color(0xFF6B4C93).withOpacity(0.15),
                    child: Icon(
                      Icons.group,
                      color: const Color(0xFF6B4C93),
                      size: Responsive.scale(context, 48),
                    ),
                  ),
          ),

          Padding(
            padding: const EdgeInsets.only(
              left: 18,
              right: 18,
              bottom: 8,
              top: 5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TITLE + MEMBER COUNT
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$members Members',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          height: 1.4,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    _MemberAvatars(memberCount: members),
                    _GroupJoinPlusButton(onTap: onJoin),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Responsive.scale(context, 24)),
        child: child,
      );
    }
    return child;
  }
}

/// Avatar stack: up to 2 member circles + one "N+" overflow circle (same size as avatars).
class _MemberAvatars extends StatelessWidget {
  final int memberCount;

  const _MemberAvatars({required this.memberCount});

  static const double _avatarRadius = 14;
  static const double _overlap = 8;

  @override
  Widget build(BuildContext context) {
    final diameter = _avatarRadius * 2;
    final showOverflow = memberCount > 2;
    final avatarCount = showOverflow ? 2 : memberCount.clamp(1, 2);
    final circleCount = showOverflow ? 3 : avatarCount;
    final totalWidth = circleCount * (diameter - _overlap) + _overlap;

    return SizedBox(
      width: totalWidth,
      height: diameter,
      child: Stack(
        children: [
          // First 2 avatars (placeholder circles)
          ...List.generate(avatarCount, (i) {
            return Positioned(
              left: i * (diameter - _overlap),
              child: CircleAvatar(
                radius: _avatarRadius,
                backgroundColor: const Color(0xFF6B4C93).withOpacity(0.25),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C93),
                  ),
                ),
              ),
            );
          }),
          // "N+" overflow circle (same size, white bg, black text)
          if (showOverflow)
            Positioned(
              left: 2 * (diameter - _overlap),
              child: CircleAvatar(
                radius: _avatarRadius,
                backgroundColor: Colors.white,
                child: Text(
                  '${(memberCount - 2).clamp(1, 999)}+',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Circular plus button matching avatar size (light grey bg, dark + icon).
class _GroupJoinPlusButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GroupJoinPlusButton({required this.onTap});

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade200,
        ),
        child: Icon(Icons.add, size: 20, color: Colors.grey.shade700),
      ),
    );
  }
}

/// Bottom sheet to start a new chat by entering the other user's phone number.
class _NewChatSheet extends ConsumerStatefulWidget {
  final String myUid;
  final VoidCallback onStarted;

  const _NewChatSheet({required this.myUid, required this.onStarted});

  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet> {
  String _completePhoneNumber = '';
  bool _isLoading = false;

  void _showMessageAndClose(String message) {
    widget.onStarted(); // close sheet first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _startChat() async {
    final phone = _completePhoneNumber.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a phone number with country code')),
      );
      return;
    }
    if (widget.myUid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userDetailsRepositoryProvider);
      final status = await userRepo.checkUserByPhoneNumber(phone);
      if (!status.exists || status.userId == null) {
        if (mounted)
          _showMessageAndClose(
            'No user found with this number. They need to join the app first.',
          );
        return;
      }
      final otherUserId = status.userId!;
      if (otherUserId == widget.myUid) {
        if (mounted)
          _showMessageAndClose(
            "You can't chat with yourself. Enter another person's number.",
          );
        return;
      }

      final directRepo = ref.read(directChatRepositoryProvider);
      String chatId;
      try {
        chatId = await directRepo.getOrCreateConversation(widget.myUid, otherUserId);
      } catch (e) {
        debugPrint('Chat create error: $e');
        if (mounted)
          _showMessageAndClose(
            'Cannot create chat. Check Firestore rules for "conversations".',
          );
        return;
      }

      String? otherName;
      String? otherPhoto;
      try {
        final otherUser = await FollowService.getPublicProfile(otherUserId);
        otherName = otherUser?.displayNameForChat ?? 'User';
        otherPhoto = otherUser?.profilePictureUrl;
      } catch (e) {
        debugPrint('User details error (using fallback): $e');
        otherName = 'User';
      }

      if (!mounted) return;
      widget.onStarted(); // close sheet first
      await Future.delayed(
        const Duration(milliseconds: 300),
      ); // let sheet close
      if (!mounted) return;
      context.push(
        AppConstants.chatConversationPath(chatId),
        extra: {
          'otherUserId': otherUserId,
          'otherUserName': otherName,
          'otherUserAvatarUrl': otherPhoto,
        },
      );
    } catch (e) {
      debugPrint('Start chat error: $e');
      if (mounted) _showMessageAndClose('Failed to start chat: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'New chat',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 20),
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
              const SizedBox(height: 8),
              Text(
                'Enter their phone number with country code (e.g. +1 234 567 8900)',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              IntlPhoneField(
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  labelStyle: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    color: Colors.grey.shade600,
                  ),
                  hintStyle: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    color: Colors.grey.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                initialCountryCode: 'AE',
                onChanged: (phone) {
                  _completePhoneNumber = phone.completeNumber;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4C93),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SkeletonInline(size: 24)
                      : const Text('Start chat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
