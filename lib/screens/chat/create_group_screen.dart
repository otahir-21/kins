import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/repositories/groups_repository.dart';
import 'package:kins_app/screens/chat/group_setting_screen.dart';

/// Create group screen: circular image, group type (Interactive / Updates only),
/// group name, description, and submit button. Responsive layout.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  static const Color _inputBg = Color(0xFFE8E8E8);
  static const Color _groupTypeSelected = Color(0xFF7A084D);

  File? _pickedImageFile;
  bool _isUpdatesOnly = true; // "Updates only" selected by default
  bool _submitting = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

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

  Future<void> _onSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group name')),
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final type = _isUpdatesOnly ? 'updates_only' : 'interactive';
      final description = _descriptionController.text.trim();
      final created = await GroupsRepository.createGroup(
        name: name,
        type: type,
        description: description,
        image: _pickedImageFile,
      );
      if (!mounted) return;
      context.pop();
      context.push(
        AppConstants.routeGroupSettings,
        extra: GroupSettingArgs(
          groupId: created.id,
          name: created.name,
          description: created.description,
          members: created.memberCount,
          imageUrl: created.imageUrl,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
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

  @override
  Widget build(BuildContext context) {
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
          'Create group',
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
              SizedBox(height: Responsive.spacing(context, 24)),
              _buildGroupImage(context),
              SizedBox(height: Responsive.spacing(context, 28)),
              _buildGroupType(context),
              SizedBox(height: Responsive.spacing(context, 24)),
              _buildGroupNameField(context),
              SizedBox(height: Responsive.spacing(context, 16)),
              _buildDescriptionField(context),
              SizedBox(height: Responsive.spacing(context, 32)),
              _buildSubmitButton(context),
              SizedBox(height: Responsive.spacing(context, 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupImage(BuildContext context) {
    final size = Responsive.scale(context, 150);
    final editSize = Responsive.scale(context, 36);
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: _pickedImageFile != null
                ? Image.file(
                    _pickedImageFile!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: size,
                    height: size,
                    color: const Color(0xFF6B4C93).withOpacity(0.15),
                    child: Icon(
                      Icons.group,
                      size: Responsive.scale(context, 56),
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
    );
  }

  Widget _buildGroupType(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group type',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 12)),
        Row(
          children: [
            _buildGroupTypeOption(
              context,
              label: 'Interactive',
              selected: !_isUpdatesOnly,
              onTap: () => setState(() => _isUpdatesOnly = false),
            ),
            SizedBox(width: Responsive.spacing(context, 24)),
            _buildGroupTypeOption(
              context,
              label: 'Updates only',
              selected: _isUpdatesOnly,
              onTap: () => setState(() => _isUpdatesOnly = true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupTypeOption(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 15),
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: 'Group name',
          hintStyle: TextStyle(
            fontSize: Responsive.fontSize(context, 15),
            color: Colors.grey.shade600,
          ),
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
      constraints: BoxConstraints(minHeight: Responsive.scale(context, 120)),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(Responsive.scale(context, 24)),
      ),
      child: TextField(
        controller: _descriptionController,
        maxLines: 4,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 15),
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: 'Description...',
          hintStyle: TextStyle(
            fontSize: Responsive.fontSize(context, 15),
            color: Colors.grey.shade600,
          ),
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

  Widget _buildSubmitButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _submitting ? null : _onSubmit,
          borderRadius: BorderRadius.circular(Responsive.scale(context, 28)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.spacing(context, 24),
              vertical: Responsive.spacing(context, 14),
            ),
            decoration: BoxDecoration(
              color: _inputBg,
              borderRadius: BorderRadius.circular(Responsive.scale(context, 28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _submitting
                ? SizedBox(
                    width: Responsive.scale(context, 28),
                    height: Responsive.scale(context, 28),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Icon(Icons.check, size: Responsive.scale(context, 28), color: Colors.black),
          ),
        ),
      ),
    );
  }
}
