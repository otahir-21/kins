import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/models/group_chat_message.dart';
import 'package:kins_app/providers/group_chat_provider.dart';
import 'package:kins_app/repositories/group_chat_repository.dart';
import 'package:kins_app/repositories/groups_repository.dart';
import 'package:kins_app/screens/chat/group_setting_screen.dart';
import 'package:kins_app/services/firebase_chat_auth_service.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

/// Arguments for opening the group conversation screen.
class GroupConversationArgs {
  final String groupId;
  final String name;
  final String description;
  final String? imageUrl;

  const GroupConversationArgs({
    required this.groupId,
    required this.name,
    required this.description,
    this.imageUrl,
  });
}

const Color _kAppBarBg = Colors.white;
const Color _kBubbleMe = Color(0xFFE5E5EA);
const Color _kBubbleOther = Colors.white;
const Color _kInputBg = Color(0xFFE9E9EB);
const Color _kSendButtonBg = Color(0xFF007AFF);

class _SenderInfo {
  final String name;
  final String? avatarUrl;
  _SenderInfo({required this.name, this.avatarUrl});
}

/// Group chat screen: header (avatar, name, description, Report, more), message list, input bar.
class GroupConversationScreen extends ConsumerStatefulWidget {
  final GroupConversationArgs args;

  const GroupConversationScreen({super.key, required this.args});

  @override
  ConsumerState<GroupConversationScreen> createState() => _GroupConversationScreenState();
}

