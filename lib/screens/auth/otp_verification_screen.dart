import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/services/auth_flow_service.dart';
import 'package:kins_app/services/backend_auth_service.dart';

import '../../widgets/app_card.dart';
import '../../widgets/auth_flow_layout.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/skeleton/skeleton_loaders.dart';

bool _isServerUnavailable(String message) {
  final lower = message.toLowerCase();
  return lower.contains('timed out') ||
      lower.contains('buffering') ||
      lower.contains('econnrefused') ||
      lower.contains('connection');
}

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isDisposed = false;
  bool _isCheckingUser = false;
  int _resendCooldownSeconds = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isDisposed) return;
      setState(() {
        _resendCooldownSeconds = (_resendCooldownSeconds - 1).clamp(0, 60);
      });
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _resendTimer?.cancel();
    try {
      _otpController.dispose();
    } catch (e) {
      // Controller might already be disposed, ignore
    }
    super.dispose();
  }

  Future<void> _verifyOTP(String otp) async {
    if (otp.length != 6 || _isDisposed) return;

    setState(() => _isCheckingUser = true);
    await ref.read(authProvider.notifier).verifyOTP(widget.phoneNumber, otp);

    if (!mounted || _isDisposed) return;
    final authState = ref.read(authProvider);

    if (authState.error != null) {
      setState(() => _isCheckingUser = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (authState.user == null) {
      setState(() => _isCheckingUser = false);
      return;
    }

    debugPrint('✅ OTP verified, user: ${authState.user!.uid}');

    try {
      final result = await BackendAuthService.login(
        provider: 'phone',
        providerUserId: authState.user!.uid,
        phoneNumber: widget.phoneNumber,
      );
      if (!mounted || _isDisposed) return;
      setState(() => _isCheckingUser = false);
      AuthFlowService.navigateAfterAuth(context, profileStatus: result.profileStatus);
    } catch (e) {
      debugPrint('❌ Backend login failed: $e');
      if (mounted && !_isDisposed) {
        setState(() => _isCheckingUser = false);
        final msg = e is BackendApiException
            ? e.message
            : (e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString());
        final friendly = _isServerUnavailable(msg)
            ? 'Server is temporarily unavailable. Please try again in a moment.'
            : msg;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendly),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _resendOTP() async {
    debugPrint('🔄 Resending OTP to ${widget.phoneNumber}');
    try {
      await ref.read(authProvider.notifier).sendOTP(widget.phoneNumber);
      if (mounted) {
        final authState = ref.read(authProvider);
        if (authState.error != null) {
          debugPrint('❌ Resend OTP Error: ${authState.error}');
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authState.error!),
                backgroundColor: Colors.black,
                duration: const Duration(seconds: 3),
              ),
            );
          } catch (e) {
            debugPrint('❌ SnackBar Error: $e');
          }
        } else {
          if (mounted) setState(() => _resendCooldownSeconds = 60);
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP resent successfully'),
                backgroundColor: Colors.black,
                duration: Duration(seconds: 2),
              ),
            );
          } catch (e) {
            debugPrint('❌ SnackBar Error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Resend OTP Exception: $e');
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to resend OTP: $e'),
              backgroundColor: Colors.black,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (snackError) {
          debugPrint('❌ SnackBar Error: $snackError');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: AuthFlowLayout(
        children: [
          Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.screenPaddingH(context),
                  vertical: Responsive.spacing(context, 16),
                ),
                child: AppCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.screenPaddingH(context),
                    vertical: Responsive.spacing(context, 28),
                  ),
                  constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Enter OTP',
                        style: textTheme.titleLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'We have sent the OTP on your registered number:',
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.phoneNumber,
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (mounted && !_isDisposed)
                        PinCodeTextField(
                          appContext: context,
                          length: 6,
                          controller: _otpController,
                          pinTheme: PinTheme(
                            shape: PinCodeFieldShape.box,
                            borderRadius: BorderRadius.circular(12),
                            fieldHeight: 52,
                            fieldWidth: 42,
                            activeFillColor: Colors.grey.shade100,
                            inactiveFillColor: Colors.grey.shade100,
                            selectedFillColor: Colors.grey.shade200,
                            activeColor: Colors.black,
                            inactiveColor: Colors.grey.shade300,
                            selectedColor: Colors.black,
                          ),
                          enableActiveFill: true,
                          keyboardType: TextInputType.number,
                          onCompleted: _isDisposed ? null : _verifyOTP,
                          onChanged: (value) => setState(() {}),
                        )
                      else
                        const SizedBox(height: 52),
                      const SizedBox(height: 24),
                      SecondaryButton(
                        onPressed: (_isDisposed || !mounted)
                            ? null
                            : () {
                                if (!mounted || _isDisposed) return;
                                final otp = _otpController.text;
                                if (otp.length != 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Please enter 6-digit OTP'),
                                      backgroundColor: Theme.of(context).colorScheme.error,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                _verifyOTP(otp);
                              },
                        label: 'Continue',
                        isLoading: authState.isLoading || _isCheckingUser,
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _resendCooldownSeconds > 0
                            ? RichText(
                                text: TextSpan(
                                  style: textTheme.bodySmall?.copyWith(fontSize: 13, color: Colors.grey.shade700),
                                  children: [
                                    const TextSpan(text: 'You can resend OTP in '),
                                    TextSpan(
                                      text: '${_resendCooldownSeconds}s',
                                      style: textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : TextButton(
                                onPressed: authState.isLoading ? null : _resendOTP,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Resend OTP',
                                  style: textTheme.bodySmall?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                      ),
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
