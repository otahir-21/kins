import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/responsive/responsive.dart';

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

  /// Mock members for UI (first is "You", rest have menu or checkmark).
  final List<Map<String, dynamic>> _members = [
    {'name': 'Andrea AMA', 'isYou': true},
    {'name': 'Andrea AMA', 'isYou': false},
    {'name': 'Andrea AMA', 'isYou': false},
    {'name': 'Andrea AMA', 'isYou': false, 'showCheck': true},
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.args;
    _nameController = TextEditingController(text: a?.name ?? '');
    _descriptionController = TextEditingController(text: a?.description ?? '');
    _pickedImageFile = a?.imageFile;
    _isUpdatesOnly = true;
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
              SizedBox(height: Responsive.spacing(context, 24)),
            ],
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
        GestureDetector(
          onTap: () {},
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

  Widget _buildMemberList(BuildContext context) {
    return Column(
      children: List.generate(_members.length, (i) {
        final m = _members[i] as Map<String, dynamic>;
        final name = m['name'] as String? ?? 'Member';
        final isYou = m['isYou'] as bool? ?? false;
        final showCheck = m['showCheck'] as bool? ?? false;
        return Padding(
          padding: EdgeInsets.only(bottom: Responsive.spacing(context, 12)),
          child: Row(
            children: [
              CircleAvatar(
                radius: Responsive.scale(context, 22),
                backgroundColor: const Color(0xFF6B4C93).withOpacity(0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C93),
                  ),
                ),
              ),
              SizedBox(width: Responsive.spacing(context, 12)),
              Expanded(
                child: Text(
                  name,
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
              else if (showCheck)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.spacing(context, 12),
                    vertical: Responsive.spacing(context, 6),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(Responsive.scale(context, 16)),
                  ),
                  child: Icon(Icons.check, size: Responsive.scale(context, 18), color: Colors.grey.shade700),
                )
              else
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600, size: Responsive.scale(context, 22)),
                  onPressed: () => _showMemberMenu(context, name),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        );
      }),
    );
  }
}
