import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/providers/chat_provider.dart';
import 'package:kins_app/repositories/users_repository.dart';
import 'package:kins_app/services/follow_service.dart';
import 'package:kins_app/services/firebase_chat_auth_service.dart';

/// New Chat screen: search users by name, email, username; tap Message to start 1:1 chat.
/// FAB on Chats tab opens this screen. New conversations appear in the Chats list.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserListItem> _users = [];
  bool _loading = false;
  String? _error;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _searchUsers(_searchController.text);
    });
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await UsersRepository.getUsersForAddMember();
      if (!mounted) return;
      setState(() {
        _users = _excludeCurrentUser(list);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _users = [];
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = query.trim().isEmpty
          ? await UsersRepository.getUsersForAddMember()
          : await UsersRepository.searchUsers(query.trim());
      if (!mounted) return;
      setState(() {
        _users = _excludeCurrentUser(list);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _users = [];
          _loading = false;
        });
      }
    }
  }

  List<UserListItem> _excludeCurrentUser(List<UserListItem> list) {
    final myId = currentUserId;
    if (myId.isEmpty) return list;
    return list.where((u) => u.id != myId).toList();
  }

  Future<void> _onMessage(UserListItem user) async {
    final myUid = currentUserId;
    if (myUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in first')),
        );
      }
      return;
    }
    if (user.id == myUid) return;

    try {
      await FirebaseChatAuthService.ensureFirebaseSignedIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: ${e.toString()}')),
        );
      }
      return;
    }

    final directRepo = ref.read(directChatRepositoryProvider);
    String chatId;
    try {
      chatId = await directRepo.getOrCreateConversation(myUid, user.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create conversation: ${e.toString()}')),
        );
      }
      return;
    }

    String? otherName = user.name;
    String? otherPhoto = user.profilePictureUrl;
    try {
      final profile = await FollowService.getPublicProfile(user.id);
      otherName = profile?.displayNameForChat ?? user.name;
      otherPhoto = profile?.profilePictureUrl ?? user.profilePictureUrl;
    } catch (_) {}

    if (!mounted) return;
    context.pop();
    context.push(
      AppConstants.chatConversationPath(chatId),
      extra: {
        'otherUserId': user.id,
        'otherUserName': otherName,
        'otherUserAvatarUrl': otherPhoto,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'New Chat',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 20),
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.screenPaddingH(context),
              vertical: Responsive.spacing(context, 8),
            ),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    color: Colors.grey.shade600,
                  ),
                  prefixIcon: Icon(Icons.search, size: 22, color: Colors.grey.shade600),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 14),
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: Responsive.spacing(context, 12)),
                          TextButton(
                            onPressed: _loadUsers,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _loading && _users.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _users.isEmpty
                        ? Center(
                            child: Text(
                              'No users found. Try a different search.',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 15),
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.screenPaddingH(context),
                              vertical: Responsive.spacing(context, 8),
                            ),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return _UserRow(
                                user: user,
                                onMessage: () => _onMessage(user),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserListItem user;
  final VoidCallback onMessage;

  const _UserRow({required this.user, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.spacing(context, 4)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF6B4C93).withOpacity(0.2),
            backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                ? NetworkImage(user.profilePictureUrl!)
                : null,
            child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 20),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B4C93),
                    ),
                  )
                : null,
          ),
          SizedBox(width: Responsive.spacing(context, 14)),
          Expanded(
            child: Text(
              user.name,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onMessage,
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.black87,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.spacing(context, 16),
                vertical: Responsive.spacing(context, 8),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Message',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
