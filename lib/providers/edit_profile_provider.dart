import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/repositories/interest_repository.dart';

/// Editable profile data for Edit Profile screen.
class EditProfileData {
  final String? name;
  final String? bio;
  final String? username;
  final String? email;
  final String? phoneNumber;
  final String? country;
  final String? city;
  final String? profilePictureUrl;
  final List<String> interestIds;

  EditProfileData({
    this.name,
    this.bio,
    this.username,
    this.email,
    this.phoneNumber,
    this.country,
    this.city,
    this.profilePictureUrl,
    this.interestIds = const [],
  });

  EditProfileData copyWith({
    String? name,
    String? bio,
    String? username,
    String? email,
    String? phoneNumber,
    String? country,
    String? city,
    String? profilePictureUrl,
    List<String>? interestIds,
  }) {
    return EditProfileData(
      name: name ?? this.name,
      bio: bio ?? this.bio,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      country: country ?? this.country,
      city: city ?? this.city,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      interestIds: interestIds ?? this.interestIds,
    );
  }

  bool _same(String? a, String? b) =>
      (a ?? '').trim() == (b ?? '').trim();

  bool listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = Set<String>.from(a);
    final sb = Set<String>.from(b);
    return sa.length == sb.length && sa.containsAll(sb);
  }

  bool isSameAs(EditProfileData other) =>
      _same(name, other.name) &&
      _same(bio, other.bio) &&
      _same(username, other.username) &&
      _same(email, other.email) &&
      _same(phoneNumber, other.phoneNumber) &&
      _same(country, other.country) &&
      _same(city, other.city) &&
      _same(profilePictureUrl, other.profilePictureUrl) &&
      listEquals(interestIds, other.interestIds);
}

class EditProfileNotifier extends StateNotifier<AsyncValue<EditProfileState>> {
  final Ref _ref;

  EditProfileNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  EditProfileState get _current =>
      state.valueOrNull ?? EditProfileState.initial();

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final uid = currentUserId;
      if (uid.isEmpty) {
        state = AsyncValue.data(EditProfileState.initial());
        return;
      }
      final userRepo = _ref.read(userDetailsRepositoryProvider);
      final interestRepo = InterestRepository();
      final me = await userRepo.getMeRaw();
      final interestIds = await interestRepo.getUserInterests(uid);
      final data = EditProfileData(
        name: me['name']?.toString(),
        bio: me['bio']?.toString(),
        username: me['username']?.toString(),
        email: me['email']?.toString(),
        phoneNumber: me['phoneNumber']?.toString(),
        country: me['country']?.toString(),
        city: me['city']?.toString(),
        profilePictureUrl: me['profilePictureUrl']?.toString(),
        interestIds: interestIds,
      );
      state = AsyncValue.data(EditProfileState(
        originalUser: data,
        editedUser: data,
        isSaving: false,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateName(String v) {
    final s = _current;
    state = AsyncValue.data(s.copyWith(
      editedUser: s.editedUser.copyWith(name: v.isEmpty ? null : v),
    ));
  }

  void updateBio(String v) {
    final s = _current;
    state = AsyncValue.data(s.copyWith(
      editedUser: s.editedUser.copyWith(bio: v.isEmpty ? null : v),
    ));
  }

  void updateUsername(String v) {
    final s = _current;
    state = AsyncValue.data(s.copyWith(
      editedUser: s.editedUser.copyWith(username: v.isEmpty ? null : v),
    ));
  }

  void updateEmail(String v) {
    final s = _current;
    state = AsyncValue.data(s.copyWith(
      editedUser: s.editedUser.copyWith(email: v.isEmpty ? null : v),
    ));
  }

  void updatePhone(String v) {
    final s = _current;
    state = AsyncValue.data(s.copyWith(
      editedUser: s.editedUser.copyWith(phoneNumber: v.isEmpty ? null : v),
    ));
  }

  void updateCountry(String? v) {
    final s = _current;
    state = AsyncValue.data(s.copyWith(
      editedUser: s.editedUser.copyWith(country: v),
    ));
  }

  void updateCity(String? v) {
    final s = _current;
    state = AsyncValue.data(s.copyWith(
      editedUser: s.editedUser.copyWith(city: v),
    ));
  }

  void toggleInterest(String id) {
    final s = _current;
    final ids = List<String>.from(s.editedUser.interestIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    state = AsyncValue.data(s.copyWith(
      editedUser: s.editedUser.copyWith(interestIds: ids),
    ));
  }

  Future<bool> save() async {
    final s = _current;
    if (!s.hasChanges || s.isSaving) return false;
    state = AsyncValue.data(s.copyWith(isSaving: true));
    try {
      final orig = s.originalUser;
      final edit = s.editedUser;
      final body = <String, dynamic>{};
      if (!_same(orig.name, edit.name)) body['name'] = edit.name?.trim();
      if (!_same(orig.bio, edit.bio)) body['bio'] = edit.bio?.trim();
      if (!_same(orig.username, edit.username)) body['username'] = edit.username?.trim();
      if (!_same(orig.email, edit.email)) body['email'] = edit.email?.trim();
      if (!_same(orig.phoneNumber, edit.phoneNumber)) body['phoneNumber'] = edit.phoneNumber?.trim();
      if (!_same(orig.country, edit.country)) body['country'] = edit.country?.trim();
      if (!_same(orig.city, edit.city)) body['city'] = edit.city?.trim();
      if (!_same(orig.profilePictureUrl, edit.profilePictureUrl)) body['profilePictureUrl'] = edit.profilePictureUrl;

      if (body.isNotEmpty) {
        final repo = _ref.read(userDetailsRepositoryProvider);
        await repo.updateProfilePartial(body);
      }
      if (!_listEquals(orig.interestIds, edit.interestIds)) {
        final interestRepo = InterestRepository();
        await interestRepo.saveUserInterests(userId: currentUserId, interestIds: edit.interestIds);
      }

      state = AsyncValue.data(EditProfileState(
        originalUser: edit,
        editedUser: edit,
        isSaving: false,
      ));
      return true;
    } catch (e) {
      state = AsyncValue.data(s.copyWith(isSaving: false));
      rethrow;
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = Set<String>.from(a);
    return sa.containsAll(b);
  }

  bool _same(String? a, String? b) => (a ?? '').trim() == (b ?? '').trim();
}

class EditProfileState {
  final EditProfileData originalUser;
  final EditProfileData editedUser;
  final bool isSaving;

  EditProfileState({
    required this.originalUser,
    required this.editedUser,
    this.isSaving = false,
  });

  static EditProfileState initial() => EditProfileState(
        originalUser: EditProfileData(),
        editedUser: EditProfileData(),
      );

  bool get hasChanges => !originalUser.isSameAs(editedUser);

  EditProfileState copyWith({
    EditProfileData? originalUser,
    EditProfileData? editedUser,
    bool? isSaving,
  }) =>
      EditProfileState(
        originalUser: originalUser ?? this.originalUser,
        editedUser: editedUser ?? this.editedUser,
        isSaving: isSaving ?? this.isSaving,
      );
}

final editProfileProvider =
    StateNotifierProvider<EditProfileNotifier, AsyncValue<EditProfileState>>(
  (ref) => EditProfileNotifier(ref),
);
