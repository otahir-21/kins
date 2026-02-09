import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/auth_provider.dart';
import 'package:kins_app/repositories/user_details_repository.dart';
import 'package:kins_app/models/user_profile_status.dart';

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
        // Complete profile -> Home Screen
        debugPrint('🏠 Navigating to Home Screen');
        context.go(AppConstants.routeHome);
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Verify OTP',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to\n${widget.phoneNumber}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (mounted && !_isDisposed)
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _otpController,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(8),
                    fieldHeight: 60,
                    fieldWidth: 50,
                    activeFillColor: Colors.white,
                    inactiveFillColor: Colors.white,
                    selectedFillColor: Colors.white,
                    activeColor: Colors.black,
                    inactiveColor: Colors.grey.shade300,
                    selectedColor: Colors.black,
                  ),
                  enableActiveFill: true,
                  keyboardType: TextInputType.number,
                  onCompleted: _isDisposed ? null : _verifyOTP,
                  onChanged: (value) {},
                )
              else
                const SizedBox(height: 60),
              const SizedBox(height: 32),
              if (authState.isLoading || _isCheckingUser)
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.black,
                  ),
                )
              else
                ElevatedButton(
                  onPressed: (_isDisposed || !mounted) 
                      ? null 
                      : () {
                          if (mounted && !_isDisposed) {
                            try {
                              final otp = _otpController.text;
                              if (otp.length == 6) {
                                _verifyOTP(otp);
                              }
                            } catch (e) {
                              // Controller might be disposed, ignore
                            }
                          }
                        },
                  child: const Text('Verify OTP'),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: (authState.isLoading || _resendCooldownSeconds > 0)
                    ? null
                    : _resendOTP,
                child: Text(
                  _resendCooldownSeconds > 0
                      ? 'Resend in ${_resendCooldownSeconds}s'
                      : 'Resend OTP',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
