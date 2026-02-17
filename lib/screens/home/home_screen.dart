import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/repositories/auth_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/repositories/user_details_repository.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/providers/notification_provider.dart';
import 'package:kins_app/services/location_service.dart';
import 'package:kins_app/repositories/location_repository.dart';
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
  final List<String> _statusOptions = [
    'Expecting Mother',
    'New Mother',
    'Mother',
    'Pregnant',
    'Planning Pregnancy',
  ];

  final List<String> _kinsightsOptions = [
    'Price & Discounts',
    'Online Reviews',
    'Expert Advice',
    'Influencer Reviews',
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
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = currentUserId;
    if (uid.isNotEmpty) {
      try {
        final repository = UserDetailsRepository();
        final userDetails = await repository.getUserDetails(uid);
        
        // Get location and profile picture from Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        
        final data = doc.exists ? doc.data() : null;
        String? location = data?['location']?['city'] ?? 'Dubai, UAE';
        // Use profile picture URL only (not documentUrl - documents are PDFs and can't be shown as images)
        final profilePicUrl = data?['profilePictureUrl'] ?? data?['profilePicture'];
        
        if (mounted) {
          setState(() {
            _userName = userDetails?.name ?? 'User';
            _selectedStatus = userDetails?.status ?? _statusOptions[0];
            _userLocation = location ?? 'Dubai, UAE';
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
                      const SizedBox(height: 16),
                      _buildFeatureCardsGrid(),
                      const SizedBox(height: 16),
                      _buildMapSection(),
                      const SizedBox(height: 16),
                      _buildPromotionalAdCard(),
                      const SizedBox(height: 16),
                      _buildKinsightsSection(),
                      const SizedBox(height: 24),
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
    return Container(
      padding: EdgeInsets.fromLTRB(
        Responsive.screenPaddingH(context),
        Responsive.spacing(context, 8),
        Responsive.screenPaddingH(context),
        Responsive.spacing(context, 12),
      ),
      child: Column(
        children: [
          // Top Row: Menu, Title, Profile
          Row(
            children: [
              // Hamburger Menu
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
              
              // Home Title
              Expanded(
                child: Text(
                  'Home',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Profile Picture (on the right) – tap to open profile
              GestureDetector(
                onTap: () => context.push(AppConstants.routeProfile),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _profilePictureUrl != null ? null : const Color(0xFF6B4C93),
                    shape: BoxShape.circle,
                    image: _profilePictureUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_profilePictureUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profilePictureUrl == null
                      ? const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Status Chip and Change Button
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showStatusDialog,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.screenPaddingH(context),
                      vertical: Responsive.spacing(context, 10),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _selectedStatus ?? 'Expecting Mother',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _showStatusDialog,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.screenPaddingH(context),
                    vertical: Responsive.spacing(context, 10),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  'Change',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: Responsive.fontSize(context, 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCardsGrid() {
    return Column(
      children: [
        // First Row
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.workspace_premium,
                title: 'Become a brand',
                color: const Color(0xFFE6E6FA), // Light purple
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Marketplace',
                color: const Color(0xFFE6E6FA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second Row
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.link,
                title: 'Groups',
                color: const Color(0xFFE6E6FA),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.people_outline,
                title: 'Community',
                color: const Color(0xFFE6E6FA),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Decorative illustration (simplified)
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6B4C93).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: const Color(0xFF6B4C93),
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            'Kinsights',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 22),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What influences your mother & child purchases the most?',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Filter chips grid (2x2)
          Row(
            children: [
              Expanded(
                child: _buildKinsightChip(_kinsightsOptions[0]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKinsightChip(_kinsightsOptions[1]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKinsightChip(_kinsightsOptions[2]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKinsightChip(_kinsightsOptions[3]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKinsightChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 13),
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
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
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
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
