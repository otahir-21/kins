import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/widgets/kins_logo.dart';

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
  const UserDetailsScreen({super.key});

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

  Timer? _usernameDebounce;
  Timer? _emailDebounce;
  Timer? _phoneDebounce;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _emailController.addListener(_onEmailChanged);
    _phoneController.addListener(_onPhoneChanged);
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
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );
    if (picked != null) setState(() => _selectedDateOfBirth = picked);
    return picked;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (_selectedDateOfBirth == null) return;
    final authState = ref.read(authProvider);
    final userId = authState.user?.uid;
    if (userId == null) {
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
      body: SafeArea(
        child: Column(
          children: [
            const KinsLogo(),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
                ),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 500),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
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
                          onChanged: (v) => ref.read(userDetailsProvider.notifier).setName(v),
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
                              onTap: () async {
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
                          availabilityStatus: _phoneStatus,
                          availabilityLabel: 'Phone number',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your phone number';
                            if (v.replaceAll(RegExp(r'\s'), '').length < 8) return 'Please enter a valid phone number';
                            if (_phoneStatus == _AvailabilityStatus.taken) return 'Phone number already taken';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _ThemedTextField(
                          controller: _emailController,
                          hint: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          theme: theme,
                          onChanged: (v) => ref.read(userDetailsProvider.notifier).setEmail(v),
                          availabilityStatus: _emailStatus,
                          availabilityLabel: 'Email',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your email';
                            if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
                            if (_emailStatus == _AvailabilityStatus.taken) return 'Email already taken';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: userDetailsState.isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: userDetailsState.isSubmitting
                                  ? Colors.grey.shade300
                                  : Colors.black,
                              foregroundColor: userDetailsState.isSubmitting
                                  ? Colors.grey.shade600
                                  : Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: userDetailsState.isSubmitting
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey.shade600,
                                    ),
                                  )
                                : Text(
                                    'Continue',
                                    style: textTheme.labelLarge?.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  static final _pillRadius = BorderRadius.circular(26);

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    Widget? suffixIcon;
    String? helperText;
    Color? helperColor;
    if (availabilityLabel != null) {
      switch (availabilityStatus) {
        case _AvailabilityStatus.checking:
          suffixIcon = SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
          );
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
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xffF2F2F2),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    required this.onTap,
    this.errorText,
  });

  final ThemeData theme;
  final DateTime? selectedDate;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final String? errorText;

  static final _pillRadius = BorderRadius.circular(26);

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: _pillRadius,
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: 'Date of birth',
          filled: true,
          fillColor: const Color(0xffF2F2F2),
          border: OutlineInputBorder(borderRadius: _pillRadius),
          enabledBorder: OutlineInputBorder(
            borderRadius: _pillRadius,
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: _pillRadius,
            borderSide: BorderSide(color: colorScheme.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: Icon(Icons.calendar_today, size: 20, color: colorScheme.onSurfaceVariant),
          errorText: errorText,
        ).applyDefaults(theme.inputDecorationTheme),
        child: Text(
          selectedDate != null ? dateFormat.format(selectedDate!) : 'Date of birth',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: selectedDate != null ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
