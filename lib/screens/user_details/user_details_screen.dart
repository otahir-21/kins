import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/models/google_profile_data.dart';
import 'package:kins_app/widgets/app_card.dart';
import 'package:kins_app/widgets/auth_flow_layout.dart';
import 'package:kins_app/widgets/secondary_button.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

/// "About you" profile screen.
///
/// Step 1 – Design understanding:
/// • Overall layout: Dark scaffold; one large white card (rounded corners) containing
///   all form content; logo above the card.
/// • Hierarchy: Logo (top, centered) → section title "About you" (left-aligned, bold) →
///   five grouped inputs (Username, Full Name, Date of birth, Phone, Email) → full-width
///   Continue button.
/// • Inputs: Pill/capsule shape, light fill, no strong borders, consistent vertical spacing;
///   Date of birth has calendar icon.
/// • Button: Full-width, same rounded style as inputs, placed directly below the fields.
/// • Spacing: Generous vertical gaps; consistent horizontal padding; soft look via
///   rounded corners and muted fills. All styling from theme (ColorScheme, textTheme,
///   inputDecorationTheme, cardTheme).
class UserDetailsScreen extends ConsumerStatefulWidget {
  const UserDetailsScreen({super.key, this.googleProfile});

  /// When set (e.g. from Google Sign-In), these fields are pre-filled and read-only.
  final GoogleProfileData? googleProfile;

  @override
  ConsumerState<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

enum _AvailabilityStatus { none, checking, available, taken, error }

class _UserDetailsScreenState extends ConsumerState<UserDetailsScreen> {
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDateOfBirth;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  static const _debounceDuration = Duration(milliseconds: 500);

  _AvailabilityStatus _usernameStatus = _AvailabilityStatus.none;
  _AvailabilityStatus _emailStatus = _AvailabilityStatus.none;
  _AvailabilityStatus _phoneStatus = _AvailabilityStatus.none;

  bool _nameLockedFromGoogle = false;
  bool _emailLockedFromGoogle = false;
  bool _phoneLockedFromGoogle = false;
  bool _dobLockedFromGoogle = false;

  Timer? _usernameDebounce;
  Timer? _emailDebounce;
  Timer? _phoneDebounce;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _emailController.addListener(_onEmailChanged);
    _phoneController.addListener(_onPhoneChanged);
    _applyGoogleProfile();
  }

