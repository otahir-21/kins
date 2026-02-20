class KinLocationModel {
  final String userId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final bool isVisible;
  final String? name;
  final String? profilePicture;
  final String? nationality;
  final String? motherhoodStatus;
  final String? description;

  KinLocationModel({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.isVisible = true,
    this.name,
    this.profilePicture,
    this.nationality,
    this.motherhoodStatus,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': updatedAt.toIso8601String(),
      'isVisible': isVisible,
      'name': name,
      'profilePicture': profilePicture,
      'nationality': nationality,
      'motherhoodStatus': motherhoodStatus,
      'description': description,
    };
  }

  factory KinLocationModel.fromMap(Map<String, dynamic> map) {
    return KinLocationModel(
      userId: map['userId'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      isVisible: map['isVisible'] ?? true,
      name: map['name'],
      profilePicture: map['profilePicture'],
      nationality: map['nationality'],
      motherhoodStatus: map['motherhoodStatus'],
      description: map['description'],
    );
  }

  factory KinLocationModel.fromFirestore(
    String userId,
    Map<String, dynamic> data,
  ) {
    final location = data['location'] as Map<String, dynamic>? ?? {};
    final profile = data as Map<String, dynamic>? ?? {};

    return KinLocationModel(
      userId: userId,
      latitude: (location['latitude'] ?? 0.0).toDouble(),
      longitude: (location['longitude'] ?? 0.0).toDouble(),
      updatedAt: location['updatedAt']?.toDate() ?? DateTime.now(),
      isVisible: location['isVisible'] ?? true,
      name: profile['name'],
      profilePicture: profile['profilePicture'],
      nationality: profile['nationality'],
      motherhoodStatus: profile['status'] ?? profile['motherhoodStatus'],
      description: profile['description'],
    );
  }

  /// From backend API user object (GET /me or GET /users/nearby item).
  /// Supports top-level latitude/longitude or location subdocument.
  factory KinLocationModel.fromBackend(String userId, Map<String, dynamic> data) {
    final loc = data['location'] as Map<String, dynamic>?;
    double lat = 0.0;
    double lng = 0.0;
    DateTime updated = DateTime.now();
    bool isVisible = data['locationIsVisible'] == true || (loc?['isVisible'] == true);
    if (data['latitude'] != null && data['longitude'] != null) {
      lat = (data['latitude'] as num).toDouble();
      lng = (data['longitude'] as num).toDouble();
      final at = data['locationUpdatedAt'] ?? loc?['updatedAt'];
      if (at != null) updated = DateTime.tryParse(at.toString()) ?? updated;
    } else if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
      lat = (loc['latitude'] as num).toDouble();
      lng = (loc['longitude'] as num).toDouble();
      final at = loc['updatedAt'];
      if (at != null) updated = DateTime.tryParse(at.toString()) ?? updated;
    }
    return KinLocationModel(
      userId: userId,
      latitude: lat,
      longitude: lng,
      updatedAt: updated,
      isVisible: isVisible,
      name: data['name']?.toString() ?? data['displayName']?.toString(),
      profilePicture: data['profilePictureUrl']?.toString() ?? data['profilePicture']?.toString(),
      nationality: data['nationality']?.toString(),
      motherhoodStatus: data['status']?.toString() ?? data['motherhoodStatus']?.toString(),
      description: data['bio']?.toString(),
    );
  }

  double distanceTo(double lat, double lng) {
    // Simple distance calculation using geolocator
    // This will be calculated using LocationService
    // For now, return 0 and calculate in service layer
    return 0.0;
  }
}
