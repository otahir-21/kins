import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/repositories/user_details_repository.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/providers/notification_provider.dart';
import 'package:kins_app/services/location_service.dart';
import 'package:kins_app/repositories/location_repository.dart';
import 'package:kins_app/repositories/auth_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _userName;
  String? _selectedStatus;
  bool _isLoading = true;
  final List<String> _statusOptions = [
    'Expecting Mother',
    'New Mother',
    'Mother',
    'Pregnant',
    'Planning Pregnancy',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      
      if (position != null) {
        final locationRepository = LocationRepository();
        final isVisible = await locationRepository.getUserLocationVisibility(user.uid);
        
        await locationRepository.saveUserLocation(
          userId: user.uid,
          latitude: position.latitude,
          longitude: position.longitude,
          isVisible: isVisible,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to initialize location: $e');
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final repository = UserDetailsRepository();
      final userDetails = await repository.getUserDetails(user.uid);
      
      if (mounted) {
        setState(() {
          _userName = userDetails?.name ?? 'User';
          _selectedStatus = userDetails?.status ?? _statusOptions[0];
          _isLoading = false;
        });
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final repository = UserDetailsRepository();
      try {
        await repository.updateUserStatus(
          userId: user.uid,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statusOptions.map((status) {
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
            
            // Content Cards
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Content Cards Row
                    Row(
                      children: [
                        // Marketplace Card
                        Expanded(
                          child: _buildMarketplaceCard(),
                        ),
                        const SizedBox(width: 12),
                        // Right Column Cards
                        Expanded(
                          child: Column(
                            children: [
                              _buildAskExpertCard(),
                              const SizedBox(height: 12),
                              _buildJoinGroupCard(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Map Section
                    _buildMapSection(),
                    const SizedBox(height: 16),
                    
                    // Survey Section
                    _buildSurveySection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation
      bottomNavigationBar: _buildBottomNavigation(0),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Welcome Section
          Row(
            children: [
              // Drawer Button
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Profile Picture
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B4C93),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              // Welcome Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _userName ?? 'User',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              // Bell Icon with badge
              Consumer(
                builder: (context, ref, child) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    return IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        context.push(AppConstants.routeNotifications);
                      },
                    );
                  }

                  final notificationsState = ref.watch(notificationsProvider(user.uid));
                  final unreadCount = notificationsState.unreadCount;

                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          context.push(AppConstants.routeNotifications);
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Status Section
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
                      color: const Color(0xFF6B4C93).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF6B4C93).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedStatus ?? 'Expecting Mother',
                          style: const TextStyle(
                            color: Color(0xFF6B4C93),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF6B4C93),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _showStatusDialog,
                child: const Text(
                  'Change',
                  style: TextStyle(
                    color: Color(0xFF6B4C93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Add Button
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    context.push(AppConstants.routeAddAction);
                  },
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      color: Color(0xFF6B4C93),
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4B5), // Light peach
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Purple wave at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF6B4C93),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 32,
                  color: Color(0xFF6B4C93),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Marketplace',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Expanded(
                  child: Text(
                    'Lorem Ipsum is simply dummy text simply dummy text simply dummy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Arrow button
                Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    onTap: () {
                      context.push(AppConstants.routeMarketplace);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B4C93),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAskExpertCard() {
    return GestureDetector(
      onTap: () {
        context.push(AppConstants.routeAskExpert);
      },
      child: Container(
        height: 94,
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Pattern overlay
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.shade300.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                  const Spacer(),
                  const Text(
                    'Ask an Expert',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildJoinGroupCard() {
    return GestureDetector(
      onTap: () {
        context.push(AppConstants.routeJoinGroup);
      },
      child: Container(
        height: 94,
        decoration: BoxDecoration(
          color: const Color(0xFF6B4C93),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Pattern overlay
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.shade200.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.link,
                    color: Colors.white,
                    size: 24,
                  ),
                  const Spacer(),
                  const Text(
                    'Join a Group',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildMapSection() {
    return GestureDetector(
      onTap: () {
        context.push(AppConstants.routeNearbyKins);
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Placeholder map
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Map View',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Location pin
            Positioned(
              bottom: 40,
              left: 40,
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
                    const Icon(
                      Icons.restaurant,
                      size: 20,
                      color: Color(0xFF6B4C93),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'The Meeting House',
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
    );
  }

  Widget _buildSurveySection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Survey',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lorem Ipsum is simply dummy text of the printing and typesetting industry.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          // Survey buttons grid
          Row(
            children: [
              Expanded(
                child: _buildSurveyButton('Yes'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSurveyButton('Yes'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSurveyButton('Yes'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSurveyButton('Yes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSurveyButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF6B4C93).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6B4C93).withOpacity(0.3),
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6B4C93),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    final authRepository = AuthRepository();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              color: const Color(0xFF6B4C93),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF6B4C93),
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // User Name
                  Text(
                    _userName ?? 'User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (user?.phoneNumber != null)
                    Text(
                      user!.phoneNumber!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                ],
              ),
            ),
            
            // Drawer Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: Color(0xFF6B4C93)),
                    title: const Text('Profile'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppConstants.routeProfile);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: Color(0xFF6B4C93)),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppConstants.routeSettings);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined, color: Color(0xFF6B4C93)),
                    title: const Text('Notifications'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppConstants.routeNotifications);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      // Show confirmation dialog
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
                        Navigator.pop(context); // Close drawer
                        try {
                          await authRepository.signOut();
                          if (mounted) {
                            // Navigate to splash/onboarding
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
    );
  }

  Widget _buildBottomNavigation(int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 0, currentIndex, AppConstants.routeHome),
              _buildNavItem(Icons.explore, 1, currentIndex, AppConstants.routeCompass),
              _buildNavItem(Icons.chat_bubble_outline, 2, currentIndex, AppConstants.routeChat),
              _buildNavItem(Icons.person_outline, 3, currentIndex, AppConstants.routeProfile),
              _buildNavItem(Icons.settings_outlined, 4, currentIndex, AppConstants.routeSettings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, int currentIndex, String route) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          context.go(route);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFF6B4C93) : Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
