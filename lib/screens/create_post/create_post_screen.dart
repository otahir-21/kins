import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/providers/post_provider.dart';
import 'package:kins_app/repositories/user_details_repository.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  PostType _postType = PostType.text;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  File? _mediaFile;
  bool _isVideo = false;
  bool _isPosting = false;
  String? _userName;
  String? _userPhotoUrl;
  final List<String> _topics = ['IVF', 'Sleep', 'Teething', 'Lorem', 'Pregnancy', 'Newborn', 'Toddler'];
  final Set<String> _selectedTopics = {};

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _textController.dispose();
    _pollQuestionController.dispose();
    for (final c in _pollOptionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUser() async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    final repo = UserDetailsRepository();
    final details = await repo.getUserDetails(uid);
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.exists ? doc.data() : null;
    if (mounted) {
      setState(() {
        _userName = details?.name ?? 'User';
        _userPhotoUrl = data?['profilePictureUrl'] ?? data?['profilePicture'];
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _mediaFile = File(result.files.single.path!);
        _isVideo = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _mediaFile = File(result.files.single.path!);
        _isVideo = true;
      });
    }
  }

  void _addPollOption() {
    if (_pollOptionControllers.length >= 6) return;
    setState(() {
      _pollOptionControllers.add(TextEditingController());
    });
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length <= 2) return;
    _pollOptionControllers[index].dispose();
    setState(() {
      _pollOptionControllers.removeAt(index);
    });
  }

  Future<void> _submitPost() async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    if (_postType == PostType.text && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter some text')));
      return;
    }
    if (_postType == PostType.image && _mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an image')));
      return;
    }
    if (_postType == PostType.video && _mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a video')));
      return;
    }
    if (_postType == PostType.poll) {
      final q = _pollQuestionController.text.trim();
      if (q.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter poll question')));
        return;
      }
      final options = _pollOptionControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
      if (options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least 2 options')));
        return;
      }
    }

    setState(() => _isPosting = true);

    try {
      final repo = ref.read(postRepositoryProvider);
      PollData? pollData;
      if (_postType == PostType.poll) {
        final options = _pollOptionControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        pollData = PollData(
          question: _pollQuestionController.text.trim(),
          options: options.asMap().entries.map((e) => PollOption(text: e.value, index: e.key, count: 0)).toList(),
        );
      }

      await repo.createPost(
        authorId: uid,
        authorName: _userName ?? 'User',
        authorPhotoUrl: _userPhotoUrl,
        type: _postType,
        text: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
        mediaFile: _mediaFile,
        isVideo: _isVideo,
        poll: pollData,
        topics: _selectedTopics.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post created')));
        context.go(AppConstants.routeDiscover);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _submitPost,
            child: _isPosting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Post'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type selection
            const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeChip(PostType.text, Icons.text_fields),
                const SizedBox(width: 8),
                _typeChip(PostType.image, Icons.image),
                const SizedBox(width: 8),
                _typeChip(PostType.video, Icons.videocam),
                const SizedBox(width: 8),
                _typeChip(PostType.poll, Icons.poll),
              ],
            ),
            const SizedBox(height: 24),

            if (_postType == PostType.text) ...[
              TextField(
                controller: _textController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'What\'s on your mind?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            if (_postType == PostType.image) ...[
              if (_mediaFile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_mediaFile!.path.split('/').last, overflow: TextOverflow.ellipsis)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _mediaFile = null)),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Pick Image'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Caption (optional)', border: OutlineInputBorder()),
              ),
            ],

            if (_postType == PostType.video) ...[
              if (_mediaFile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_mediaFile!.path.split('/').last, overflow: TextOverflow.ellipsis)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _mediaFile = null)),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.videocam),
                label: const Text('Pick Video'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Caption (optional)', border: OutlineInputBorder()),
              ),
            ],

            if (_postType == PostType.poll) ...[
              TextField(
                controller: _pollQuestionController,
                decoration: const InputDecoration(
                  labelText: 'Poll question',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Options', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...List.generate(_pollOptionControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pollOptionControllers[i],
                          decoration: InputDecoration(
                            hintText: 'Option ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (_pollOptionControllers.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _removePollOption(i),
                        ),
                    ],
                  ),
                );
              }),
              if (_pollOptionControllers.length < 6)
                TextButton.icon(
                  onPressed: _addPollOption,
                  icon: const Icon(Icons.add),
                  label: const Text('Add option'),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Caption (optional)', border: OutlineInputBorder()),
              ),
            ],

            const SizedBox(height: 24),
            const Text('Topics (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _topics.map((t) {
                final selected = _selectedTopics.contains(t);
                return FilterChip(
                  label: Text(t),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v == true) _selectedTopics.add(t);
                      else _selectedTopics.remove(t);
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(PostType type, IconData icon) {
    final selected = _postType == type;
    return ChoiceChip(
      label: Icon(icon, size: 20),
      selected: selected,
      onSelected: (_) => setState(() => _postType = type),
    );
  }
}