  void _applyGoogleProfile() {
    final g = widget.googleProfile;
    // When from phone auth (no googleProfile), pre-fill phone from storage
    if (g == null) {
      final phone = currentUserPhone;
      if (phone != null && phone.trim().isNotEmpty && _phoneController.text.isEmpty) {
        _phoneController.text = phone.trim();
      }
      return;
    }
    if (g.name != null && g.name!.trim().isNotEmpty) {
      _nameController.text = g.name!.trim();
      _nameLockedFromGoogle = true;
    }
    if (g.email != null && g.email!.trim().isNotEmpty) {
      _emailController.text = g.email!.trim();
      _emailLockedFromGoogle = true;
    }
    if (g.phoneNumber != null && g.phoneNumber!.trim().isNotEmpty) {
      _phoneController.text = g.phoneNumber!.trim();
      _phoneLockedFromGoogle = true;
    }
    if (g.dateOfBirth != null) {
      _selectedDateOfBirth = g.dateOfBirth;
      _dobLockedFromGoogle = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(userDetailsProvider.notifier);
      if (_nameController.text.trim().isNotEmpty) notifier.setName(_nameController.text.trim());
      if (_emailController.text.trim().isNotEmpty) notifier.setEmail(_emailController.text.trim());
      if (_selectedDateOfBirth != null) notifier.setDateOfBirth(_selectedDateOfBirth!);
    });
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    final value = _usernameController.text;
    final norm = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (norm.length < 2) {
      setState(() => _usernameStatus = _AvailabilityStatus.none);
      return;
    }
    setState(() => _usernameStatus = _AvailabilityStatus.checking);
    _usernameDebounce = Timer(_debounceDuration, () => _checkUsername(value));
  }

  void _onEmailChanged() {
    _emailDebounce?.cancel();
    final value = _emailController.text;
    if (value.trim().isEmpty || !value.contains('@')) {
      setState(() => _emailStatus = _AvailabilityStatus.none);
      return;
    }
    setState(() => _emailStatus = _AvailabilityStatus.checking);
    _emailDebounce = Timer(_debounceDuration, () => _checkEmail(value));
  }

  void _onPhoneChanged() {
    _phoneDebounce?.cancel();
    final value = _phoneController.text;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) {
      setState(() => _phoneStatus = _AvailabilityStatus.none);
      return;
    }
    setState(() => _phoneStatus = _AvailabilityStatus.checking);
    _phoneDebounce = Timer(_debounceDuration, () => _checkPhone(value));
  }

  Future<void> _checkUsername(String value) async {
    final userId = ref.read(authProvider).user?.uid;
    final repo = ref.read(userDetailsRepositoryProvider);
    try {
      final available = await repo.checkUsernameAvailable(value, currentUserId: userId);
      if (!mounted) return;
      setState(() => _usernameStatus =
          available ? _AvailabilityStatus.available : _AvailabilityStatus.taken);
    } catch (_) {
      if (!mounted) return;
      setState(() => _usernameStatus = _AvailabilityStatus.error);
    }
  }

  Future<void> _checkEmail(String value) async {
    final userId = ref.read(authProvider).user?.uid;
    final repo = ref.read(userDetailsRepositoryProvider);
    try {
      final available = await repo.checkEmailAvailable(value, currentUserId: userId);
      if (!mounted) return;
      setState(() => _emailStatus =
          available ? _AvailabilityStatus.available : _AvailabilityStatus.taken);
    } catch (_) {
      if (!mounted) return;
      setState(() => _emailStatus = _AvailabilityStatus.error);
    }
  }

  Future<void> _checkPhone(String value) async {
    final userId = ref.read(authProvider).user?.uid;
    final repo = ref.read(userDetailsRepositoryProvider);
    try {
      final available = await repo.checkPhoneAvailable(value, currentUserId: userId);
      if (!mounted) return;
      setState(() => _phoneStatus =
          available ? _AvailabilityStatus.available : _AvailabilityStatus.taken);
    } catch (_) {
      if (!mounted) return;
      setState(() => _phoneStatus = _AvailabilityStatus.error);
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _emailDebounce?.cancel();
    _phoneDebounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _emailController.removeListener(_onEmailChanged);
    _phoneController.removeListener(_onPhoneChanged);
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<DateTime?> _selectDateOfBirth() async {
    final initialDate = _selectedDateOfBirth ??
        DateTime.now().subtract(const Duration(days: 365 * 18));
    final firstDate = DateTime(1900);
    final lastDate = DateTime.now();

    if (Platform.isIOS) {
      DateTime selectedDate = initialDate.isBefore(firstDate)
          ? firstDate
          : (initialDate.isAfter(lastDate) ? lastDate : initialDate);
      final picked = await showCupertinoModalPopup<DateTime>(
        context: context,
        builder: (ctx) => Container(
            height: 320,
            color: Theme.of(ctx).scaffoldBackgroundColor,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    onPressed: () => Navigator.pop(ctx, selectedDate),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoTheme.of(ctx).copyWith(
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 20,
                        color: CupertinoColors.label.resolveFrom(ctx),
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: selectedDate,
                    minimumDate: firstDate,
                    maximumDate: lastDate,
                    onDateTimeChanged: (v) => selectedDate = v,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (picked != null) setState(() => _selectedDateOfBirth = picked);
      return picked;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) setState(() => _selectedDateOfBirth = picked);
    return picked;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (_selectedDateOfBirth == null) return;
    // Use authProvider.user first; fallback to currentUserId (storage/Firebase) for app restart
    final authState = ref.read(authProvider);
    final userId = authState.user?.uid ?? currentUserId;
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User not authenticated'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    ref.read(userDetailsProvider.notifier).setName(_nameController.text.trim());
    ref.read(userDetailsProvider.notifier).setEmail(_emailController.text.trim());
    ref.read(userDetailsProvider.notifier).setDateOfBirth(_selectedDateOfBirth!);
    await ref.read(userDetailsProvider.notifier).submitUserDetails(
          userId,
          username: _usernameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );
    final userDetailsState = ref.read(userDetailsProvider);
    if (!mounted) return;
    if (userDetailsState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userDetailsState.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      context.go(AppConstants.routeInterests);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final userDetailsState = ref.watch(userDetailsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: AuthFlowLayout(
        children: [
          Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: Responsive.screenPaddingH(context),
                  right: Responsive.screenPaddingH(context),
                  top: Responsive.spacing(context, 16),
                  bottom: MediaQuery.viewPaddingOf(context).bottom + Responsive.screenPaddingH(context),
                ),
                child: AppCard(
                  constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'About you',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ) ?? TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              fontFamily: textTheme.bodyLarge?.fontFamily,
                            ),
                          )
                        ),
                        const SizedBox(height: 20),
                        _ThemedTextField(
                          controller: _usernameController,
                          hint: 'Username',
                          textCapitalization: TextCapitalization.none,
                          theme: theme,
                          availabilityStatus: _usernameStatus,
                          availabilityLabel: 'Username',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your username';
                            if (_usernameStatus == _AvailabilityStatus.taken) return 'Username already taken';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _ThemedTextField(
                          controller: _nameController,
                          hint: 'Full Name',
                          theme: theme,
                          readOnly: _nameLockedFromGoogle,
                          onChanged: _nameLockedFromGoogle ? null : (v) => ref.read(userDetailsProvider.notifier).setName(v),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null,
                        ),
                        const SizedBox(height: 16),
                        FormField<DateTime?>(
                          initialValue: _selectedDateOfBirth,
                          validator: (v) => v == null ? 'Please select your date of birth' : null,
                          onSaved: (v) => setState(() => _selectedDateOfBirth = v),
                          builder: (state) {
                            final value = state.value ?? _selectedDateOfBirth;
                            return _DateOfBirthField(
                              theme: theme,
                              selectedDate: value,
                              dateFormat: _dateFormat,
                              errorText: state.errorText,
                              readOnly: _dobLockedFromGoogle,
                              onTap: _dobLockedFromGoogle
                                  ? null
                                  : () async {
                                      final picked = await _selectDateOfBirth();
                                      if (picked != null) {
                                        state.didChange(picked);
                                        setState(() => _selectedDateOfBirth = picked);
                                      }
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _ThemedTextField(
                          controller: _phoneController,
                          hint: 'Phone',
                          keyboardType: TextInputType.phone,
                          theme: theme,
                          readOnly: _phoneLockedFromGoogle,
                          availabilityStatus: _phoneLockedFromGoogle ? _AvailabilityStatus.none : _phoneStatus,
                          availabilityLabel: 'Phone number',
                          onChanged: _phoneLockedFromGoogle ? null : (v) {},
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your phone number';
                            if (v.replaceAll(RegExp(r'\s'), '').length < 8) return 'Please enter a valid phone number';
                            if (!_phoneLockedFromGoogle && _phoneStatus == _AvailabilityStatus.taken) return 'Phone number already taken';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _ThemedTextField(
                          controller: _emailController,
                          hint: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          theme: theme,
                          readOnly: _emailLockedFromGoogle,
                          availabilityStatus: _emailLockedFromGoogle ? _AvailabilityStatus.none : _emailStatus,
                          availabilityLabel: 'Email',
                          onChanged: _emailLockedFromGoogle ? null : (v) => ref.read(userDetailsProvider.notifier).setEmail(v),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your email';
                            if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
                            if (!_emailLockedFromGoogle && _emailStatus == _AvailabilityStatus.taken) return 'Email already taken';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SecondaryButton(
                          onPressed: userDetailsState.isSubmitting ? null : _submitForm,
                          isLoading: userDetailsState.isSubmitting,
                          label: 'Continue',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemedTextField extends StatelessWidget {
  const _ThemedTextField({
    required this.controller,
    required this.hint,
    required this.theme,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.words,
    this.onChanged,
    this.validator,
    this.availabilityStatus = _AvailabilityStatus.none,
    this.availabilityLabel,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final ThemeData theme;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final _AvailabilityStatus availabilityStatus;
  final String? availabilityLabel;
  final bool readOnly;

  static final _pillRadius = BorderRadius.circular(30);

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    Widget? suffixIcon;
    String? helperText;
    Color? helperColor;
    if (availabilityLabel != null && !readOnly) {
      switch (availabilityStatus) {
        case _AvailabilityStatus.checking:
          suffixIcon = const SkeletonInline(size: 20);
          helperText = 'Checking...';
          helperColor = colorScheme.onSurfaceVariant;
          break;
        case _AvailabilityStatus.available:
          suffixIcon = Icon(Icons.check_circle, color: Colors.green.shade600, size: 22);
          helperText = '$availabilityLabel available';
          helperColor = Colors.green.shade700;
          break;
        case _AvailabilityStatus.taken:
          suffixIcon = Icon(Icons.error, color: colorScheme.error, size: 22);
          helperText = '$availabilityLabel already taken';
          helperColor = colorScheme.error;
          break;
        case _AvailabilityStatus.error:
          suffixIcon = Icon(Icons.error_outline, color: colorScheme.error, size: 22);
          helperText = 'Could not check. Try again.';
          helperColor = colorScheme.error;
          break;
        case _AvailabilityStatus.none:
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          validator: validator,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: Colors.grey.shade600,
            ),
            filled: true,
            fillColor: const Color(0xffF5F5F5),
            border: OutlineInputBorder(borderRadius: _pillRadius),
            enabledBorder: OutlineInputBorder(
              borderRadius: _pillRadius,
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: _pillRadius,
              borderSide: BorderSide(color: colorScheme.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: _pillRadius,
              borderSide: BorderSide(color: colorScheme.error),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            suffixIcon: suffixIcon,
          ).applyDefaults(theme.inputDecorationTheme),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: helperColor,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _DateOfBirthField extends StatelessWidget {
  const _DateOfBirthField({
    required this.theme,
    required this.selectedDate,
    required this.dateFormat,
    this.onTap,
    this.errorText,
    this.readOnly = false,
  });

  final ThemeData theme;
  final DateTime? selectedDate;
  final DateFormat dateFormat;
  final VoidCallback? onTap;
  final String? errorText;
  final bool readOnly;

  static final _pillRadius = BorderRadius.circular(30);

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final decorator = InputDecorator(
        decoration: InputDecoration(
          hintText: 'Date of birth',
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
          filled: true,
          fillColor: const Color(0xffF5F5F5),
          border: OutlineInputBorder(borderRadius: _pillRadius),
          enabledBorder: OutlineInputBorder(
            borderRadius: _pillRadius,
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: _pillRadius,
            borderSide: BorderSide(color: colorScheme.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          suffixIcon: Icon(Icons.calendar_today, size: 20, color: colorScheme.onSurfaceVariant),
          errorText: errorText,
        ).applyDefaults(theme.inputDecorationTheme),
        child: Text(
          selectedDate != null ? dateFormat.format(selectedDate!) : 'Date of birth',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 12,
            color: selectedDate != null ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
        ),
      );
    if (readOnly || onTap == null) {
      return decorator;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: _pillRadius,
      child: decorator,
    );
  }
}
