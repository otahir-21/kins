import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/widgets/kins_logo.dart';

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

  Future<void> _sendOTP() async {
    if (_completePhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number'),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 2),
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
          backgroundColor: Colors.black,
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const KinsLogo(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    const Text(
                      'Motherhood unmuted.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    SignInCard(
                      isLoading: authState.isLoading,
                      onContinue: (String fullPhone) {
                        setState(() => _completePhoneNumber = fullPhone);
                        _sendOTP();
                      },
                    ),
                    const SizedBox(height: 8),

                    SocialLoginDivider(),
                    const SizedBox(height: 20),
                    const TermsAndPolicyDisclaimer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Terms and policy disclaimer below signup/login. Links open in external browser.
class TermsAndPolicyDisclaimer extends StatelessWidget {
  const TermsAndPolicyDisclaimer({super.key});

  static const Color _bodyColor = Colors.grey;
  static const Color _linkColor = Colors.blue;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: DefaultTextStyle.of(context).style.copyWith(
              fontSize: 12,
              color: _bodyColor,
            ),
            children: [
              const TextSpan(text: 'By signing up, you agree to our '),
              TextSpan(
                text: 'Terms of Service',
                style: const TextStyle(
                  color: _linkColor,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _openUrl('https://example.com/terms'),
              ),
              const TextSpan(text: ', '),
              TextSpan(
                text: 'Community Guidelines',
                style: const TextStyle(
                  color: _linkColor,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _openUrl('https://example.com/community-guidelines'),
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: const TextStyle(
                  color: _linkColor,
                  decoration: TextDecoration.underline,
                ),
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
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Sign in",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Phone input container
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xffF2F2F2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  // Country code dropdown
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCode,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      items: gccCountries.map((country) {
                        return DropdownMenuItem(
                          value: country["code"],
                          child: Text(
                            country["code"]!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedCode = value!);
                      },
                    ),
                  ),

                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 22,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 10),

                  // Phone number field (E.164: country code + digits)
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !widget.isLoading,
                      decoration: const InputDecoration(
                        hintText: "Mobile Number",
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
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
            SizedBox(
              height: 52,
              width: double.infinity,
              child: Material(
                color: widget.isLoading
                    ? Colors.grey
                    : const Color(0xffEDEDED),
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: widget.isLoading
                      ? null
                      : () {
                          final digits = _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
                          final fullPhone = selectedCode + digits;
                          if (digits.length < 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid phone number'),
                                backgroundColor: Colors.black,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          widget.onContinue(fullPhone);
                        },
                  borderRadius: BorderRadius.circular(30),
                  child: Center(
                    child: widget.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
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

class SocialLoginDivider extends StatelessWidget {
  const SocialLoginDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),

        // Divider with text
        Row(
          children: const [
            Expanded(child: Divider(thickness: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Or continue with',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(child: Divider(thickness: 1)),
          ],
        ),

        const SizedBox(height: 20),

        // Social buttons: same height and width, consistent spacing
        const _SocialButtonHeight(),
      ],
    );
  }
}

/// Shared height for Apple and Google buttons (UI only).
const double _kSocialButtonHeight = 44.0;

class _SocialButtonHeight extends StatelessWidget {
  const _SocialButtonHeight();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),

        SizedBox(
          height: _kSocialButtonHeight,
          width: double.infinity,
          child: _GoogleSignInButton(height: _kSocialButtonHeight),
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: _kSocialButtonHeight,
          width: double.infinity,
          child: SignInWithAppleButton(
            onPressed: () {
              // Apple login - UI only
            },
            height: _kSocialButtonHeight,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

/// Custom Google button: official G logo on the left + "Sign in with Google" (UI only).
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          // Google login - UI only
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Official Google "G" logo (unchanged, no recolor)
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
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
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
