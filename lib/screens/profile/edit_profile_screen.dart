import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/models/interest_model.dart';
import 'package:kins_app/providers/edit_profile_provider.dart';
import 'package:kins_app/repositories/interest_repository.dart';
import 'package:kins_app/widgets/interest_chips_scrollable.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

/// Edit Profile screen - optional fields, partial update via PUT /me/about.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _primaryColor = Color(0xFF6B4C93);
  static const _textGrey = Color(0xFF8E8E93);
  static const _inputRadius = 28.0;
  static const _fieldSpacing = 16.0;
  static const _borderGrey = Color(0xFFE5E5E5);

  List<InterestModel> _allInterests = [];
  File? _pickedImageFile;
  final TextEditingController _interestSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  @override
  void dispose() {
    _interestSearchController.dispose();
    super.dispose();
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
          loading: () => const SkeletonSettings(),
          error: (e, _) => Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Failed to load: $e',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
                  ),
                  SizedBox(height: Responsive.spacing(context, 16)),
                  TextButton(
                    onPressed: () => ref.read(editProfileProvider.notifier).load(),
                    child: Text('Retry', style: TextStyle(fontSize: Responsive.fontSize(context, 16))),
                  ),
                ],
              ),
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
          SizedBox(height: Responsive.spacing(context, 24)),
          _buildProfileImage(edit),
          SizedBox(height: Responsive.spacing(context, 32)),
          _buildField(
            hint: 'Full name',
            value: edit.name,
            onChanged: notifier.updateName,
            showWarning: (edit.name ?? '').trim().isEmpty,
          ),
          SizedBox(height: Responsive.spacing(context, _fieldSpacing)),
          _buildMultilineField(
            hint: 'Tell us about yourself',
            value: edit.bio,
            onChanged: notifier.updateBio,
          ),
          SizedBox(height: Responsive.spacing(context, _fieldSpacing)),
          _buildField(
            hint: 'Username',
            value: edit.username,
            onChanged: notifier.updateUsername,
            showWarning: (edit.username ?? '').trim().isEmpty,
            helper: 'Unique username',
          ),
          SizedBox(height: Responsive.spacing(context, _fieldSpacing)),
          _buildField(
            hint: 'Email',
            value: edit.email,
            onChanged: notifier.updateEmail,
            keyboard: TextInputType.emailAddress,
            showWarning: (edit.email ?? '').trim().isEmpty,
          ),
          SizedBox(height: Responsive.spacing(context, _fieldSpacing)),
          _buildField(
            hint: 'Phone',
            value: edit.phoneNumber,
            onChanged: notifier.updatePhone,
            keyboard: TextInputType.phone,
            showWarning: (edit.phoneNumber ?? '').trim().isEmpty,
          ),
          SizedBox(height: Responsive.spacing(context, _fieldSpacing)),
          _buildCountryDropdown(edit.country, (s) {
            notifier.updateCountry(s);
            notifier.updateCity(null);
          }),
          SizedBox(height: Responsive.spacing(context, _fieldSpacing)),
          _buildCityDropdown(edit.city, edit.country, notifier.updateCity),
          SizedBox(height: Responsive.spacing(context, _fieldSpacing)),
          _buildInterestsSection(edit, notifier),
          SizedBox(height: Responsive.spacing(context, 48)),
        ],
      ),
    );
  }

  Widget _buildHeader(EditProfileState s, EditProfileNotifier notifier) {
    return Padding(
      padding: EdgeInsets.only(top: Responsive.spacing(context, 12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black, size: Responsive.fontSize(context, 22)),
            onPressed: () => context.pop(),
          ),
          ElevatedButton(
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
            child: s.isSaving
                ? const SkeletonInline(size: 20)
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: hasImage ? NetworkImage(url!) : null,
                child: hasImage
                    ? null
                    : _pickedImageFile != null
                        ? ClipOval(
                            child: Image.file(_pickedImageFile!, width: 72, height: 72, fit: BoxFit.cover),
                          )
                        : Icon(Icons.person, color: _textGrey, size: 34),
              ),
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
          SizedBox(height: Responsive.spacing(context, 6)),
        ],
        Container(
          height: Responsive.spacing(context, 56),
          padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 16)),
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
                    fontSize: Responsive.fontSize(context, 14),
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: Responsive.fontSize(context, 14), color: Colors.grey.shade600),
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
                Icon(Icons.info_outline, size: Responsive.fontSize(context, 20), color: Colors.grey.shade500),
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
      padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 16), vertical: Responsive.spacing(context, 14)),
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
          fontSize: Responsive.fontSize(context, 14),
          fontWeight: FontWeight.w400,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: Responsive.fontSize(context, 14), color: Colors.grey.shade600),
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

  static const Map<String, List<String>> _countryCities = {
    'United Arab Emirates': ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Ras Al Khaimah', 'Fujairah', 'Other'],
    'United Kingdom': ['London', 'Manchester', 'Birmingham', 'Leeds', 'Other'],
    'United States': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Other'],
    'Canada': ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Other'],
    'Australia': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Other'],
    'India': ['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Other'],
    'Pakistan': ['Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Other'],
    'Saudi Arabia': ['Riyadh', 'Jeddah', 'Dammam', 'Mecca', 'Medina', 'Other'],
    'Egypt': ['Cairo', 'Alexandria', 'Giza', 'Other'],
    'Other': ['Other'],
  };

  static List<String> get _countries => _countryCities.keys.toList();

  Widget _buildCountryDropdown(String? value, ValueChanged<String?> onChanged) {
    return _buildDropdown(
      value: value,
      hint: 'Country',
      items: _countries,
      onChanged: onChanged,
    );
  }

  Widget _buildCityDropdown(String? value, String? selectedCountry, ValueChanged<String?> onChanged) {
    final cities = (selectedCountry != null && selectedCountry.trim().isNotEmpty)
        ? (_countryCities[selectedCountry.trim()] ?? <String>[])
        : <String>[];
    return _buildDropdown(
      value: value,
      hint: selectedCountry == null || selectedCountry.trim().isEmpty ? 'Select country first' : 'City',
      items: cities,
      onChanged: cities.isEmpty ? (_) {} : onChanged,
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
    final canTap = effectiveItems.isNotEmpty;
    return GestureDetector(
      onTap: canTap
          ? () => _showPickerBottomSheet(context, hint, effectiveItems, (s) {
                onChanged(s);
                Navigator.of(context).pop();
              })
          : null,
      child: Container(
        height: Responsive.spacing(context, 56),
        padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 16)),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(_inputRadius),
          border: Border.all(color: _borderGrey),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                v ?? hint,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w400,
                  color: v != null ? Colors.black : Colors.grey.shade600,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 24, color: canTap ? Colors.grey.shade600 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showPickerBottomSheet(BuildContext context, String title, List<String> items, ValueChanged<String> onSelected) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                child: Text(title, style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600, color: Colors.black)),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final s = items[i];
                    return ListTile(
                      title: Text(s, style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: Colors.black)),
                      onTap: () => onSelected(s),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterestsSection(EditProfileData edit, EditProfileNotifier notifier) {
    final selectedIds = Set<String>.from(edit.interestIds);
    final hasSelection = selectedIds.isNotEmpty;
    final query = _interestSearchController.text.trim().toLowerCase();
    final filteredInterests = query.isEmpty
        ? _allInterests
        : _allInterests.where((i) => i.name.toLowerCase().contains(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Tags (Interests)', style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
            if (!hasSelection) ...[
              SizedBox(width: Responsive.spacing(context, 6)),
              Icon(Icons.info_outline, size: Responsive.fontSize(context, 18), color: Colors.grey.shade500),
            ],
          ],
        ),
        SizedBox(height: Responsive.spacing(context, 12)),
        Container(
          height: 36,
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
                  controller: _interestSearchController,
                  onChanged: (_) => setState(() {}),
style: TextStyle(
          fontSize: Responsive.fontSize(context, 14),
          fontWeight: FontWeight.w400,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: 'Search interests',
          hintStyle: TextStyle(fontSize: Responsive.fontSize(context, 14), color: Colors.grey.shade600),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 12)),
        InterestChipsScrollable(
          interests: filteredInterests,
          selectedIds: selectedIds,
          onToggle: (id) => notifier.toggleInterest(id),
        ),
      ],
    );
  }
}
