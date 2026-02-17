import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kins_app/models/kin_location_model.dart';
import 'package:kins_app/repositories/location_repository.dart';
import 'package:kins_app/services/location_service.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';
import 'dart:async';

class NearbyKinsScreen extends ConsumerStatefulWidget {
  const NearbyKinsScreen({super.key});

  @override
  ConsumerState<NearbyKinsScreen> createState() => _NearbyKinsScreenState();
}

class _NearbyKinsScreenState extends ConsumerState<NearbyKinsScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final LocationRepository _locationRepository = LocationRepository();
  
  Position? _currentPosition;
  List<KinLocationModel> _nearbyKins = [];
  KinLocationModel? _selectedKin;
  bool _isLoading = true;
  String? _locationError;
  
  // Filters
  double _selectedRadius = 50.0; // Default 50km
  String? _selectedMotherhoodStatus;
  String? _selectedNationality;
  
  final List<double> _radiusOptions = [1.0, 5.0, 10.0, 25.0, 50.0];
  final List<String> _motherhoodStatusOptions = [
    'Expecting Mother',
    'New Mother',
    'Mother',
    'Pregnant',
    'Planning Pregnancy',
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      // Get current location
      final position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        setState(() {
          _locationError = 'Could not get your location. Please enable location services.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Save location to Firestore
      final uid = currentUserId;
      if (uid.isNotEmpty) {
        // Get visibility status
        final isVisible = await _locationRepository.getUserLocationVisibility(uid);
        
        await _locationRepository.saveUserLocation(
          userId: uid,
          latitude: position.latitude,
          longitude: position.longitude,
          isVisible: isVisible,
        );
      }

      // Move camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14.0,
        ),
      );

      // Load nearby kins
      _loadNearbyKins();
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  void _loadNearbyKins() {
    if (_currentPosition == null) return;

    final uid = currentUserId;
    if (uid.isEmpty) return;

    _locationRepository
        .getNearbyKins(
          centerLat: _currentPosition!.latitude,
          centerLng: _currentPosition!.longitude,
          radiusKm: _selectedRadius,
          motherhoodStatusFilter: _selectedMotherhoodStatus,
          nationalityFilter: _selectedNationality,
        )
        .listen((kins) {
      if (mounted) {
        setState(() {
          _nearbyKins = kins;
        });
      }
    });
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final uid = currentUserId;

    // Current user marker (blue)
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_user'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Nearby kins markers (purple with 'k')
    for (var kin in _nearbyKins) {
      if (kin.userId == uid) continue; // Skip current user

      markers.add(
        Marker(
          markerId: MarkerId(kin.userId),
          position: LatLng(kin.latitude, kin.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          onTap: () {
            setState(() {
              _selectedKin = kin;
            });
          },
        ),
      );
    }

    return markers;
  }

  void _applyFilters() {
    _loadNearbyKins();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map
          if (_isLoading)
            const SkeletonMapList()
          else if (_locationError != null)
            Center(
              child: Padding(
                padding: EdgeInsets.all(Responsive.spacing(context, 24)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _locationError!,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 16),
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _locationError = null;
                          _isLoading = true;
                        });
                        _initializeLocation();
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                    ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                    : const LatLng(25.2048, 55.2708), // Default to Dubai
                zoom: 14.0,
              ),
              markers: _buildMarkers(),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
              onMapCreated: (controller) {
                _mapController = controller;
                // Move camera to current position if available
                if (_currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      14.0,
                    ),
                  );
                }
              },
              onCameraMove: (position) {
                // Check if we need clustering based on zoom
                final zoom = position.zoom;
                if (zoom < 12 || _nearbyKins.length > 25) {
                  // Could implement clustering here
                }
              },
            ),

          // Header
          SafeArea(
            child: Column(
              children: [
                // Breadcrumb and back button
                Padding(
                  padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Maps → Nearby kins',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Title
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kins around your\nlocation',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 24),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Filter buttons
                _buildFilterChips(),
              ],
            ),
          ),

          // Profile preview dialog (shown when kin marker is tapped)
          if (_selectedKin != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedKin = null;
                });
              },
              child: Container(
                color: Colors.transparent,
                child: _buildKinProfileDialog(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context)),
      child: Row(
        children: [
          // Distance filter
          FilterChip(
            label: Text('${_selectedRadius.toInt()}km'),
            selected: true,
            onSelected: (selected) {
              _showDistanceFilter();
            },
          ),
          const SizedBox(width: 8),
          // Motherhood status filter
          if (_selectedMotherhoodStatus != null)
            FilterChip(
              label: Text(_selectedMotherhoodStatus!),
              selected: true,
              onSelected: (selected) {
                setState(() {
                  _selectedMotherhoodStatus = null;
                });
                _applyFilters();
              },
            ),
          const SizedBox(width: 8),
          // Nationality filter
          if (_selectedNationality != null)
            FilterChip(
              label: Text(_selectedNationality!),
              selected: true,
              onSelected: (selected) {
                setState(() {
                  _selectedNationality = null;
                });
                _applyFilters();
              },
            ),
        ],
      ),
    );
  }

  void _showDistanceFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(Responsive.spacing(context, 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Distance',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._radiusOptions.map((radius) {
              return ListTile(
                title: Text('${radius.toInt()} km'),
                trailing: _selectedRadius == radius
                    ? const Icon(Icons.check, color: Color(0xFF6B4C93))
                    : null,
                onTap: () {
                  setState(() {
                    _selectedRadius = radius;
                  });
                  Navigator.pop(context);
                  _applyFilters();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildKinProfileDialog() {
    final kin = _selectedKin!;

    return Positioned(
      bottom: 20,
      right: 20,
      left: 20,
      child: GestureDetector(
        onTap: () {
          // Prevent dismissing when tapping inside the dialog
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          child: Stack(
            children: [
              // Close/Expand button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedKin = null;
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(Responsive.screenPaddingH(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile Picture and Info Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Large Profile Picture
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B4C93),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 2,
                            ),
                          ),
                          child: kin.profilePicture != null
                              ? ClipOval(
                                  child: Image.network(
                                    kin.profilePicture!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 50,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 50,
                                ),
                        ),
                        const SizedBox(width: 16),
                        // User Information
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              Text(
                                kin.name ?? 'Unknown User',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 20),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Description/Tagline
                              Text(
                                kin.description ?? 'Lorem Ipsum is Lorem Ipsum',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 14),
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Nationality
                              if (kin.nationality != null)
                                Row(
                                  children: [
                                    Text(
                                      'Nationality: ',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 14),
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      kin.nationality!,
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 14),
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 6),
                              // Status
                              Row(
                                children: [
                                  Text(
                                    'Status: ',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 14),
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    kin.motherhoodStatus ?? 'Expecting',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 14),
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Implement follow functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Follow functionality coming soon'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE6E6FA), // Light purple
                              foregroundColor: Colors.black87,
                              padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 14)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Follow',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 16),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Navigate to message screen
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Message functionality coming soon'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE6E6FA), // Light purple
                              foregroundColor: Colors.black87,
                              padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 14)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Message',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 16),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),);
  }
}
