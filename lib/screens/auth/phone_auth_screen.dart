import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/core/utils/storage_service.dart';
import 'package:kins_app/providers/auth_provider.dart';

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
  bool _isRecaptchaInProgress = false;

  @override
  void initState() {
    super.initState();
    // Check for verification ID when screen becomes visible (after reCAPTCHA)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForVerificationId();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _checkForVerificationId() {
    // Check storage directly for verification ID
    final verificationId = StorageService.getString('verification_id');
    if (verificationId != null && 
        verificationId.isNotEmpty && 
        _completePhoneNumber.isNotEmpty &&
        !_isNavigating) {
      _isNavigating = true;
      // Wait to ensure reCAPTCHA is fully done
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _isNavigating) {
          // Double-check verification ID is still there
          final currentVerificationId = StorageService.getString('verification_id');
          if (currentVerificationId != null && currentVerificationId.isNotEmpty) {
            context.go(
              '${AppConstants.routeOtpVerification}?phone=${Uri.encodeComponent(_completePhoneNumber)}',
            );
          } else {
            _isNavigating = false;
          }
        }
      });
    }
  }


  Future<void> _sendOTP() async {
    if (_formKey.currentState!.validate()) {
      if (_completePhoneNumber.isEmpty) {
        debugPrint('❌ Validation Error: Phone number is empty');
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid phone number'),
              backgroundColor: Colors.black,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          debugPrint('❌ SnackBar Error: $e');
        }
        return;
      }

      _isNavigating = false;
      _isRecaptchaInProgress = true;
      
      // Start OTP sending - reCAPTCHA will appear on THIS screen
      await ref.read(authProvider.notifier).sendOTP(_completePhoneNumber);

      if (mounted) {
        final authState = ref.read(authProvider);
        if (authState.error != null) {
          _isRecaptchaInProgress = false;
          // Log error to console
          debugPrint('❌ Auth Error: ${authState.error}');
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
          // DO NOT navigate immediately - wait for reCAPTCHA to complete
          // Navigation will be handled by listener or polling after reCAPTCHA completes
          _pollForVerificationId();
        }
      }
    }
  }

  void _pollForVerificationId() async {
    // Poll for verification ID for up to 15 seconds (reCAPTCHA might take time)
    // Check both state and storage
    for (int i = 0; i < 75 && !_isNavigating && mounted && _isRecaptchaInProgress; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (mounted && !_isNavigating && _isRecaptchaInProgress) {
        // Check storage directly (more reliable)
        final verificationId = StorageService.getString('verification_id');
        if (verificationId != null && verificationId.isNotEmpty) {
          // Mark reCAPTCHA as done
          _isRecaptchaInProgress = false;
          // Wait a bit more to ensure reCAPTCHA is fully done
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted && !_isNavigating) {
            _isNavigating = true;
            context.go(
              '${AppConstants.routeOtpVerification}?phone=${Uri.encodeComponent(_completePhoneNumber)}',
            );
          }
          break;
        }
        
        // Also check state
        final authState = ref.read(authProvider);
        if (authState.verificationId != null && 
            authState.verificationId!.isNotEmpty) {
          // Mark reCAPTCHA as done
          _isRecaptchaInProgress = false;
          // Wait a bit more to ensure reCAPTCHA is fully done
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted && !_isNavigating) {
            _isNavigating = true;
            context.go(
              '${AppConstants.routeOtpVerification}?phone=${Uri.encodeComponent(_completePhoneNumber)}',
            );
          }
          break;
        }
      } else {
        break;
      }
    }
    // If polling ended without finding verification ID, mark reCAPTCHA as done
    if (_isRecaptchaInProgress) {
      _isRecaptchaInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    
    // Listen to auth state changes - must be in build method
    ref.listen<AuthState>(authProvider, (previous, next) {
      // Navigate when verification ID is received and we're not already navigating
      // Only navigate if reCAPTCHA is done
      if (!_isNavigating && 
          !_isRecaptchaInProgress &&
          previous?.verificationId != next.verificationId &&
          next.verificationId != null && 
          next.verificationId!.isNotEmpty &&
          !next.isLoading &&
          next.error == null &&
          _completePhoneNumber.isNotEmpty) {
        _isNavigating = true;
        // Wait longer to ensure reCAPTCHA is fully done before navigating
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && _isNavigating && !_isRecaptchaInProgress) {
            // Double-check verification ID is still there
            final verificationId = StorageService.getString('verification_id');
            if (verificationId != null && verificationId.isNotEmpty) {
              context.go(
                '${AppConstants.routeOtpVerification}?phone=${Uri.encodeComponent(_completePhoneNumber)}',
              );
            } else {
              _isNavigating = false;
            }
          }
        });
      }
    });
    
    // Also check storage when widget rebuilds (after reCAPTCHA returns)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isNavigating && _completePhoneNumber.isNotEmpty) {
        _checkForVerificationId();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Enter Phone Number',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                const Text(
                  'Welcome to KINS',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your phone number to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                IntlPhoneField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  initialCountryCode: 'US',
                  onChanged: (phone) {
                    _completePhoneNumber = phone.completeNumber;
                  },
                  validator: (phone) {
                    if (phone == null || phone.number.isEmpty) {
                      return 'Please enter a phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _sendOTP,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Send OTP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
