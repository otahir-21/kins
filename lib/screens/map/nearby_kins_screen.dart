import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kins_app/models/kin_location_model.dart';
import 'package:kins_app/repositories/location_repository.dart';
import 'package:kins_app/services/location_service.dart';
import 'package:kins_app/providers/user_details_provider.dart';
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get visibility status
        final isVisible = await _locationRepository.getUserLocationVisibility(user.uid);
        
        await _locationRepository.saveUserLocation(
          userId: user.uid,
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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
    final user = FirebaseAuth.instance.currentUser;

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
      if (kin.userId == user?.uid) continue; // Skip current user

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
            const Center(child: CircularProgressIndicator())
          else if (_locationError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
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
                        fontSize: 16,
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
                    : const LatLng(40.3573, -74.6672), // Default to Princeton
                zoom: 14.0,
              ),
              markers: _buildMarkers(),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
              onMapCreated: (controller) {
                _mapController = controller;
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
                  padding: const EdgeInsets.all(16.0),
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
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kins around your\nlocation',
                      style: const TextStyle(
                        fontSize: 24,
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

          // Profile preview card (slides up from bottom)
          if (_selectedKin != null)
            _buildProfilePreviewCard(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Distance',
              style: TextStyle(
                fontSize: 20,
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

  Widget _buildProfilePreviewCard() {
    final kin = _selectedKin!;
    final distance = _currentPosition != null
        ? _locationService.calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            kin.latitude,
            kin.longitude,
          )
        : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Profile picture and name
                    Row(
                      children: [
                        // Profile picture
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B4C93),
                            shape: BoxShape.circle,
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
                                        size: 30,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 30,
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Name and distance
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kin.name ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (distance > 0)
                                Text(
                                  '${distance.toStringAsFixed(1)} km away',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Expand icon
                        IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () {
                            // TODO: Navigate to full profile
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile screen - Coming soon'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Description
                    if (kin.description != null)
                      Text(
                        kin.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Attributes
                    if (kin.nationality != null)
                      _buildAttributeRow('Nationality', kin.nationality!),
                    if (kin.motherhoodStatus != null)
                      _buildAttributeRow('Motherhood', kin.motherhoodStatus!),
                    const SizedBox(height: 24),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Implement follow
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Follow - Coming soon'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B4C93),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Follow'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // TODO: Implement message
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Message - Coming soon'),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6B4C93),
                              side: const BorderSide(color: Color(0xFF6B4C93)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Message'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttributeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
