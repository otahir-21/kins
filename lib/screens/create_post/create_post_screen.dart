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
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';
import 'package:kins_app/widgets/interest_chips_scrollable.dart';

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
  final TextEditingController _interestSearchController = TextEditingController();

  static const Color _borderGrey = Color(0xFFE5E5E5);

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
    _interestSearchController.dispose();
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

  bool get _canPost {
    if (_isPosting) return false;
    
    // Poll mode: need question and at least 2 options
    if (_postType == PostType.poll) {
      if (_pollQuestionController.text.trim().isEmpty) return false;
      final options = _pollOptionControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return options.length >= 2;
    }
    
    // Image/Video mode: need media file
    if (_postType == PostType.image || _postType == PostType.video) {
      return _mediaFile != null;
    }
    
    // Text mode: need text
    return _textController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(),
            
            // Content (scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Text input or Poll UI
                    if (_postType == PostType.poll)
                      _buildPollMode()
                    else
                      _buildTextInput(),
                    
                    // Media preview
                    if (_mediaFile != null) ...[
                      const SizedBox(height: 16),
                      _buildMediaPreview(),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Interests section
                    if (_loadingInterests)
                      const SkeletonInterestChips()
                    else
                      _buildInterestsSection(),
                    
                    const SizedBox(height: 80), // Space for bottom buttons
                  ],
                ),
              ),
            ),
            
            // Bottom action buttons
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Close button
          IconButton(
            icon: const Icon(Icons.close, size: 22, color: Colors.black),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          
          // User profile image
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
            ),
            child: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      _userPhotoUrl!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  )
                : Icon(
                    Icons.person,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
          ),
          
          const Spacer(),
          
          // Post button
          ElevatedButton(
            onPressed: _canPost ? _submitPost : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              disabledBackgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: _isPosting
                ? const SkeletonInline(size: 16)
                : const Text(
                    'Post',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return TextField(
      controller: _textController,
      maxLines: null,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      decoration: const InputDecoration(
        hintText: 'Share your thoughts...',
        hintStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: Colors.grey,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPollMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question label
        Text(
          'Question:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Question input
        TextField(
          controller: _pollQuestionController,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Ask a question...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Answer options label
        Text(
          'Answer Options:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        
        // Options
        ...List.generate(_pollOptionControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pollOptionControllers[i],
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Option ${i + 1}',
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (_pollOptionControllers.length > 2)
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                    onPressed: () => _removePollOption(i),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          );
        }),
        
        // Add option button
        if (_pollOptionControllers.length < 6)
          InkWell(
            onTap: _addPollOption,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+ Add option',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaPreview() {
    if (_mediaFile == null) return const SizedBox.shrink();
    
    return Stack(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey.shade100,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _isVideo
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        color: Colors.black12,
                        child: const Center(
                          child: Icon(Icons.videocam, size: 48, color: Colors.grey),
                        ),
                      ),
                      const Icon(
                        Icons.play_circle_outline,
                        size: 64,
                        color: Colors.white,
                      ),
                    ],
                  )
                : Image.file(
                    _mediaFile!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        // Remove button
        Positioned(
          top: 8,
          right: 8,
          child: InkWell(
            onTap: () => setState(() {
              _mediaFile = null;
              _postType = PostType.text;
            }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Poll button
          _buildActionButton(
            icon: Icons.poll_outlined,
            onTap: () {
              setState(() {
                if (_postType == PostType.poll) {
                  _postType = PostType.text;
                } else {
                  _postType = PostType.poll;
                  _mediaFile = null;
                }
              });
            },
            isActive: _postType == PostType.poll,
          ),
          const SizedBox(width: 16),
          
          // Photo button
          _buildActionButton(
            icon: Icons.photo_outlined,
            onTap: () async {
              // Show picker for image or video
              final result = await showModalBottomSheet<String>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: const Text('Photo'),
                        onTap: () => Navigator.pop(ctx, 'image'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.videocam),
                        title: const Text('Video'),
                        onTap: () => Navigator.pop(ctx, 'video'),
                      ),
                    ],
                  ),
                ),
              );
              
              if (result == 'image') {
                await _pickImage();
                if (_mediaFile != null) {
                  setState(() {
                    _postType = PostType.image;
                  });
                }
              } else if (result == 'video') {
                await _pickVideo();
                if (_mediaFile != null) {
                  setState(() {
                    _postType = PostType.video;
                  });
                }
              }
            },
            isActive: _mediaFile != null,
          ),
          const SizedBox(width: 16),
          
          // More button
          _buildActionButton(
            icon: Icons.add,
            onTap: () {
              // TODO: Implement later
            },
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? Colors.black.withOpacity(0.1) : const Color(0xFFF1F1F1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? Colors.black : Colors.grey.shade700,
        ),
      ),
    );
  }

  /// Build interests section with user's interests first
  Widget _buildInterestsSection() {
    if (_allInterests.isEmpty) {
      return const SizedBox.shrink();
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

    final query = _interestSearchController.text.trim().toLowerCase();
    final filteredInterests = query.isEmpty
        ? sortedInterests
        : sortedInterests.where((i) => i.name.toLowerCase().contains(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topics label
        Text(
          'Topics (optional)',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        // Search bar (same style as interests screen)
        Container(
          height: 45,
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
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search interests',
                    hintStyle: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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
        const SizedBox(height: 12),
        // Interest chips (scrollable horizontal rows)
        InterestChipsScrollable(
          interests: filteredInterests,
          selectedIds: _selectedInterestIds,
          onToggle: (id) {
            setState(() {
              if (_selectedInterestIds.contains(id)) {
                _selectedInterestIds.remove(id);
              } else {
                _selectedInterestIds.add(id);
              }
            });
          },
        ),
      ],
    );
  }
}
