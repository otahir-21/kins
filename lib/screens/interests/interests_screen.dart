import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/interest_provider.dart';
import 'dart:math' as math;

import '../../models/interest_model.dart';

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  // Predefined colors for selected interest chips
  final List<Color> _chipColors = [
    const Color(0xFF6B4C93), // Dark purple
    const Color(0xFFFFB6C1), // Light pink
    const Color(0xFFFFE4B5), // Light peach
    const Color(0xFF8B4513), // Brown
    const Color(0xFFE6E6FA), // Lavender
    const Color(0xFFFF6347), // Red-orange
  ];
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load interests on screen init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(interestProvider.notifier).loadInterests();
    });
  }

  Future<void> _handleContinue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final interestState = ref.read(interestProvider);
    if (interestState.selectedInterestIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one interest'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Prevent multiple taps
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Save selected interest IDs to user profile
      await ref.read(interestProvider.notifier).saveUserInterests(user.uid);
      
      if (mounted) {
        // Navigate to home screen after successful save
        context.go(AppConstants.routeHome);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save interests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final interestState = ref.watch(interestProvider);
    final selectedInterests = interestState.selectedInterests;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top section with logo and skip
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // KINS Logo
                  Container(
                    width: 100,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4C93),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'kins',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Skip button
                  TextButton(
                    onPressed: () {
                      // Navigate to home if skip
                      context.go(AppConstants.routeHome);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Title
                    const Text(
                      'Select your interest',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Interests grid
                    if (interestState.isLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6B4C93),
                          ),
                        ),
                      )
                    else if (interestState.error != null)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                interestState.error!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  ref.read(interestProvider.notifier).loadInterests();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: _buildInterestsGrid(interestState),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom action bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
              child: Row(
                children: [
                  // Selected interests indicator (overlapping circles)
                  Expanded(
                    child: _buildSelectedInterestsIndicator(selectedInterests),
                  ),
                  const SizedBox(width: 16),

                  // Continue button
                  _buildContinueButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsGrid(InterestState state) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: state.interests.length,
      itemBuilder: (context, index) {
        final interest = state.interests[index];
        final isSelected = state.selectedInterestIds.contains(interest.id);

        return _buildInterestChip(interest, isSelected);
      },
    );
  }

  Widget _buildInterestChip(InterestModel interest, bool isSelected) {
    return InkWell(
      onTap: () {
        ref.read(interestProvider.notifier).toggleInterest(interest.id);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6B4C93)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                interest.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              isSelected ? Icons.close : Icons.add,
              size: 18,
              color: isSelected
                  ? const Color(0xFF6B4C93)
                  : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedInterestsIndicator(List<InterestModel> selectedInterests) {
    if (selectedInterests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200.withOpacity(0.6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          'No interests selected',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    // Show first 5 interests, then +N for remaining
    final visibleCount = math.min(selectedInterests.length, 5);
    final remainingCount = selectedInterests.length - visibleCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Visible interest chips (overlapping)
          SizedBox(
            width: (visibleCount * 30.0) + 20.0, // Width for overlapping circles
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(visibleCount, (index) {
                final interest = selectedInterests[index];
                final color = _chipColors[index % _chipColors.length];
                
                return Positioned(
                  left: index * 30.0, // Overlap by 30px
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getInterestInitials(interest.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // +N indicator if more than 5
          if (remainingCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6347), // Red-orange
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '+$remainingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getInterestInitials(String name) {
    if (name.length <= 4) {
      return name.toUpperCase();
    }
    // Get first 3-4 characters
    return name.substring(0, math.min(4, name.length)).toUpperCase();
  }

  Widget _buildContinueButton() {
    final interestState = ref.watch(interestProvider);
    final hasSelection = interestState.selectedInterestIds.isNotEmpty;
    final isEnabled = hasSelection && !_isSaving;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEnabled
              ? [
                  const Color(0xFFFFE4B5), // Light peach
                  const Color(0xFFFFB6C1), // Light pink
                ]
              : [
                  Colors.grey.shade300,
                  Colors.grey.shade400,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFFFFB6C1).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: isEnabled ? _handleContinue : null,
          child: Center(
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    Icons.arrow_forward,
                    color: isEnabled ? Colors.white : Colors.grey.shade600,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}
