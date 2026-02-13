import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/models/chat_model.dart';
import 'package:kins_app/providers/chat_provider.dart';
import 'package:kins_app/repositories/chat_repository.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:intl/intl.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

/// WhatsApp-like conversation screen: bubbles, time, delivery/seen ticks.
class ConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String? otherUserName;
  final String? otherUserAvatarUrl;

  const ConversationScreen({
    super.key,
    required this.chatId,
    this.otherUserName,
    this.otherUserAvatarUrl,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _chatRepo = ChatRepository();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _markDeliveredAndSeen();
  }

  Future<void> _markDeliveredAndSeen() async {
    final uid = currentUserId.isNotEmpty ? currentUserId : null;
    if (uid == null) return;
    try {
      await _chatRepo.markDeliveredAndSeen(widget.chatId, uid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    final uid = currentUserId.isNotEmpty ? currentUserId : null;
    if (uid == null) return;

    setState(() {
      _isSending = true;
      _textController.clear();
    });
    try {
      await _chatRepo.sendMessage(chatId: widget.chatId, senderId: uid, text: text);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserId;
    final myUid = uid;
    final chatSnap = ref.watch(chatStreamProvider(widget.chatId));
    final chat = chatSnap.valueOrNull;
    final otherUserId = _otherUserId(chat);
    final otherUserAsync = otherUserId.isNotEmpty ? ref.watch(otherUserByIdProvider(otherUserId)) : const AsyncValue.data(null);
    final displayName = widget.otherUserName ?? otherUserAsync.valueOrNull?.name ?? 'Chat';
    final displayAvatar = widget.otherUserAvatarUrl ?? otherUserAsync.valueOrNull?.profilePictureUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5), // WhatsApp-like background
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54), // WhatsApp green
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: displayAvatar != null ? NetworkImage(displayAvatar) : null,
              child: displayAvatar == null
                  ? const Icon(Icons.person, color: Colors.white, size: 24)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (_) {},
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'info', child: Text('View profile')),
              const PopupMenuItem(value: 'mute', child: Text('Mute')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatRepo.streamMessages(widget.chatId),
              builder: (context, msgSnap) {
                if (!msgSnap.hasData) {
                  return const SkeletonCommentList(itemCount: 4);
                }
                final messages = msgSnap.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hi!',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    ),
                  );
                }
                return StreamBuilder<ChatConversation?>(
                  stream: _chatRepo.streamChat(widget.chatId),
                  builder: (context, chatSnap) {
                    final chat = chatSnap.data;
                    final otherUid = _otherUserId(chat);
                    final lastDelivered = chat?.lastDeliveredAtBy ?? {};
                    final lastSeen = chat?.lastSeenAtBy ?? {};

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == myUid;
                        final status = isMe
                            ? (msg.isLocalPending
                                ? MessageStatus.sending
                                : messageStatusForSender(
                                    messageCreatedAt: msg.createdAt,
                                    otherUserId: otherUid,
                                    lastDeliveredAtBy: lastDelivered,
                                    lastSeenAtBy: lastSeen,
                                  ))
                            : null;
                        return _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          status: status,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  String _otherUserId(ChatConversation? chat) {
    if (chat == null) return '';
    final myUid = currentUserId;
    final list = chat.participantIds.where((id) => id != myUid).toList();
    return list.isNotEmpty ? list.first : '';
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      color: const Color(0xFFF0F2F5),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey.shade700),
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF075E54),
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const SkeletonInline(size: 24)
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final MessageStatus? status;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = message.createdAt != null
        ? DateFormat.jm().format(message.createdAt!)
        : '...';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFD9FDD3) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (isMe && status != null) ...[
                  const SizedBox(width: 4),
                  _StatusTicks(status: status!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTicks extends StatelessWidget {
  final MessageStatus status;

  const _StatusTicks({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.grey;
        break;
      case MessageStatus.sent:
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case MessageStatus.seen:
        icon = Icons.done_all;
        color = const Color(0xFF34B7F1); // blue ticks
        break;
    }
    return Icon(icon, size: 16, color: color);
  }
}
