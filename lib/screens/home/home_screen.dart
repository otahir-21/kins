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
import 'package:kins_app/repositories/user_details_repository.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/providers/notification_provider.dart';
import 'package:kins_app/services/location_service.dart';
import 'package:kins_app/repositories/location_repository.dart';
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
  int _currentBottomNavIndex = 0; // Track active bottom nav item
  
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Status',
              style: TextStyle(
                fontSize: 20,
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            _buildHeader(),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Feature Cards Grid (2x2)
                    _buildFeatureCardsGrid(),
                    const SizedBox(height: 16),
                    
                    // Map Section
                    _buildMapSection(),
                    const SizedBox(height: 16),
                    
                    // Promotional Ad Card
                    _buildPromotionalAdCard(),
                    const SizedBox(height: 16),
                    
                    // Kinsights Section
                    _buildKinsightsSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
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
              const Expanded(
                child: Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 18,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
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
                      style: const TextStyle(
                        fontSize: 14,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  'Change',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
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
            padding: const EdgeInsets.all(16.0),
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
                  style: const TextStyle(
                    fontSize: 14,
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Tap to view full map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
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
                      const Text(
                        'Dubai Hills Mall',
                        style: TextStyle(
                          fontSize: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Promoted Ad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'p',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 20,
                      ),
                      Text(
                        'geon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
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
      padding: const EdgeInsets.all(20.0),
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
          const Text(
            'Kinsights',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'What influences your mother & child purchases the most?',
            style: TextStyle(
              fontSize: 14,
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
      padding: const EdgeInsets.symmetric(vertical: 14),
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final uid = currentUserId;
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
              // Close Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
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
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to saved posts
                      },
                    ),
                    _buildDrawerItem(
                      title: 'Account Settings',
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppConstants.routeSettings);
                      },
                    ),
                    _buildDrawerItem(
                      title: 'Terms of Service',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to terms of service
                      },
                    ),
                    _buildDrawerItem(
                      title: 'Privacy Policy',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to privacy policy
                      },
                    ),
                    _buildDrawerItem(
                      title: 'About Us',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to about us
                      },
                    ),
                    _buildDrawerItem(
                      title: 'Contact Us',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to contact us
                      },
                    ),
                    const Divider(height: 1),
                    _buildDrawerItem(
                      title: 'Log out',
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
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? Colors.red : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isLogout ? Colors.red : Colors.grey.shade400,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // Light grey background
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                route: AppConstants.routeHome,
              ),
              _buildBottomNavItem(
                index: 1,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Discover',
                route: AppConstants.routeDiscover,
              ),
              _buildBottomNavItem(
                index: 2,
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Chat',
                route: AppConstants.routeChat,
              ),
              _buildBottomNavItem(
                index: 3,
                icon: Icons.card_membership_outlined,
                activeIcon: Icons.card_membership,
                label: 'Membership',
                route: AppConstants.routeMembership,
              ),
              _buildBottomNavItem(
                index: 4,
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag,
                label: 'Marketplace',
                route: AppConstants.routeMarketplace,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
  }) {
    final isActive = _currentBottomNavIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentBottomNavIndex = index;
        });
        // Navigate to the route
        if (route == AppConstants.routeHome) {
          // If already on home, do nothing
          return;
        }
        context.push(route);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF6A1A5D) // Dark purple for active
              : Colors.grey.shade200, // Light grey for inactive
          shape: BoxShape.circle,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF6A1A5D).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          isActive ? activeIcon : icon,
          color: isActive ? Colors.white : Colors.black87,
          size: 24,
        ),
      ),
    );
  }
}
