import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/models/chat_model.dart';
import 'package:kins_app/providers/chat_provider.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/widgets/floating_nav_overlay.dart';

/// Chat screen with Groups / Chats / Marketplace tabs, search, and list UI
/// matching the design (header, segmented control, search bar, chat list, FAB, bottom nav).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  int _selectedSegment = 1; // 0: Groups, 1: Chats, 2: Marketplace
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Mock groups list
  final List<Map<String, dynamic>> _groups = [
    {
      'title': 'Mums of Jumeirah',
      'description': 'Local mums in Jumeirah area',
      'members': 477,
      'imageUrl': null,
    },
    {
      'title': 'Abu Dhabi Schools',
      'description': 'Discuss schools and activities',
      'members': 1480,
      'imageUrl': null,
    },
    {
      'title': 'Miscarriage Recovery',
      'description': 'Support and healing together',
      'members': 821,
      'imageUrl': null,
    },
    {
      'title': 'Mums Who Walk',
      'description': 'Walking groups and meetups',
      'members': 75,
      'imageUrl': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FloatingNavOverlay(
        currentIndex: 1,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildSegmentedControl(),
              _buildSearchBar(),
              Expanded(
                child: _selectedSegment == 0
                    ? _buildGroupsList()
                    : _selectedSegment == 1
                        ? _buildChatsList()
                        : _buildMarketplacePlaceholder(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onFabPressed,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Chats',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey.shade700),
            onPressed: () => _searchFocusNode.requestFocus(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    const segments = ['Groups', 'Chats', 'Marketplace'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: List.generate(segments.length, (index) {
          final isSelected = _selectedSegment == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedSegment = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.grey.shade200 : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  segments[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 22),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildChatsList() {
    final myUid = currentUserId;
    final chatsAsync = ref.watch(myChatsStreamProvider);
    return chatsAsync.when(
      data: (chats) {
        final searchQuery = _searchController.text.toLowerCase();
        final filtered = searchQuery.isEmpty
            ? chats
            : chats.where((c) {
                // Filter by other user name will be applied in row via provider
                return c.lastMessageText.toLowerCase().contains(searchQuery);
              }).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Text(
              chats.isEmpty ? 'No chats yet. Tap + to start a conversation.' : 'No matching chats.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final chat = filtered[index];
            return _ChatListRow(chat: chat, myUid: myUid);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        debugPrint('Chat list error: $e');
        debugPrint('Stack: $st');
        final msg = e.toString();
        final isIndex = msg.contains('index') || msg.contains('Index') || msg.contains('create_composite');
        final isPermission = msg.contains('PERMISSION_DENIED') || msg.contains('permission');
        String hint = '';
        if (isIndex) {
          hint = "\n\nFix: Copy the 'https://console.firebase.google.com/...' link from the debug console above, open it in a browser, then click 'Create index'. Use Collection group scope if you created one manually.";
        }
        if (isPermission) hint = '\n\nAdd the chats security rules in Firebase Console → Firestore → Rules (see FIREBASE_CHAT_SETUP.md).';
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  msg + hint,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupsList() {
    final searchQuery = _searchController.text.toLowerCase();
    final filtered = searchQuery.isEmpty
        ? _groups
        : _groups.where((g) => (g['title'] as String).toLowerCase().contains(searchQuery)).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final group = filtered[index];
        return _GroupCard(
          title: group['title'] as String,
          description: group['description'] as String,
          members: group['members'] as int,
          imageUrl: group['imageUrl'] as String?,
          onJoin: () {
            // TODO: Join group
          },
        );
      },
    );
  }

  Widget _buildMarketplacePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Marketplace',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Buy & sell with other kins',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _onFabPressed() {
    if (_selectedSegment == 0) {
      // New group - TODO
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New group coming soon')),
      );
    } else if (_selectedSegment == 1) {
      _showNewChatSheet();
    } else {
      // Marketplace
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marketplace coming soon')),
      );
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
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat.jm().format(date);
    }
    if (date.year == now.year && date.month == now.month && now.day - date.day == 1) {
      return 'Yesterday';
    }
    if (date.year == now.year) return DateFormat.MMMd().format(date);
    return DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserId = chat.otherParticipantId(myUid);
    final otherUserAsync = ref.watch(otherUserByIdProvider(otherUserId));
    final name = otherUserAsync.valueOrNull?.name ?? 'User';
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
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFF6B4C93),
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
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
                    style: const TextStyle(
                      fontSize: 16,
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
                      fontSize: 14,
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
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B4C93),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
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

class _GroupCard extends StatelessWidget {
  final String title;
  final String description;
  final int members;
  final String? imageUrl;
  final VoidCallback onJoin;

  const _GroupCard({
    required this.title,
    required this.description,
    required this.members,
    this.imageUrl,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 64,
              height: 64,
              color: const Color(0xFF6B4C93).withOpacity(0.15),
              child: imageUrl != null
                  ? Image.network(imageUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.group, color: Color(0xFF6B4C93), size: 32),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$members Members',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: onJoin,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Join', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
          SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userDetailsRepositoryProvider);
      final chatRepo = ref.read(chatRepositoryProvider);

      final status = await userRepo.checkUserByPhoneNumber(phone);
      if (!status.exists || status.userId == null) {
        if (mounted) _showMessageAndClose('No user found with this number. They need to join the app first.');
        return;
      }
      final otherUserId = status.userId!;
      if (otherUserId == widget.myUid) {
        if (mounted) _showMessageAndClose("You can't chat with yourself. Enter another person's number.");
        return;
      }

      String chatId;
      try {
        chatId = await chatRepo.getOrCreate1v1Chat(widget.myUid, otherUserId);
      } catch (e) {
        debugPrint('Chat create error: $e');
        if (mounted) _showMessageAndClose('Cannot create chat. Check Firestore rules for "chats" (create).');
        return;
      }

      String? otherName;
      String? otherPhoto;
      try {
        final otherUser = await userRepo.getUserDetails(otherUserId);
        otherName = otherUser?.name ?? 'User';
        otherPhoto = otherUser?.profilePictureUrl;
      } catch (e) {
        debugPrint('User details error (using fallback): $e');
        otherName = 'User';
      }

      if (!mounted) return;
      widget.onStarted(); // close sheet first
      await Future.delayed(const Duration(milliseconds: 300)); // let sheet close
      if (!mounted) return;
      context.push(
        AppConstants.chatConversationPath(chatId),
        extra: {
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'New chat',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              IntlPhoneField(
                decoration: InputDecoration(
                  labelText: 'Phone number',
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
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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
