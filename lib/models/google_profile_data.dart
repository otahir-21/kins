/// Profile data from Google Sign-In to pre-fill and lock fields on About You screen.
class GoogleProfileData {
  const GoogleProfileData({
    this.name,
    this.email,
    this.phoneNumber,
    this.dateOfBirth,
  });

  final String? name;
  final String? email;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
}