class _GroupConversationScreenState extends ConsumerState<GroupConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, _SenderInfo> _membersCache = {};
  bool _authReady = false;
  String? _authError;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _ensureAuthAndLoadMembers();
  }

  Future<void> _ensureAuthAndLoadMembers() async {
    try {
      await FirebaseChatAuthService.ensureFirebaseSignedIn();
      if (!mounted) return;
      setState(() {
        _authReady = true;
        _authError = null;
      });
      await _loadMembers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _authReady = true;
          _authError = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '');
        });
      }
    }
  }

  Future<void> _loadMembers() async {
    final detail = await GroupsRepository.getGroup(widget.args.groupId);
    if (!mounted || detail == null) return;
    final map = <String, _SenderInfo>{};
    for (final m in detail.members) {
      map[m.id] = _SenderInfo(name: m.name, avatarUrl: m.profilePictureUrl);
    }
    setState(() => _membersCache.addAll(map));
  }

  _SenderInfo _senderInfo(String senderId) {
    if (senderId.isEmpty) return _SenderInfo(name: 'System', avatarUrl: null);
    return _membersCache[senderId] ?? _SenderInfo(name: 'User', avatarUrl: null);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    final uid = currentUserId;
    if (uid.isEmpty) return;
    setState(() {
      _isSending = true;
      _textController.clear();
    });
    try {
      await ref.read(groupChatRepositoryProvider).sendTextMessage(
            groupId: widget.args.groupId,
            senderId: uid,
            text: text,
          );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _onAttachment() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Image'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Document'),
              onTap: () => Navigator.pop(ctx, 'doc'),
            ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    FileType fileType = FileType.image;
    if (type == 'video') fileType = FileType.video;
    if (type == 'doc') fileType = FileType.any;
    final result = await FilePicker.platform.pickFiles(type: fileType, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final platformFile = result.files.single;
    final uid = currentUserId;
    if (uid.isEmpty) return;
    if (!mounted) return;

    Uint8List? bytes = platformFile.bytes;
    String fileName = platformFile.name ?? 'image';
    String ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    if (ext.isEmpty) ext = type == 'image' ? 'jpg' : 'bin';

    if (bytes == null || bytes.isEmpty) {
      final path = platformFile.path;
      if (path == null || path.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file. Try again.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      final normalizedPath = path.startsWith('file://') ? Uri.parse(path).path : path;
      final file = File(normalizedPath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File no longer available. Pick again.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      if (fileName.isEmpty) fileName = normalizedPath.split(RegExp(r'[/\\]')).last;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Read failed: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }
    if (bytes.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File is empty.'), backgroundColor: Colors.red));
      return;
    }

    // Compress images so large photos upload quickly and don't timeout
    if (type == 'image' && bytes.length > 200 * 1024) {
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1200,
          minHeight: 1200,
          quality: 85,
          format: CompressFormat.jpeg,
        );
        if (compressed.isNotEmpty) {
          bytes = compressed;
          ext = 'jpg';
          if (kDebugMode) debugPrint('[GroupConversation] Image compressed to ${bytes.length ~/ 1024} KB');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[GroupConversation] Compression failed, uploading original: $e');
      }
    }

    setState(() => _isSending = true);
    try {
      await ref.read(groupChatRepositoryProvider).sendMediaMessageWithBytes(
            groupId: widget.args.groupId,
            senderId: uid,
            type: type,
            bytes: bytes!,
            fileName: fileName,
            ext: ext,
          ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw Exception('Upload timed out. Check your connection.'),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[GroupConversation] sendMediaMessage failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), ''),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final messagesAsync = ref.watch(groupMessagesStreamProvider(args.groupId));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, args),
      body: Column(
        children: [
          Expanded(
            child: _authError != null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _authError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _ensureAuthAndLoadMembers,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : !_authReady
                    ? const Center(child: CircularProgressIndicator())
                    : messagesAsync.when(
                        data: (messages) {
                          if (messages.isEmpty) {
                            return Center(
                              child: Text(
                                'No messages yet. Say hi!',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: Responsive.fontSize(context, 15),
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.screenPaddingH(context),
                              vertical: Responsive.spacing(context, 12),
                            ),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              return _buildMessageWidget(context, msg, index, messages);
                            },
                          );
                        },
                        loading: () => const SkeletonCommentList(itemCount: 6),
                        error: (e, _) => Center(
                          child: Padding(
                            padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  e.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => ref.invalidate(groupMessagesStreamProvider(args.groupId)),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildMessageWidget(
    BuildContext context,
    GroupChatMessage msg,
    int index,
    List<GroupChatMessage> all,
  ) {
    final myUid = currentUserId;
    final isMe = msg.senderId == myUid;
    final timeStr = msg.createdAt != null ? DateFormat.jm().format(msg.createdAt!) : '--:--';
    final info = _senderInfo(msg.senderId);
    // List is newest-first (reverse ListView). Show avatar on first message of each block (oldest in block = index+1 is different sender).
    final showAvatar = index == all.length - 1 ||
        (index < all.length - 1 && all[index + 1].senderId != msg.senderId);

    if (msg.type == GroupChatMessageType.system) {
      return _SystemBubble(text: msg.content ?? '');
    }
    if (msg.type == GroupChatMessageType.image || msg.type == GroupChatMessageType.video) {
      final url = msg.mediaUrl ?? '';
      return _GroupMediaBubble(
        mediaUrl: url,
        type: msg.type,
        senderName: info.name,
        time: timeStr,
        avatarUrl: info.avatarUrl,
        isMe: isMe,
      );
    }
    if (msg.type == GroupChatMessageType.doc) {
      return _GroupDocBubble(
        mediaUrl: msg.mediaUrl,
        fileName: msg.fileName ?? 'Document',
        senderName: info.name,
        time: timeStr,
        avatarUrl: info.avatarUrl,
        isMe: isMe,
        showAvatar: showAvatar,
      );
    }
    return _GroupMessageBubble(
      senderName: info.name,
      text: msg.content ?? '',
      isMe: isMe,
      time: timeStr,
      showStatus: isMe,
      avatarUrl: info.avatarUrl,
      showAvatar: showAvatar,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, GroupConversationArgs args) {
    return AppBar(
      backgroundColor: _kAppBarBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
        onPressed: () => context.pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: args.imageUrl != null && args.imageUrl!.isNotEmpty
                ? NetworkImage(args.imageUrl!)
                : null,
            child: args.imageUrl == null || args.imageUrl!.isEmpty
                ? Icon(Icons.group, color: Colors.grey.shade600, size: 26)
                : null,
          ),
          SizedBox(width: Responsive.spacing(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  args.name,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 17),
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  args.description,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {},
          child: Text(
            'Report',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 15),
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
          onSelected: (value) {
            if (value == 'settings') {
              context.push(
                AppConstants.routeGroupSettings,
                extra: GroupSettingArgs(
                  groupId: args.groupId,
                  name: args.name,
                  description: args.description,
                  members: 0,
                  imageUrl: args.imageUrl,
                ),
              );
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'settings', child: Text('Group settings')),
            const PopupMenuItem(value: 'mute', child: Text('Mute')),
          ],
        ),
      ],
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Responsive.spacing(context, 8),
        Responsive.spacing(context, 8),
        Responsive.spacing(context, 8),
        Responsive.spacing(context, 8) + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: _kAppBarBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey.shade600, size: 26),
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kInputBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _textController,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    color: Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                ),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.grey.shade600, size: 24),
            onPressed: _isSending ? null : _onAttachment,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isSending ? null : _onSend,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: _kSendButtonBg,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupMessageBubble extends StatelessWidget {
  final String senderName;
  final String text;
  final bool isMe;
  final String time;
  final bool showStatus;
  final String? avatarUrl;
  final bool showAvatar;

  const _GroupMessageBubble({
    required this.senderName,
    required this.text,
    required this.isMe,
    required this.time,
    this.showStatus = false,
    this.avatarUrl,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? _kBubbleMe : _kBubbleOther;
    final maxW = MediaQuery.sizeOf(context).width * 0.75;

    Widget bubble = Container(
      margin: EdgeInsets.only(bottom: Responsive.spacing(context, 6)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 12),
        vertical: Responsive.spacing(context, 8),
      ),
      constraints: BoxConstraints(maxWidth: maxW),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            text,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 15),
              color: Colors.black87,
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 4)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 11),
                  color: Colors.grey.shade600,
                ),
              ),
              if (isMe && showStatus) ...[
                const SizedBox(width: 4),
                Icon(Icons.done_all, size: 16, color: Colors.grey.shade600),
              ],
            ],
          ),
        ],
      ),
    );

    if (isMe) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.spacing(context, 6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAvatar)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Icon(Icons.person, size: 18, color: Colors.grey.shade600)
                    : null,
              ),
            )
          else
            const SizedBox(width: 40),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                bubble,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupMediaBubble extends StatelessWidget {
  final String mediaUrl;
  final GroupChatMessageType type;
  final String senderName;
  final String time;
  final String? avatarUrl;
  final bool isMe;

  const _GroupMediaBubble({
    required this.mediaUrl,
    required this.type,
    required this.senderName,
    required this.time,
    this.avatarUrl,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.8;
    final isVideo = type == GroupChatMessageType.video;
    Widget mediaContent = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: 220),
        color: Colors.grey.shade200,
        child: isVideo
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: maxW,
                    height: 200,
                    color: Colors.grey.shade300,
                    child: Icon(Icons.videocam, size: 48, color: Colors.grey.shade500),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                  ),
                ],
              )
            : Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                width: maxW,
                height: 200,
                errorBuilder: (_, __, ___) => Container(
                  width: maxW,
                  height: 200,
                  color: Colors.grey.shade300,
                  child: Icon(Icons.image, size: 48, color: Colors.grey.shade500),
                ),
              ),
      ),
    );
    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            mediaContent,
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.spacing(context, 6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Icon(Icons.person, size: 18, color: Colors.grey.shade600)
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                senderName,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 13),
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              mediaContent,
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 11),
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupDocBubble extends StatelessWidget {
  final String? mediaUrl;
  final String fileName;
  final String senderName;
  final String time;
  final String? avatarUrl;
  final bool isMe;
  final bool showAvatar;

  const _GroupDocBubble({
    this.mediaUrl,
    required this.fileName,
    required this.senderName,
    required this.time,
    this.avatarUrl,
    this.isMe = false,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.75;
    final bubbleColor = isMe ? _kBubbleMe : _kBubbleOther;
    Widget docBubble = Container(
      margin: EdgeInsets.only(bottom: Responsive.spacing(context, 6)),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 12),
        vertical: Responsive.spacing(context, 10),
      ),
      constraints: BoxConstraints(maxWidth: maxW),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, size: 32, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 11),
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (isMe) {
      return Align(alignment: Alignment.centerRight, child: docBubble);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.spacing(context, 6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAvatar)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Icon(Icons.person, size: 18, color: Colors.grey.shade600)
                    : null,
              ),
            )
          else
            const SizedBox(width: 40),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                docBubble,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  final String text;

  const _SystemBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 8)),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.spacing(context, 12),
          vertical: Responsive.spacing(context, 6),
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 12),
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
