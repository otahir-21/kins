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

  double distanceTo(double lat, double lng) {
    // Simple distance calculation using geolocator
    // This will be calculated using LocationService
    // For now, return 0 and calculate in service layer
    return 0.0;
  }
}
