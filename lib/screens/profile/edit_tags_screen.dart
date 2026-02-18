import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/widgets/secondary_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Edit tags: country/city dropdowns, tags section (add/remove).
class EditTagsScreen extends ConsumerStatefulWidget {
  const EditTagsScreen({super.key});

  @override
  ConsumerState<EditTagsScreen> createState() => _EditTagsScreenState();
}

class _EditTagsScreenState extends ConsumerState<EditTagsScreen> {
  String _country = 'UAE';
  String _city = 'Dubai';

  static const List<String> _countries = ['UAE', 'Saudi Arabia', 'Kuwait', 'Qatar', 'Bahrain', 'Oman'];
  static const Map<String, List<String>> _countryCities = {
    'UAE': ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Ras Al Khaimah', 'Fujairah', 'Umm Al Quwain'],
    'Saudi Arabia': ['Riyadh', 'Jeddah', 'Dammam', 'Mecca', 'Medina', 'Khobar'],
    'Kuwait': ['Kuwait City', 'Hawally', 'Ahmadi', 'Jahra', 'Farwaniya'],
    'Qatar': ['Doha', 'Al Wakrah', 'Al Rayyan', 'Umm Salal'],
    'Bahrain': ['Manama', 'Muharraq', 'Riffa', 'Hamad Town'],
    'Oman': ['Muscat', 'Salalah', 'Sohar', 'Nizwa', 'Sur'],
  };

  List<String> _citiesForCountry(String country) => _countryCities[country] ?? [];

  List<String> _tags = [];
  String? _userName;
  String? _profilePhotoUrl;
  bool _isSaving = false;
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _tagsExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final uid = currentUserId.isNotEmpty ? currentUserId : null;
    if (uid == null) return;
    try {
      final userRepo = ref.read(userDetailsRepositoryProvider);
      final user = await userRepo.getUserDetails(uid);
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      final location = data?['location'] as Map<String, dynamic>?;
      final interests = data?['interests'] as List<dynamic>?;
      if (mounted) {
        final bio = data?['bio'] is String ? data!['bio'] as String? : null;
        setState(() {
          _userName = user?.name ?? data?['name'] ?? 'User';
          _profilePhotoUrl = user?.profilePictureUrl ?? data?['profilePictureUrl']?.toString();
          _country = location?['country'] ?? 'UAE';
          _city = location?['city'] ?? 'Dubai';
          _tags = interests != null ? interests.map((e) => e.toString()).where((s) => s.isNotEmpty).toList() : ['Lorem'];
        });
        _bioController.text = bio ?? '';
      }
    } catch (_) {
      if (mounted) setState(() => _tags = ['Lorem']);
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
        title: const Text('Edit tags', style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.spacing(context, 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF6B4C93).withOpacity(0.2),
                  backgroundImage: _profilePhotoUrl != null ? NetworkImage(_profilePhotoUrl!) : null,
                  child: _profilePhotoUrl == null ? const Icon(Icons.person, color: Color(0xFF6B4C93)) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName ?? 'User', style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('120 Followers · 20 Following · 8 Posts · 2 Reposts', style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTagsRow(context),
            const SizedBox(height: 24),
            TextField(
              controller: _bioController,
              maxLines: 3,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Bio',
                labelStyle: TextStyle(fontSize: Responsive.fontSize(context, 14), color: Colors.grey.shade600),
                hintText: 'A short bio about you',
                hintStyle: TextStyle(fontSize: Responsive.fontSize(context, 14), color: Colors.grey.shade600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            _buildPickerField(context, 'Country of residence', _country, _countries, (v) => setState(() {
              _country = v;
              _city = _citiesForCountry(v).isNotEmpty ? _citiesForCountry(v).first : '';
            })),
            const SizedBox(height: 16),
            _buildPickerField(context, 'City', _city, _citiesForCountry(_country), (v) => setState(() => _city = v), hintWhenEmpty: 'Select country first'),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => setState(() => _tagsExpanded = !_tagsExpanded),
              child: Row(
                children: [
                  Text('Tags', style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(_tagsExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (_tagsExpanded) ...[
              const SizedBox(height: 12),
              _buildTagsRow(context),
            ],
            const SizedBox(height: 32),
            SecondaryButton(
              onPressed: _isSaving ? null : () async {
                setState(() => _isSaving = true);
                await _save();
                if (mounted) setState(() => _isSaving = false);
              },
              label: 'Save',
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }

  /// LinkedIn-style tag pills: white bg, grey border, grey text; Add pill uses primary for accent.
  static const double _chipRadius = 20;
  static const Color _chipPrimary = Color(0xFF7a084e);

  Widget _buildTagsRow(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: _tags.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == _tags.length) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _addTag,
                borderRadius: BorderRadius.circular(_chipRadius),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_chipRadius),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          fontWeight: FontWeight.w500,
                          color: _chipPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.add, size: 14, color: _chipPrimary),
                    ],
                  ),
                ),
              ),
            );
          }
          final tag = _tags[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _removeTag(tag),
              borderRadius: BorderRadius.circular(_chipRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_chipRadius),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.close, size: 14, color: _chipPrimary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPickerField(BuildContext context, String label, String value, List<String> options, ValueChanged<String> onSelected, {String? hintWhenEmpty}) {
    final isEmpty = options.isEmpty;
    final displayText = value.isNotEmpty ? value : (hintWhenEmpty ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label, style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          ),
        GestureDetector(
          onTap: isEmpty ? null : () => _showPickerBottomSheet(context, label, options, onSelected),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 16), vertical: Responsive.spacing(context, 14)),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      fontWeight: FontWeight.w400,
                      color: value.isNotEmpty ? Colors.black : Colors.grey.shade600,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, size: 24, color: isEmpty ? Colors.grey.shade400 : Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
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
                      onTap: () {
                        onSelected(s);
                        Navigator.of(ctx).pop();
                      },
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

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _addTag() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add tag'),
        content: TextField(
          controller: _tagController,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Tag name',
            hintStyle: TextStyle(fontSize: Responsive.fontSize(context, 14), color: Colors.grey.shade600),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final t = _tagController.text.trim();
              if (t.isNotEmpty) {
                setState(() => _tags.add(t));
                _tagController.clear();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final uid = currentUserId.isNotEmpty ? currentUserId : null;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'location': {'country': _country, 'city': _city},
        'interests': _tags,
        'bio': _bioController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
