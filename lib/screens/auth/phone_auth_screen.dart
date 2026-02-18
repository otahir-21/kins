import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/services/auth_flow_service.dart';
import 'package:kins_app/services/backend_auth_service.dart';
import 'package:kins_app/widgets/auth_flow_layout.dart';
import 'package:kins_app/widgets/app_card.dart';
import 'package:kins_app/widgets/secondary_button.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _completePhoneNumber = '';
  bool _isNavigating = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (!AppConstants.useFirebaseAuth) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Google sign-in is only available with Firebase Auth'),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          );
      }
      return;
    }
    try {
      final result = await ref.read(authProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      if (result == null) return;
      final backendResult = await BackendAuthService.login(
        provider: 'google',
        providerUserId: result.user.uid,
        email: result.googleProfile?.email,
        name: result.googleProfile?.name,
        profilePictureUrl: null,
      );
      if (!mounted) return;
      AuthFlowService.navigateAfterAuth(
        context,
        profileStatus: backendResult.profileStatus,
        googleProfile: result.googleProfile,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(authProvider).error ?? e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendOTP() async {
    if (_completePhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid phone number'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    ref.read(authProvider.notifier).clearError();
    _isNavigating = false;
    await ref.read(authProvider.notifier).sendOTP(_completePhoneNumber);

    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (!_isNavigating) {
      _isNavigating = true;
      context.go(
        '${AppConstants.routeOtpVerification}?phone=${Uri.encodeComponent(_completePhoneNumber)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AuthFlowLayout(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                Responsive.screenPaddingH(context),
                Responsive.spacing(context, 8),
                Responsive.screenPaddingH(context),
                Responsive.screenPaddingH(context),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Motherhood unmuted.',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ) ?? TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SignInCard(
                      isLoading: authState.isLoading,
                      onContinue: (String fullPhone) {
                        setState(() => _completePhoneNumber = fullPhone);
                        _sendOTP();
                      },
                    ),
                    const SizedBox(height: 8),
                    SocialLoginDivider(onGooglePressed: _handleGoogleSignIn),
                    const SizedBox(height: 20),
                    const TermsAndPolicyDisclaimer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Terms and policy disclaimer below signup/login. Links open in external browser.
class TermsAndPolicyDisclaimer extends StatelessWidget {
  const TermsAndPolicyDisclaimer({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    ) ?? TextStyle(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
      fontFamily: theme.textTheme.bodyLarge?.fontFamily,
    );
    final linkStyle = textStyle.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: textStyle,
            children: [
              const TextSpan(text: 'By signing up, you agree to our '),
              TextSpan(
                text: 'Terms of Service',
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _openUrl('https://example.com/terms'),
              ),
              const TextSpan(text: ', '),
              TextSpan(
                text: 'Community Guidelines',
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _openUrl('https://example.com/community-guidelines'),
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _openUrl('https://example.com/privacy'),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      ),
    );
  }
}

class SignInCard extends StatefulWidget {
  const SignInCard({
    super.key,
    required this.onContinue,
    this.isLoading = false,
  });

  final void Function(String fullPhone) onContinue;
  final bool isLoading;

  @override
  State<SignInCard> createState() => _SignInCardState();
}

class _SignInCardState extends State<SignInCard> {
  String selectedCode = "+971";
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> gccCountries = [
    {"name": "UAE", "code": "+971"},
    {"name": "Saudi Arabia", "code": "+966"},
    {"name": "Qatar", "code": "+974"},
    {"name": "Kuwait", "code": "+965"},
    {"name": "Oman", "code": "+968"},
    {"name": "Bahrain", "code": "+973"},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Center(
      child: AppCard(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sign in",
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ) ?? TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: textTheme.bodyLarge?.fontFamily,
              ),
            ),
            const SizedBox(height: 16),

            // Phone input container
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xffF5F5F5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  // Country code picker (bottom sheet instead of dropdown)
                  GestureDetector(
                    onTap: () => _showCountryCodePicker(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedCode,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey.shade600),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 22,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 10),

                  // Phone number field (E.164: country code + digits) - same font as app text fields
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !widget.isLoading,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Mobile Number",
                        hintStyle: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          color: Colors.grey.shade600,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        filled: true,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Continue button
            SecondaryButton(
              onPressed: () {
                final digits = _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
                final fullPhone = selectedCode + digits;
                if (digits.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter a valid phone number'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                widget.onContinue(fullPhone);
              },
              label: 'Continue',
              isLoading: widget.isLoading,
            ),
          ],
        ),
      ),
    );
  }

  void _showCountryCodePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                child: Text('Country code', style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600, color: Colors.black)),
              ),
              const Divider(height: 1),
              ListView.builder(
                shrinkWrap: true,
                itemCount: gccCountries.length,
                itemBuilder: (ctx, i) {
                  final c = gccCountries[i];
                  final code = c['code']!;
                  final name = c['name']!;
                  return ListTile(
                    title: Text('$name  $code', style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: Colors.black)),
                    onTap: () {
                      setState(() => selectedCode = code);
                      Navigator.of(ctx).pop();
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SocialLoginDivider extends StatelessWidget {
  const SocialLoginDivider({super.key, this.onGooglePressed});

  final VoidCallback? onGooglePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),

        // Divider with text
        Row(
          children: [
            Expanded(child: Divider(thickness: 0.5, color: Colors.grey)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Or continue with',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: Divider(thickness: 0.5, color: Colors.grey)),
          ],
        ),

        const SizedBox(height: 20),

        _SocialButtonHeight(onGooglePressed: onGooglePressed),
      ],
    );
  }
}

/// Shared height and text style for Apple and Google buttons (same font on both).
const double _kSocialButtonHeight = 44.0;

TextStyle _socialButtonTextStyle(BuildContext context) {
  final base = Theme.of(context).textTheme.bodyMedium;
  final color = Theme.of(context).colorScheme.onSurfaceVariant;
  return (base ?? const TextStyle()).copyWith(
    fontSize: 15,
    color: color,
    fontWeight: FontWeight.w500,
  );
}

class _SocialButtonHeight extends StatelessWidget {
  const _SocialButtonHeight({this.onGooglePressed});

  final VoidCallback? onGooglePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),

        SizedBox(
          height: _kSocialButtonHeight,
          width: double.infinity,
          child: _GoogleSignInButton(
            height: _kSocialButtonHeight,
            onTap: onGooglePressed,
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: _kSocialButtonHeight,
          width: double.infinity,
          child: _AppleSignInButton(
            height: _kSocialButtonHeight,
            onTap: () {
              // Apple login - UI only
            },
          ),
        ),
      ],
    );
  }
}

/// Custom Google button: official G logo + "Sign in with Google". Uses theme font.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.height, this.onTap});

  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xffEFEFEF),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                height: 24,
                width: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(width: 24, height: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Sign in with Google',
                style: _socialButtonTextStyle(context).copyWith(color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Apple button: same font as Google, black bg per Apple HIG.
class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({required this.height, this.onTap});

  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.apple, size: 24, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Sign in with Apple',
                style: _socialButtonTextStyle(context).copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color color;

  const _SocialButton({
    required this.child,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
