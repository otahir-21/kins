import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/repositories/auth_repository.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/repositories/user_details_repository.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/providers/follow_provider.dart';
import 'package:kins_app/providers/groups_provider.dart';
import 'package:kins_app/providers/notification_provider.dart';
import 'package:kins_app/repositories/follow_repository.dart';
import 'package:kins_app/repositories/groups_repository.dart';
import 'package:kins_app/screens/chat/group_conversation_screen.dart';
import 'package:kins_app/widgets/group_card.dart';
import 'package:kins_app/services/location_service.dart';
import 'package:kins_app/repositories/location_repository.dart';
import 'package:kins_app/widgets/app_header.dart';
import 'package:kins_app/widgets/confirm_dialog.dart';
import 'package:kins_app/widgets/floating_nav_overlay.dart';
import 'package:kins_app/widgets/kins_logo.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _userName;
  String? _userLocation;
  String? _selectedStatus;
  String? _profilePictureUrl;
  bool _isLoading = true;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  final List<String> _statusOptions = [
    'Expecting Mother',
    'New Mother',
    'Mother',
    'Pregnant',
    'Planning Pregnancy',
  ];

  final List<({String label, String percent})> _kinsightsOptions = [
    (label: 'Lorem ipsum', percent: '12%'),
    (label: 'Lorem ipsum', percent: '55%'),
    (label: 'Lorem ipsum', percent: '34%'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    try {
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
        
        // Move map camera to current location
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14.0,
          ),
        );
        
        final locationRepository = LocationRepository();
        final isVisible = await locationRepository.getUserLocationVisibility(uid);
        
        await locationRepository.saveUserLocation(
          userId: uid,
          latitude: position.latitude,
          longitude: position.longitude,
          isVisible: isVisible,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to initialize location: $e');
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = currentUserId;
    if (uid.isNotEmpty) {
      try {
        final repository = UserDetailsRepository();
        final userDetails = await repository.getUserDetails(uid);
        // Get location and profile picture from backend GET /me
        final me = await BackendApiClient.get('/me');
        final user = me['user'] as Map<String, dynamic>? ?? me as Map<String, dynamic>;
        final city = user['city']?.toString();
        final country = user['country']?.toString();
        final location = (city != null && city.isNotEmpty) || (country != null && country.isNotEmpty)
            ? [if (city != null && city.isNotEmpty) city, if (country != null && country.isNotEmpty) country].join(', ')
            : 'Dubai, UAE';
        final profilePicUrl = user['profilePictureUrl']?.toString() ?? user['profilePicture']?.toString();

        if (mounted) {
          setState(() {
            _userName = userDetails?.name ?? 'User';
            _selectedStatus = userDetails?.status ?? _statusOptions[0];
            _userLocation = location;
            _profilePictureUrl = profilePicUrl;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('❌ Failed to load user data: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final uid = currentUserId;
    if (uid.isNotEmpty) {
      final repository = UserDetailsRepository();
      try {
        await repository.updateUserStatus(
          userId: uid,
          status: newStatus,
        );
        setState(() {
          _selectedStatus = newStatus;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: $e')),
          );
        }
      }
    }
  }

  void _showStatusDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(Responsive.spacing(context, 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Status',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._statusOptions.map((status) {
              return ListTile(
                title: Text(status),
                trailing: _selectedStatus == status
                    ? const Icon(Icons.check, color: Color(0xFF6B4C93))
                    : null,
                onTap: () {
                  _updateStatus(status);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(child: SkeletonHome()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      body: FloatingNavOverlay(
        currentIndex: 2,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildSearchBar(),
                      _buildActionRow(),
                      _buildSuggestedForYou(),
                      const SizedBox(height: 16),
                      _buildGroupsSection(),
                      const SizedBox(height: 16),
                      _buildMapSection(),
                      const SizedBox(height: 16),
                      _buildPromotionalAdCard(),
                      const SizedBox(height: 16),
                      _buildKinsightsSection(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final uid = currentUserId;
    final notificationState = uid.isNotEmpty ? ref.watch(notificationsProvider(uid)) : null;
    final unreadCount = notificationState?.unreadCount ?? 0;

    return Container(
      color: Colors.white,
      child: AppHeader(
        leading: AppHeader.drawerButton(context),
        name: _userName ?? 'Home',
        subtitle: _userLocation,
        profileImageUrl: _profilePictureUrl,
        onTitleTap: () => context.push(AppConstants.routeProfile),
        trailing: GestureDetector(
          onTap: () => context.push(AppConstants.routeNotifications),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 35,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_outlined, size: 18, color: Colors.black87),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.screenPaddingH(context),
        vertical: Responsive.spacing(context, 8),
      ),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    color: Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  static const Color _actionCardBg = Color(0xFFF8F8F8);
  static const Color _actionCircleBg = Color(0xFFEEEEEE);
  static const Color _actionTitleColor = Color(0xFF333333);
  static const Color _actionSubtitleColor = Color(0xFF666666);
  static const Color _groupsTagPurple = Color(0xFF7C1D54);
  static const double _actionCapsuleWidth = 200;
  static const double _actionChipWidth = 64;
  static const double _actionChipHeight = 28;

  Widget _buildActionRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.screenPaddingH(context),
        Responsive.spacing(context, 16),
        Responsive.screenPaddingH(context),
        Responsive.spacing(context, 12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionCard(
              title: 'Create',
              subtitle: 'Group',
              tag: 'Groups',
              onTagTap: () => context.push(AppConstants.routeDiscover),
              onTap: () => context.push(AppConstants.routeCreateGroup),
            ),
            SizedBox(width: Responsive.spacing(context, 12)),
            _buildActionCard(
              title: 'Create',
              subtitle: 'Post',
              tag: 'Post',
              onTagTap: () => context.push(AppConstants.routeCreatePost),
              onTap: () => context.push(AppConstants.routeCreatePost),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    String? tag,
    VoidCallback? onTagTap,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: _actionCapsuleWidth,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, 16),
            vertical: Responsive.spacing(context, 12),
          ),
          decoration: BoxDecoration(
            color: _actionCardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _actionCircleBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 22, color: Colors.black),
              ),
              SizedBox(width: Responsive.spacing(context, 12)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: _actionTitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: Responsive.spacing(context, 2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 13),
                        fontWeight: FontWeight.w400,
                        color: _actionSubtitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (tag != null)
                GestureDetector(
                  onTap: onTagTap ?? onTap,
                  child: Container(
                    width: _actionChipWidth,
                    height: _actionChipHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _groupsTagPurple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag!,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _suggestionChipHeight = 56;
  static const double _suggestionFollowBtnHeight = 28;
  static const Color _suggestionPurple = Color(0xFF6B4C93);

  Widget _buildSuggestedForYou() {
    final suggestionsAsync = ref.watch(suggestionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.screenPaddingH(context),
            Responsive.spacing(context, 8),
            0,
            Responsive.spacing(context, 8),
          ),
          child: Text(
            'Suggested for you',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        suggestionsAsync.when(
          data: (suggestions) {
            if (suggestions.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: _suggestionChipHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => SizedBox(width: Responsive.spacing(context, 12)),
                itemBuilder: (context, i) {
                  final user = suggestions[i];
                  return _buildSuggestionChip(user);
                },
              ),
            );
          },
          loading: () => SizedBox(
            height: _suggestionChipHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => _buildSuggestionChipPlaceholder(),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSuggestionChipPlaceholder() {
    return Container(
      width: 200,
      padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 12), vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: Colors.grey.shade300),
          SizedBox(width: Responsive.spacing(context, 10)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 10, width: 60, color: Colors.grey.shade300),
                const SizedBox(height: 4),
                Container(height: 8, width: 80, color: Colors.grey.shade200),
              ],
            ),
          ),
          Container(
            width: 64,
            height: _suggestionFollowBtnHeight,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(FollowUserInfo user) {
    final isFollowed = user.isFollowedByMe;
    final displayName = user.displayNameForChat;
    final handle = user.username != null && user.username!.isNotEmpty
        ? '@${user.username!}'
        : '';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 12), vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                ? NetworkImage(user.profilePictureUrl!)
                : null,
            child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                ? Icon(Icons.person, color: Colors.grey.shade600, size: 22)
                : null,
          ),
          SizedBox(width: Responsive.spacing(context, 10)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (handle.isNotEmpty) ...[
                SizedBox(height: Responsive.spacing(context, 2)),
                Text(
                  handle,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          SizedBox(width: Responsive.spacing(context, 10)),
          _SuggestionFollowButton(
            userId: user.id,
            isFollowed: isFollowed,
            onStateChanged: () => ref.invalidate(suggestionsProvider),
          ),
        ],
      ),
    );
  }

  static const double _groupCardWidth = 280;
  static const double _groupCardHeight = 220;

  Widget _buildGroupsSection() {
    final groupsAsync = ref.watch(homeGroupsProvider);
    return groupsAsync.when(
      data: (response) {
        final groups = response.groups;
        if (groups.isEmpty) return const SizedBox.shrink();
        return SizedBox(
              height: _groupCardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
                itemCount: groups.length,
                separatorBuilder: (_, __) => SizedBox(width: Responsive.spacing(context, 12)),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return SizedBox(
                    width: _groupCardWidth,
                    child: GroupCard(
                      groupId: group.id,
                      name: group.name,
                      description: group.description,
                      members: group.memberCount,
                      imageUrl: group.imageUrl,
                      horizontalSlide: true,
                      onTap: () {
                        context.push(
                          AppConstants.groupConversationPath(group.id),
                          extra: GroupConversationArgs(
                            groupId: group.id,
                            name: group.name,
                            description: group.description,
                            imageUrl: group.imageUrl,
                          ),
                        );
                      },
                      onJoin: () {
                        // TODO: Join group; same as Chat tab
                      },
                    ),
                  );
                },
              ),
            );
      },
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 24)),
        child: Center(
          child: CircularProgressIndicator(color: const Color(0xFF7C1D54)),
        ),
      ),
      error: (err, _) => Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 16)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                err.toString().replaceFirst(RegExp(r'^Exception:?\s*'), ''),
                style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Responsive.spacing(context, 8)),
              TextButton(
                onPressed: () => ref.invalidate(homeGroupsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return GestureDetector(
      onTap: () {
        // Navigate to full map screen
        context.push(AppConstants.routeNearbyKins);
      },
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Real Google Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition != null
                      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                      : const LatLng(25.2048, 55.2708), // Dubai default
                  zoom: 14.0,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  // If we have current position, move camera to it
                  if (_currentPosition != null) {
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        14.0,
                      ),
                    );
                  }
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false, // Hide default button
                mapType: MapType.normal,
                zoomControlsEnabled: false, // Hide zoom controls
                zoomGesturesEnabled: true, // Enable zoom for better UX
                scrollGesturesEnabled: true, // Enable scroll for better UX
                rotateGesturesEnabled: false, // Disable rotate
                tiltGesturesEnabled: false, // Disable tilt
                markers: _currentPosition != null
                    ? {
                        Marker(
                          markerId: const MarkerId('current_location'),
                          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                        ),
                      }
                    : {},
                // Add error handling
                onTap: (LatLng position) {
                  // Navigate to full map when tapped
                  context.push(AppConstants.routeNearbyKins);
                },
              ),
              // Semi-transparent overlay to indicate it's clickable (only when no position)
              if (_currentPosition == null)
                Positioned.fill(
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.screenPaddingH(context),
                          vertical: Responsive.spacing(context, 8),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Tap to view full map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: Responsive.fontSize(context, 12),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // LIVING label with blue pin (left side)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.spacing(context, 10),
                    vertical: Responsive.spacing(context, 6),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'LIVING',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Location marker overlay (Dubai Hills Mall)
              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.spacing(context, 12),
                    vertical: Responsive.spacing(context, 8),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_bag,
                        size: 18,
                        color: const Color(0xFF6B4C93),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Dubai Hills Mall',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromotionalAdCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Blurred background image placeholder
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade100,
                    Colors.purple.shade100,
                  ],
                ),
              ),
              child: Container(
                color: Colors.blue.shade50,
                // Placeholder for background image - can be replaced with actual image
              ),
            ),
            // Promoted Ad label
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.spacing(context, 8),
                  vertical: Responsive.spacing(context, 4),
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Promoted Ad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.fontSize(context, 10),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // Red blob with pigeon logo (heart instead of 'i')
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'p',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.fontSize(context, 28),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 20,
                      ),
                      Text(
                        'geon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.fontSize(context, 28),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Baby footprint icons (decorative)
            Positioned(
              top: 40,
              left: 30,
              child: Icon(
                Icons.favorite,
                size: 20,
                color: Colors.blue.shade200,
              ),
            ),
            Positioned(
              bottom: 50,
              right: 40,
              child: Icon(
                Icons.favorite,
                size: 16,
                color: Colors.blue.shade200,
              ),
            ),
            // Carousel dots
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4C93),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKinsightsSection() {
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kinsights: What factors influence your purchases the most?',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ..._kinsightsOptions.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildKinsightRow(option.label, option.percent),
              )),
        ],
      ),
    );
  }

  Widget _buildKinsightRow(String label, String percent) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.screenPaddingH(context),
        vertical: Responsive.spacing(context, 12),
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            percent,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final authRepository = ref.read(authRepositoryProvider);

    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Logo and Close Button
              Padding(
                padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    KinsLogo(
                      width: Responsive.scale(context, 90),
                      height: Responsive.scale(context, 36),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Drawer Menu Items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(
                      title: 'Saved Posts',
                      icon: Icons.bookmark_border,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to saved posts
                      },
                    ),
                    _buildDrawerItem(
                      title: 'Account Settings',
                      icon: Icons.person_outline,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppConstants.routeSettings);
                      },
                    ),
                    _buildDrawerItem(
                      title: 'Terms of Service',
                      icon: Icons.description_outlined,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to terms of service
                      },
                    ),
                    _buildDrawerItem(
                      title: 'Privacy Policy',
                      icon: Icons.privacy_tip_outlined,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to privacy policy
                      },
                    ),
                    _buildDrawerItem(
                      title: 'About Us',
                      icon: Icons.info_outline,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to about us
                      },
                    ),
                    _buildDrawerItem(
                      title: 'Contact Us',
                      icon: Icons.contact_support_outlined,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to contact us
                      },
                    ),
                    const Divider(height: 1),
                    _buildDrawerItem(
                      title: 'Log out',
                      icon: Icons.exit_to_app,
                      isLogout: true,
                      onTap: () async {
                        final shouldLogout = await showConfirmDialog<bool>(
                          context: context,
                          title: 'Log out',
                          message: 'Are you sure you want to log out?',
                          confirmLabel: 'Log out',
                          destructive: true,
                          icon: Icons.logout,
                        );

                        if (shouldLogout == true) {
                          Navigator.pop(context);
                          try {
                            await authRepository.signOut();
                            if (mounted) {
                              context.go(AppConstants.routeSplash);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to logout: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isLogout = false,
    bool isDestructive = false,
  }) {
    final useRed = isLogout || isDestructive;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: useRed ? Colors.red : Colors.black87, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: useRed ? Colors.red : Colors.black87,
          fontSize: Responsive.fontSize(context, 16),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: useRed ? Colors.red : Colors.grey.shade400,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.screenPaddingH(context),
        vertical: 0,
      ),
    );
  }

}

