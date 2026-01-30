class UserModel {
  final String uid;
  final String phoneNumber;
  final DateTime? createdAt;
  final String? name;
  final String? gender;
  final String? documentUrl;
  final String? status; // Motherhood status (Expecting Mother, New Mother, etc.)
  final String? profilePictureUrl;
  final String? bio;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    this.createdAt,
    this.name,
    this.gender,
    this.documentUrl,
    this.status,
    this.profilePictureUrl,
    this.bio,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt?.toIso8601String(),
      'name': name,
      'gender': gender,
      'documentUrl': documentUrl,
      'status': status,
      'profilePictureUrl': profilePictureUrl,
      'bio': bio,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
      name: map['name'],
      gender: map['gender'],
      documentUrl: map['documentUrl'],
      status: map['status'],
      profilePictureUrl: map['profilePictureUrl'],
      bio: map['bio'],
    );
  }
}
