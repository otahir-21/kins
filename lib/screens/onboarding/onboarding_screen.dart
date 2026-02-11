import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/onboarding_provider.dart';

/// Onboarding image paths (add img-2.png, img-3.png to assets/onboardingIcons/ for pages 2 & 3)
const String _onboardingImg1 = 'assets/onboardingIcons/img-1.png';
const String _onboardingImg2 = 'assets/onboardingIcons/img-2.png';
const String _onboardingImg3 = 'assets/onboardingIcons/img-3.png';

/// Onboarding colors matching the design
class _OnboardingColors {
  static const Color activeDot = Color(0xFF5A1D6B); // dark purple
  static const Color inactiveDotBorder = Color(0xFFE0E0E0);
  static const Color imageContainerBackground = Colors.white;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const double _swipeToAuthThreshold = 50;

  static const List<OnboardingPageData> _pages = [
    OnboardingPageData(
      imagePath: _onboardingImg1,
      title: 'Lorem Ipsum',
      subtitle: 'Expert & Share Stories',
      description:
          'Lorem Ipsum is simply dummy text of the printing and typesetting industry.',
    ),
    OnboardingPageData(
      imagePath: _onboardingImg2,
      title: 'Easy to Use',
      subtitle: 'Simple and intuitive',
      description:
          'Designed for everyone. Find what you need and connect with your community.',
    ),
    OnboardingPageData(
      imagePath: _onboardingImg3,
      title: 'Get Started',
      subtitle: 'Join KINS today',
      description:
          'Join thousands of users already using KINS. Your journey starts here.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_currentPage != _pages.length - 1) return false;
    final m = notification.metrics;
    final overscroll = m.pixels - m.maxScrollExtent;
    if (overscroll > _swipeToAuthThreshold) {
      _completeOnboarding();
      return true;
    }
    return false;
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _skipOnboarding() {
    ref.read(onboardingProvider.notifier).completeOnboarding();
    if (mounted) context.go(AppConstants.routePhoneAuth);
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (mounted) context.go(AppConstants.routePhoneAuth);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Full-screen PageView: each page = one container (image + Skip) + text below.
            // On page 3, swiping left (overscroll) goes to auth.
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
                  itemBuilder: (context, index) {
                    return _OnboardingPageContent(
                      data: _pages[index],
                      textTheme: textTheme,
                      onSkip: _skipOnboarding,
                    );
                  },
                ),
              ),
            ),

            // On page 3: show "Get Started" so user can go to auth (swipe or tap)
            if (_currentPage == _pages.length - 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    '',
                    style: textTheme.titleMedium?.copyWith(
                      color: _OnboardingColors.activeDot,
                      decoration: TextDecoration.underline,
                      decorationColor: _OnboardingColors.activeDot,
                    ),
                  ),
                ),
              ),

            // Pagination indicators - active: bigger circle, white background, image in center; inactive: smaller
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) {
                    final isActive = _currentPage == index;
                    final size = isActive ? 56.0 : 40.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _OnboardingColors.inactiveDotBorder,
                            width: 1.5,
                          ),
                        ),
                        child: isActive
                            ? Center(
                                child: Image.asset(
                                  'assets/logo/kinsK_Transparent.png',
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 32,
                                    height: 32,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final String imagePath;
  final String title;
  final String subtitle;
  final String description;

  const OnboardingPageData({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}

class _OnboardingPageContent extends StatelessWidget {
  final OnboardingPageData data;
  final TextTheme textTheme;
  final VoidCallback onSkip;

  const _OnboardingPageContent({
    required this.data,
    required this.textTheme,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // One container: image + Skip (text is outside, below)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            child: Container(
              margin: EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Center(
                    child: SizedBox(
                      height: (550.0).clamp(0.0, MediaQuery.sizeOf(context).height * 0.55),
                      width: double.infinity,
                      child: Image.asset(
                        data.imagePath,
                        errorBuilder: (_, __, ___) => Image.asset(
                          _onboardingImg1,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 20),
                    child: TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Skip',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Text content (outside the image container)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
              data.title,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w300,
                color: Colors.black,
              ) ?? const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Subtitle - prominent, black, centered
            Text(
              data.subtitle,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w200,
                color: Colors.black,
              ) ?? const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Description - smaller, dark grey, centered
            Text(
              data.description,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                height: 1.4,
              ) ?? const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
