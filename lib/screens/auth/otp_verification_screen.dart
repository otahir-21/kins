import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/auth_provider.dart';

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

  @override
  void dispose() {
    _isDisposed = true;
    // Safely dispose controller
    try {
      _otpController.dispose();
    } catch (e) {
      // Controller might already be disposed, ignore
    }
    super.dispose();
  }

  Future<void> _verifyOTP(String otp) async {
    if (otp.length == 6 && !_isDisposed) {
      await ref.read(authProvider.notifier).verifyOTP(otp);

      if (mounted && !_isDisposed) {
        final authState = ref.read(authProvider);
        if (authState.error != null) {
          // Log error to console
          debugPrint('❌ OTP Verification Error: ${authState.error}');
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
        } else if (authState.user != null) {
          debugPrint('✅ OTP Verified Successfully');
          context.go(AppConstants.routeOtpVerified);
        }
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
              if (authState.isLoading)
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
                onPressed: authState.isLoading ? null : _resendOTP,
                child: const Text('Resend OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
