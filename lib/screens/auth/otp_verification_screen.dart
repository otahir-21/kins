import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/repositories/user_details_repository.dart';

import '../../widgets/kins_logo.dart';

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
  final _userDetailsRepository = UserDetailsRepository();
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
      await _userDetailsRepository.savePhoneNumber(
        userId: authState.user!.uid,
        phoneNumber: widget.phoneNumber,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to save phone number: $e');
    }

    await _checkUserAndNavigate(widget.phoneNumber);
  }

  Future<void> _checkUserAndNavigate(String phoneNumber) async {
    try {
      debugPrint('🔍 Checking user status for: $phoneNumber');
      
      final profileStatus = await _userDetailsRepository.checkUserByPhoneNumber(phoneNumber);
      
      if (!mounted || _isDisposed) return;

      setState(() {
        _isCheckingUser = false;
      });

      // Navigate based on profile status
      if (!profileStatus.exists || profileStatus.needsProfile) {
        // New user or missing profile details -> Profile Details Screen
        debugPrint('📝 Navigating to Profile Details Screen');
        context.go(AppConstants.routeUserDetails);
      } else if (profileStatus.needsInterests) {
        // Has profile but missing interests -> Interest Screen
        debugPrint('🎯 Navigating to Interest Screen');
        context.go(AppConstants.routeInterests);
      } else if (profileStatus.isComplete) {
        // Complete profile -> Feed (default tab)
        debugPrint('🏠 Navigating to Feed');
        context.go(AppConstants.routeDiscover);
      } else {
        // Fallback: go to profile details
        debugPrint('⚠️ Unknown status, navigating to Profile Details');
        context.go(AppConstants.routeUserDetails);
      }
    } catch (e) {
      debugPrint('❌ Error checking user status: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _isCheckingUser = false;
        });
        // On error, navigate to profile details as fallback
        context.go(AppConstants.routeUserDetails);
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
    final otpLength = _otpController.text.length;
    final canContinue = otpLength == 6 && !authState.isLoading && !_isCheckingUser;
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
      body: SafeArea(
        child: Column(
          children: [
            const KinsLogo(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Enter OTP',
                        style: textTheme.titleLarge?.copyWith(
                          fontSize: 17,
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
                      if (authState.isLoading || _isCheckingUser)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (_isDisposed || !mounted)
                                ? null
                                : canContinue
                                ? () {
                              if (mounted && !_isDisposed) {
                                try {
                                  final otp = _otpController.text;
                                  if (otp.length == 6) _verifyOTP(otp);
                                } catch (e) { /* controller disposed */ }
                              }
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canContinue ? Colors.black : Colors.grey.shade300,
                              foregroundColor: canContinue ? Colors.white : Colors.grey.shade600,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: Text(
                              'Continue',
                              style: textTheme.labelLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: canContinue ? Colors.white : Colors.grey.shade600,
                              ),
                            ),
                          ),
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
            )
          ],
        ),
      ),
    );
  }
}
