import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/repositories/groups_repository.dart';
import 'package:kins_app/repositories/users_repository.dart';
import 'package:kins_app/widgets/confirm_dialog.dart';

/// Data passed when opening Group Setting (from list tap or after create).
class GroupSettingArgs {
  final String groupId;
  final String name;
  final String description;
  final int members;
  final String? imageUrl;
  final File? imageFile;

  const GroupSettingArgs({
    required this.groupId,
    required this.name,
    required this.description,
    required this.members,
    this.imageUrl,
    this.imageFile,
  });
}

/// Group Setting screen: edit group image, type, name, description, and manage members.
class GroupSettingScreen extends StatefulWidget {
  final GroupSettingArgs? args;

  const GroupSettingScreen({super.key, this.args});

  @override
  State<GroupSettingScreen> createState() => _GroupSettingScreenState();
}

class _GroupSettingScreenState extends State<GroupSettingScreen> {
  static const Color _inputBg = Color(0xFFE8E8E8);
  static const Color _groupTypeSelected = Color(0xFF7A084D);

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  File? _pickedImageFile;
  bool _isUpdatesOnly = true;

  GroupDetailResponse? _groupDetail;
  List<GroupMemberInfo> _members = [];
  bool _membersLoading = true;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final a = widget.args;
    _nameController = TextEditingController(text: a?.name ?? '');
    _descriptionController = TextEditingController(text: a?.description ?? '');
    _pickedImageFile = a?.imageFile;
    _isUpdatesOnly = true;
    _loadGroupDetail();
  }

  /// GET /api/v1/groups/:groupId → group + members. Only members can open; use isAdmin for "Add people".
  Future<void> _loadGroupDetail() async {
    final groupId = widget.args?.groupId;
    if (groupId == null || groupId.isEmpty || groupId == 'new') {
      if (mounted) setState(() => _membersLoading = false);
      return;
    }
    try {
      final detail = await GroupsRepository.getGroup(groupId);
      if (mounted) {
        setState(() {
          _groupDetail = detail;
          _members = detail?.members ?? [];
          _membersLoading = false;
          if (detail != null) {
            _nameController.text = detail.name;
            _descriptionController.text = detail.description;
            _isUpdatesOnly = detail.type == 'updates_only';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _membersLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null && mounted) {
      setState(() => _pickedImageFile = File(result.files.single.path!));
    }
  }

  Future<void> _save() async {
    final groupId = widget.args?.groupId;
    if (groupId == null || groupId.isEmpty || groupId == 'new') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save: invalid group')),
      );
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group name')),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final type = _isUpdatesOnly ? 'updates_only' : 'interactive';
      final description = _descriptionController.text.trim();
      await GroupsRepository.updateGroup(
        groupId: groupId,
        name: name,
        description: description,
        type: type,
        image: _pickedImageFile,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      _loadGroupDetail();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group saved')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), ''),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteGroup() async {
    final groupId = widget.args?.groupId;
    if (groupId == null || groupId.isEmpty || groupId == 'new') return;
    if (!(_groupDetail?.isAdmin ?? false)) return;
    final confirm = await showConfirmDialog<bool>(
      context: context,
      title: 'Delete group',
      message: 'Delete this group? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await GroupsRepository.deleteGroup(groupId);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), ''),
            ),
          ),
        );
      }
    }
  }

  void _showMemberMenu(BuildContext context, String memberName) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: const Text('Remove'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Make Admin'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final imageUrl = args?.imageUrl;
    final hasImage = _pickedImageFile != null || (imageUrl != null && imageUrl.isNotEmpty);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Group Setting',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 20),
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          if (widget.args?.groupId != null &&
              widget.args!.groupId.isNotEmpty &&
              widget.args!.groupId != 'new')
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _groupTypeSelected,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: _groupTypeSelected,
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: Responsive.spacing(context, 20)),
              _buildTopRow(context, hasImage: hasImage, imageUrl: imageUrl),
              SizedBox(height: Responsive.spacing(context, 24)),
              _buildGroupNameField(context),
              SizedBox(height: Responsive.spacing(context, 16)),
              _buildDescriptionField(context),
              SizedBox(height: Responsive.spacing(context, 28)),
              _buildGroupMembersHeader(context),
              SizedBox(height: Responsive.spacing(context, 12)),
              _buildMemberList(context),
              SizedBox(height: Responsive.spacing(context, 32)),
              _buildDeleteButton(context),
              SizedBox(height: Responsive.spacing(context, 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    final canDelete = widget.args?.groupId != null &&
        widget.args!.groupId.isNotEmpty &&
        widget.args!.groupId != 'new' &&
        (_groupDetail?.isAdmin ?? false);
    if (!canDelete) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _deleting ? null : _deleteGroup,
        icon: _deleting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red.shade700,
                ),
              )
            : Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
        label: Text(
          _deleting ? 'Deleting...' : 'Delete group',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            color: Colors.red.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, {required bool hasImage, String? imageUrl}) {
    final imageSize = Responsive.scale(context, 120);
    final editSize = Responsive.scale(context, 36);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: _pickedImageFile != null
                  ? Image.file(
                      _pickedImageFile!,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                    )
                  : (imageUrl != null && imageUrl.isNotEmpty)
                      ? Image.network(
                          imageUrl,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: imageSize,
                          height: imageSize,
                          color: const Color(0xFF6B4C93).withOpacity(0.15),
                          child: Icon(
                            Icons.group,
                            size: Responsive.scale(context, 48),
                            color: const Color(0xFF6B4C93),
                          ),
                        ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: editSize,
                  height: editSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade300,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.edit, size: Responsive.scale(context, 18), color: Colors.grey.shade700),
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: Responsive.spacing(context, 20)),
        Expanded(child: _buildGroupType(context)),
      ],
    );
  }

  Widget _buildGroupType(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Group type',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 6)),
            Icon(Icons.lock_outline, size: Responsive.scale(context, 16), color: Colors.grey.shade600),
          ],
        ),
        SizedBox(height: Responsive.spacing(context, 12)),
        _buildGroupTypeOption(context, label: 'Interactive', selected: !_isUpdatesOnly, onTap: () => setState(() => _isUpdatesOnly = false)),
        SizedBox(height: Responsive.spacing(context, 8)),
        _buildGroupTypeOption(context, label: 'Updates only', selected: _isUpdatesOnly, onTap: () => setState(() => _isUpdatesOnly = true)),
      ],
    );
  }

  Widget _buildGroupTypeOption(BuildContext context, {required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: Responsive.scale(context, 20),
            height: Responsive.scale(context, 20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? _groupTypeSelected : Colors.grey.shade400,
            ),
          ),
          SizedBox(width: Responsive.spacing(context, 8)),
          Text(
            label,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 15),
              fontWeight: FontWeight.w400,
              color: selected ? Colors.black : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNameField(BuildContext context) {
    return Container(
      height: Responsive.scale(context, 48),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(Responsive.scale(context, 24)),
      ),
      child: TextField(
        controller: _nameController,
        style: TextStyle(fontSize: Responsive.fontSize(context, 15), color: Colors.black),
        decoration: InputDecoration(
          hintText: 'The Social Club',
          hintStyle: TextStyle(fontSize: Responsive.fontSize(context, 15), color: Colors.grey.shade600),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, 20),
            vertical: Responsive.spacing(context, 14),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionField(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: Responsive.scale(context, 100)),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(Responsive.scale(context, 24)),
      ),
      child: TextField(
        controller: _descriptionController,
        maxLines: 4,
        style: TextStyle(fontSize: Responsive.fontSize(context, 15), color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Description...',
          hintStyle: TextStyle(fontSize: Responsive.fontSize(context, 15), color: Colors.grey.shade600),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, 20),
            vertical: Responsive.spacing(context, 14),
          ),
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _buildGroupMembersHeader(BuildContext context) {
    final groupId = widget.args?.groupId;
    final canAdd = groupId != null && groupId.isNotEmpty && groupId != 'new' && (_groupDetail?.isAdmin ?? false);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Group Members',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 18),
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        if (canAdd)
          GestureDetector(
            onTap: () => _openAddMembersSheet(context),
            child: Container(
              width: Responsive.scale(context, 36),
              height: Responsive.scale(context, 36),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: Icon(Icons.add, size: Responsive.scale(context, 22), color: Colors.grey.shade700),
            ),
          ),
      ],
    );
  }

  void _openAddMembersSheet(BuildContext context) {
    final groupId = widget.args?.groupId;
    if (groupId == null || groupId.isEmpty || groupId == 'new') return;
    final existingIds = _members.map((m) => m.id).toSet();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) => Material(
        color: Colors.white,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => _AddMembersSheetContent(
          groupId: groupId,
          existingMemberIds: existingIds,
          scrollController: scrollController,
          onMemberAdded: (member) {
            setState(() => _members = [..._members, member]);
          },
          onClose: () => Navigator.pop(ctx),
        ),
        ),
      ),
    ).then((_) => _loadGroupDetail());
  }

  Widget _buildMemberList(BuildContext context) {
    final myId = currentUserId;
    if (_membersLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 16)),
        child: Center(
          child: SizedBox(
            width: Responsive.scale(context, 24),
            height: Responsive.scale(context, 24),
            child: CircularProgressIndicator(strokeWidth: 2, color: _groupTypeSelected),
          ),
        ),
      );
    }
    if (_members.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 12)),
        child: Text(
          'No members yet. Tap + to add.',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            color: Colors.grey.shade600,
          ),
        ),
      );
    }
    return Column(
      children: _members.map((m) {
        final isYou = m.id == myId;
        return Padding(
          padding: EdgeInsets.only(bottom: Responsive.spacing(context, 12)),
          child: Row(
            children: [
              CircleAvatar(
                radius: Responsive.scale(context, 22),
                backgroundColor: const Color(0xFF6B4C93).withOpacity(0.2),
                backgroundImage: m.profilePictureUrl != null && m.profilePictureUrl!.isNotEmpty
                    ? NetworkImage(m.profilePictureUrl!)
                    : null,
                child: m.profilePictureUrl == null || m.profilePictureUrl!.isEmpty
                    ? Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 16),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B4C93),
                        ),
                      )
                    : null,
              ),
              SizedBox(width: Responsive.spacing(context, 12)),
              Expanded(
                child: Text(
                  m.name,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              if (isYou)
                Text(
                  'You',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    color: Colors.grey.shade600,
                  ),
                )
              else
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600, size: Responsive.scale(context, 22)),
                  onPressed: () => _showMemberMenu(context, m.name),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Bottom sheet content: list all users with Add button per row.
class _AddMembersSheetContent extends StatefulWidget {
  final String groupId;
  final Set<String> existingMemberIds;
  final ScrollController scrollController;
  final void Function(GroupMemberInfo) onMemberAdded;
  final VoidCallback onClose;

  const _AddMembersSheetContent({
    required this.groupId,
    required this.existingMemberIds,
    required this.scrollController,
    required this.onMemberAdded,
    required this.onClose,
  });

  @override
  State<_AddMembersSheetContent> createState() => _AddMembersSheetContentState();
}

class _AddMembersSheetContentState extends State<_AddMembersSheetContent> {
  List<UserListItem> _users = [];
  bool _loading = true;
  final Set<String> _addedIds = {};
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialUsers());
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _searchUsers(_searchController.text);
    });
  }

  /// Initial load: try GET /users then GET /users/search so list shows as soon as dialog opens.
  Future<void> _loadInitialUsers() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final list = await UsersRepository.getUsersForAddMember();
    if (!mounted) return;
    setState(() {
      _users = list;
      _loading = false;
    });
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;
    setState(() => _loading = true);
    final list = await UsersRepository.searchUsers(query);
    if (!mounted) return;
    setState(() {
      _users = list;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addUser(UserListItem user) async {
    if (_addedIds.contains(user.id)) return;
    try {
      await GroupsRepository.addGroupMembers(widget.groupId, [user.id]);
      if (!mounted) return;
      setState(() => _addedIds.add(user.id));
      widget.onMemberAdded(GroupMemberInfo(
        id: user.id,
        name: user.name,
        profilePictureUrl: user.profilePictureUrl,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${user.name}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = (String id) => !widget.existingMemberIds.contains(id) && !_addedIds.contains(id);
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.screenPaddingH(context),
            vertical: Responsive.spacing(context, 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add members',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
          child: TextField(
            controller: _searchController,
            style: TextStyle(backgroundColor: Colors.white, color: Colors.black),
            decoration: InputDecoration(
              fillColor: Colors.white,
              filled: true,
              hintText: 'Search users...',
              prefixIcon: Icon(Icons.search, size: Responsive.scale(context, 22), color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            onChanged: (_) {},
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 8)),
        Expanded(
          child: Container(
            color: Colors.white,
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: _groupTypeSelected),
                  )
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'Type to search for users',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: widget.scrollController,
                        padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                    final user = _users[index];
                    final showAdd = canAdd(user.id);
                    return Padding(
                      padding: EdgeInsets.only(bottom: Responsive.spacing(context, 8)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: Responsive.scale(context, 24),
                            backgroundColor: const Color(0xFF6B4C93).withOpacity(0.2),
                            backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                                ? NetworkImage(user.profilePictureUrl!)
                                : null,
                            child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                                ? Text(
                                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 18),
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6B4C93),
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(width: Responsive.spacing(context, 12)),
                          Expanded(
                            child: Text(
                              user.name,
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 16),
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (showAdd)
                            TextButton(
                              onPressed: () => _addUser(user),
                              child: const Text('Add'),
                            )
                          else
                            Text(
                              _addedIds.contains(user.id) ? 'Added' : 'In group',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 14),
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    );
                        },
                      ),
          ),
        ),
        ],
      ),
    );
  }
}

const Color _groupTypeSelected = Color(0xFF7A084D);
