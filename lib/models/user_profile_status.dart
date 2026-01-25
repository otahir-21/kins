/// Represents the completion status of a user's profile
class UserProfileStatus {
  final bool exists;
  final bool hasProfile; // Has name, email, dateOfBirth
  final bool hasInterests; // Has at least one interest
  final String? userId; // Firestore document ID
  final String? phoneNumber;

  UserProfileStatus({
    required this.exists,
    this.hasProfile = false,
    this.hasInterests = false,
    this.userId,
    this.phoneNumber,
  });

  /// Check if profile is complete (has all required fields)
  bool get isComplete => hasProfile && hasInterests;

  /// Check if user needs to complete profile
  bool get needsProfile => !hasProfile;

  /// Check if user needs to select interests
  bool get needsInterests => hasProfile && !hasInterests;
}