/// Follow/Following button for suggestion chip. Calls follow or unfollow then [onStateChanged].
class _SuggestionFollowButton extends ConsumerStatefulWidget {
  const _SuggestionFollowButton({
    required this.userId,
    required this.isFollowed,
    required this.onStateChanged,
  });

  final String userId;
  final bool isFollowed;
  final VoidCallback onStateChanged;

  @override
  ConsumerState<_SuggestionFollowButton> createState() => _SuggestionFollowButtonState();
}

class _SuggestionFollowButtonState extends ConsumerState<_SuggestionFollowButton> {
  bool _loading = false;
  bool _isFollowed = false;

  @override
  void initState() {
    super.initState();
    _isFollowed = widget.isFollowed;
  }

  @override
  void didUpdateWidget(_SuggestionFollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.isFollowed != widget.isFollowed) {
      _isFollowed = widget.isFollowed;
    }
  }

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    final repo = ref.read(followRepositoryProvider);
    try {
      if (_isFollowed) {
        await repo.unfollow(widget.userId);
        if (mounted) setState(() => _isFollowed = false);
      } else {
        await repo.follow(widget.userId);
        if (mounted) setState(() => _isFollowed = true);
      }
      widget.onStateChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const double _btnHeight = 28;
  static const Color _purple = Color(0xFF7C1D54); // same as Groups tag

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _isFollowed ? Colors.grey.shade200 : _purple,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _loading ? null : _onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 64,
          height: _btnHeight,
          alignment: Alignment.center,
          child: _loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _isFollowed ? Colors.grey.shade600 : Colors.white),
                )
              : Text(
                  _isFollowed ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: _isFollowed ? Colors.grey.shade700 : Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
