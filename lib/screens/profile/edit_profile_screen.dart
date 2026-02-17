import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/models/interest_model.dart';
import 'package:kins_app/providers/edit_profile_provider.dart';
import 'package:kins_app/repositories/interest_repository.dart';

/// Edit Profile screen - optional fields, partial update via PUT /me/about.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _primaryColor = Color(0xFF6B4C93);
  static const _inputRadius = 28.0;
  static const _fieldSpacing = 16.0;
  static const _borderGrey = Color(0xFFE5E5E5);

  List<InterestModel> _allInterests = [];
  File? _pickedImageFile;

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    try {
      final list = await InterestRepository().getInterests();
      if (mounted) setState(() => _allInterests = list);
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _pickedImageFile = File(result.files.single.path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(editProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: asyncState.when(
          data: (s) => _buildContent(s),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Failed to load: $e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.read(editProfileProvider.notifier).load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(EditProfileState s) {
    final edit = s.editedUser;
    final notifier = ref.read(editProfileProvider.notifier);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
      child: Column(
        children: [
          _buildHeader(s, notifier),
          const SizedBox(height: 24),
          _buildProfileImage(edit),
          const SizedBox(height: 32),
          _buildField(
            hint: 'Full name',
            value: edit.name,
            onChanged: notifier.updateName,
            showWarning: (edit.name ?? '').trim().isEmpty,
          ),
          SizedBox(height: _fieldSpacing),
          _buildMultilineField(
            hint: 'Tell us about yourself',
            value: edit.bio,
            onChanged: notifier.updateBio,
          ),
          SizedBox(height: _fieldSpacing),
          _buildField(
            hint: 'Username',
            value: edit.username,
            onChanged: notifier.updateUsername,
            showWarning: (edit.username ?? '').trim().isEmpty,
            helper: 'Unique username',
          ),
          SizedBox(height: _fieldSpacing),
          _buildField(
            hint: 'Email',
            value: edit.email,
            onChanged: notifier.updateEmail,
            keyboard: TextInputType.emailAddress,
            showWarning: (edit.email ?? '').trim().isEmpty,
          ),
          SizedBox(height: _fieldSpacing),
          _buildField(
            hint: 'Phone',
            value: edit.phoneNumber,
            onChanged: notifier.updatePhone,
            keyboard: TextInputType.phone,
            showWarning: (edit.phoneNumber ?? '').trim().isEmpty,
          ),
          SizedBox(height: _fieldSpacing),
          _buildCountryDropdown(edit.country, notifier.updateCountry),
          SizedBox(height: _fieldSpacing),
          _buildCityDropdown(edit.city, notifier.updateCity),
          SizedBox(height: _fieldSpacing),
          _buildInterestsSection(edit, notifier),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeader(EditProfileState s, EditProfileNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
            onPressed: () => context.pop(),
          ),
          TextButton(
            onPressed: s.hasChanges && !s.isSaving
                ? () async {
                    try {
                      final ok = await notifier.save();
                      if (ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved')),
                        );
                        context.pop();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                : null,
            style: TextButton.styleFrom(
              backgroundColor: s.hasChanges && !s.isSaving ? _primaryColor : Colors.grey.shade300,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: s.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(EditProfileData edit) {
    final url = _pickedImageFile != null ? null : edit.profilePictureUrl;
    final hasImage = url != null && url.isNotEmpty;

    return GestureDetector(
      onTap: _pickImage,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: _primaryColor.withOpacity(0.2),
              backgroundImage: hasImage ? NetworkImage(url) : null,
              child: hasImage
                  ? null
                  : _pickedImageFile != null
                      ? ClipOval(
                          child: Image.file(_pickedImageFile!, width: 100, height: 100, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.person, color: _primaryColor, size: 48),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String hint,
    String? value,
    required ValueChanged<String> onChanged,
    bool showWarning = false,
    String? helper,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (helper != null) ...[
          Text(helper, style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: Colors.grey.shade600)),
          const SizedBox(height: 6),
        ],
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(_inputRadius),
            border: Border.all(color: _borderGrey),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: value ?? '',
                  onChanged: onChanged,
                  keyboardType: keyboard,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: Responsive.fontSize(context, 16), color: Colors.grey.shade600),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              if (showWarning)
                Icon(Icons.info_outline, size: 20, color: Colors.grey.shade500),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultilineField({
    required String hint,
    String? value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_inputRadius),
        border: Border.all(color: _borderGrey),
      ),
      child: TextFormField(
        initialValue: value ?? '',
        onChanged: onChanged,
        maxLines: 3,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 16),
          fontWeight: FontWeight.w400,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: Responsive.fontSize(context, 16), color: Colors.grey.shade600),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildCountryDropdown(String? value, ValueChanged<String?> onChanged) {
    const countries = [
      'United Arab Emirates', 'United Kingdom', 'United States', 'Canada',
      'Australia', 'India', 'Pakistan', 'Saudi Arabia', 'Egypt', 'Other',
    ];
    return _buildDropdown(
      value: value,
      hint: 'Country',
      items: countries,
      onChanged: onChanged,
    );
  }

  Widget _buildCityDropdown(String? value, ValueChanged<String?> onChanged) {
    const cities = [
      'Dubai', 'Abu Dhabi', 'Sharjah', 'London', 'New York', 'Toronto',
      'Sydney', 'Mumbai', 'Karachi', 'Riyadh', 'Cairo', 'Other',
    ];
    return _buildDropdown(
      value: value,
      hint: 'City',
      items: cities,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final v = (value != null && value.trim().isNotEmpty) ? value.trim() : null;
    final effectiveItems = v != null && !items.contains(v) ? [v, ...items] : items;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_inputRadius),
        border: Border.all(color: _borderGrey),
      ),
      alignment: Alignment.centerLeft,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: v,
          hint: Text(hint, style: TextStyle(fontSize: Responsive.fontSize(context, 16), color: Colors.grey.shade600)),
          isExpanded: true,
          items: effectiveItems
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w400, color: Colors.black)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildInterestsSection(EditProfileData edit, EditProfileNotifier notifier) {
    final selectedIds = Set<String>.from(edit.interestIds);
    final hasSelection = selectedIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Tags (Interests)', style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
            if (!hasSelection) ...[
              const SizedBox(width: 6),
              Icon(Icons.info_outline, size: 18, color: Colors.grey.shade500),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allInterests.map((i) {
            final isSelected = selectedIds.contains(i.id);
            return GestureDetector(
              onTap: () => notifier.toggleInterest(i.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor.withOpacity(0.15) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _primaryColor : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  i.name,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    color: isSelected ? _primaryColor : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
