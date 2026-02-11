import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/models/post_model.dart';
import 'package:kins_app/models/interest_model.dart';
import 'package:kins_app/providers/post_provider.dart';
import 'package:kins_app/providers/interest_provider.dart';
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
  
  // Interests from MongoDB backend
  List<InterestModel> _allInterests = [];
  Set<String> _userInterestIds = {};
  final Set<String> _selectedInterestIds = {};
  bool _loadingInterests = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadInterests();
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
    
    try {
      // Get user details from backend /me API
      final response = await BackendApiClient.get('/me', useAuth: true);
      
      if (response['success'] == true) {
        final user = response['user'] as Map<String, dynamic>?;
        if (mounted && user != null) {
          setState(() {
            _userName = user['name']?.toString() ?? 'User';
            _userPhotoUrl = user['profilePictureUrl']?.toString();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to load user: $e');
      // Use fallback values
      if (mounted) {
        setState(() {
          _userName = 'User';
          _userPhotoUrl = null;
        });
      }
    }
  }

  /// Load all interests and user's interests from MongoDB backend
  Future<void> _loadInterests() async {
    try {
      final uid = currentUserId;
      final interestRepo = ref.read(interestRepositoryProvider);
      
      // Load all interests
      final interests = await interestRepo.getInterests();
      
      // Load user's interests
      Set<String> userInterests = {};
      if (uid.isNotEmpty) {
        final userInterestsList = await interestRepo.getUserInterests(uid);
        userInterests = userInterestsList.toSet();
      }
      
      if (mounted) {
        setState(() {
          _allInterests = interests;
          _userInterestIds = userInterests;
          _loadingInterests = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load interests: $e');
      if (mounted) {
        setState(() {
          _loadingInterests = false;
        });
      }
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
    
    // Validate at least one interest is selected (required by backend)
    if (_selectedInterestIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one interest for your post')));
      return;
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
        topics: _selectedInterestIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post created')));
        // Pop back to discover screen so it can refresh
        context.pop(true); // Return true to indicate success
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
            _loadingInterests
                ? const Center(child: CircularProgressIndicator())
                : _buildInterestsSection(),
          ],
        ),
      ),
    );
  }

  /// Build interests section with user's interests first
  Widget _buildInterestsSection() {
    if (_allInterests.isEmpty) {
      return const Text(
        'No interests available. Please add interests from your profile.',
        style: TextStyle(color: Colors.grey),
      );
    }

    // Sort interests: user's interests first, then others alphabetically
    final sortedInterests = [..._allInterests];
    sortedInterests.sort((a, b) {
      final aIsUserInterest = _userInterestIds.contains(a.id);
      final bIsUserInterest = _userInterestIds.contains(b.id);
      
      if (aIsUserInterest && !bIsUserInterest) return -1;
      if (!aIsUserInterest && bIsUserInterest) return 1;
      return a.name.compareTo(b.name);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show user's interests count if any
        if (_userInterestIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Your interests (${_userInterestIds.length})',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        
        // Interest chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sortedInterests.map((interest) {
            final selected = _selectedInterestIds.contains(interest.id);
            final isUserInterest = _userInterestIds.contains(interest.id);
            
            return FilterChip(
              label: Text(interest.name),
              selected: selected,
              avatar: isUserInterest 
                  ? Icon(
                      Icons.star,
                      size: 16,
                      color: selected ? Colors.white : const Color(0xFF6A1A5D),
                    )
                  : null,
              selectedColor: const Color(0xFF6A1A5D).withOpacity(0.3),
              checkmarkColor: const Color(0xFF6A1A5D),
              backgroundColor: isUserInterest 
                  ? const Color(0xFF6A1A5D).withOpacity(0.05)
                  : null,
              side: isUserInterest
                  ? BorderSide(
                      color: const Color(0xFF6A1A5D).withOpacity(0.2),
                      width: 1,
                    )
                  : null,
              onSelected: (v) {
                setState(() {
                  if (v == true) {
                    _selectedInterestIds.add(interest.id);
                  } else {
                    _selectedInterestIds.remove(interest.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
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
