import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kins_app/providers/user_details_provider.dart';

/// Edit tags: country/city dropdowns, tags section (add/remove).
class EditTagsScreen extends ConsumerStatefulWidget {
  const EditTagsScreen({super.key});

  @override
  ConsumerState<EditTagsScreen> createState() => _EditTagsScreenState();
}

class _EditTagsScreenState extends ConsumerState<EditTagsScreen> {
  String _country = 'UAE';
  String _city = 'Dubai';
  List<String> _tags = [];
  String? _userName;
  String? _profilePhotoUrl;
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
            Wrap(spacing: 8, runSpacing: 8, children: _tags.map((t) => Chip(label: Text(t), onDeleted: () => _removeTag(t))).toList()),
            const SizedBox(height: 24),
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Bio',
                hintText: 'A short bio about you',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _country,
              decoration: InputDecoration(
                labelText: 'Country of residence',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ['UAE', 'Saudi Arabia', 'Kuwait', 'Qatar', 'Bahrain', 'Oman']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _country = v ?? _country),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _city,
              decoration: InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ['Dubai', 'Abu Dhabi', 'Sharjah', 'Riyadh', 'Jeddah', 'Doha', 'Kuwait City']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _city = v ?? _city),
            ),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._tags.map((t) => Chip(
                    label: Text(t),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeTag(t),
                  )),
                  InputChip(
                    label: const Text('Lorem'),
                    avatar: const Icon(Icons.add, size: 18),
                    onPressed: () => _addTag(),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4C93),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
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
          decoration: const InputDecoration(hintText: 'Tag name'),
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
