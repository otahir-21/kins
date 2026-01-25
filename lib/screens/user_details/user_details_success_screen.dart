import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'dart:math' as math;

class UserDetailsSuccessScreen extends ConsumerWidget {
  const UserDetailsSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDetailsState = ref.watch(userDetailsProvider);

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
                  // KINS Logo placeholder - will be replaced with image later
                  Container(
                    width: 100,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4C93), // Dark purple/plum
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
                  // Skip button (optional, can be removed)
                  TextButton(
                    onPressed: () {
                      // Handle skip if needed
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

            // Main content card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Large rounded card
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F0E8), // Beige/off-white
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Stack(
                          children: [
                            // Decorative pill shapes in background (behind text)
                            ..._buildDecorativePills(),
                            
                            // Content on top
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32.0, 40.0, 32.0, 32.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title - using Text with proper styling
                                  const Text(
                                    'Document Uploaded\nand Data Saved',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      height: 1.3,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.visible,
                                    textAlign: TextAlign.left,
                                  ),
                                  const SizedBox(height: 24),

                                  // Success message
                                  Text(
                                    'Your information has been successfully saved to Firebase',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade700,
                                      height: 1.5,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.visible,
                                    textAlign: TextAlign.left,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  // Selected items row
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Selected interest tags with Lorem Ipsum text
                            ..._buildSelectedTags(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Arrow button with gradient
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFB6C1), // Light pink
                          Color(0xFFFF69B4), // Rose pink
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF69B4).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          // Navigate to Home screen
                          context.go(AppConstants.routeHome);
                        },
                        child: const Center(
                          child: Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build decorative pill shapes
  List<Widget> _buildDecorativePills() {
    final pills = <Widget>[];

    // Create decorative pills with specific positions to match design
    // Positioned to not overlap with text content
    final pillData = [
      {'size': 120.0, 'left': 40.0, 'top': 120.0, 'rotation': 15.0, 'gradient': false},
      {'size': 100.0, 'left': 200.0, 'top': 100.0, 'rotation': -20.0, 'gradient': true},
      {'size': 90.0, 'left': 280.0, 'top': 140.0, 'rotation': 30.0, 'gradient': false},
      {'size': 110.0, 'left': 50.0, 'top': 240.0, 'rotation': -15.0, 'gradient': true},
      {'size': 95.0, 'left': 200.0, 'top': 260.0, 'rotation': 25.0, 'gradient': false},
      {'size': 105.0, 'left': 300.0, 'top': 220.0, 'rotation': -30.0, 'gradient': true},
      {'size': 85.0, 'left': 120.0, 'top': 360.0, 'rotation': 20.0, 'gradient': false},
      {'size': 115.0, 'left': 250.0, 'top': 340.0, 'rotation': -25.0, 'gradient': true},
      {'size': 100.0, 'left': 30.0, 'top': 420.0, 'rotation': 10.0, 'gradient': false},
      {'size': 90.0, 'left': 180.0, 'top': 440.0, 'rotation': -18.0, 'gradient': true},
      {'size': 105.0, 'left': 320.0, 'top': 460.0, 'rotation': 22.0, 'gradient': false},
    ];

    for (final data in pillData) {
      final size = data['size'] as double;
      final left = data['left'] as double;
      final top = data['top'] as double;
      final rotation = data['rotation'] as double;
      final isGradient = data['gradient'] as bool;
      
      pills.add(
        Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.8,
              child: Transform.rotate(
                angle: rotation * math.pi / 180,
                child: Container(
                  width: size,
                  height: size * 0.4,
                  decoration: BoxDecoration(
                    color: isGradient ? null : Colors.white,
                    gradient: isGradient
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFFFB6C1), // Light pink
                              Color(0xFFFF69B4), // Rose pink
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(size * 0.2),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return pills;
  }

  // Build selected interest tags
  List<Widget> _buildSelectedTags() {
    final tags = [
      {'color': const Color(0xFF8B4513), 'text': 'Lorem'}, // Reddish-brown
      {'color': const Color(0xFFE6E6FA), 'text': 'Lorem'}, // Light lavender
      {'color': const Color(0xFFFFE4B5), 'text': 'Lorem'}, // Light peach
      {'color': const Color(0xFF6B4C93), 'text': 'Lorem'}, // Dark purple
      {'color': const Color(0xFFFF6347), 'text': '+1'}, // Red-orange with +1
    ];

    return tags.map((tag) {
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: tag['color'] as Color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              tag['text'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
