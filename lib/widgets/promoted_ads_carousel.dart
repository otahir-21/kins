import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';
import 'package:kins_app/models/promoted_ad_model.dart';
import 'package:kins_app/repositories/ads_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// Promoted ads banner under the map: fetches GET /ads/active, shows sliding images every 10s, tap opens link.
class PromotedAdsCarousel extends StatefulWidget {
  const PromotedAdsCarousel({super.key});

  @override
  State<PromotedAdsCarousel> createState() => _PromotedAdsCarouselState();
}

class _PromotedAdsCarouselState extends State<PromotedAdsCarousel> {
  List<PromotedAdModel> _ads = [];
  bool _loading = true;
  int _currentPage = 0;
  late PageController _pageController;
  Timer? _timer;
  static const Duration _autoSlideDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadAds();
  }

  Future<void> _loadAds() async {
    final ads = await AdsRepository.getActiveAds();
    if (mounted) {
      setState(() {
        _ads = ads;
        _loading = false;
      });
      if (_ads.length > 1) _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoSlideDuration, (_) {
      if (!mounted || _ads.isEmpty) return;
      final next = (_pageController.page?.round() ?? 0) + 1;
      final index = next >= _ads.length ? 0 : next;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('⚠️ Could not launch ad link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade100,
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C1D54)),
        ),
      );
    }
    if (_ads.isEmpty) return const SizedBox.shrink();

    const double imageHeight = 172;
    const double indicatorStripHeight = 28;

    return Container(
      height: imageHeight + indicatorStripHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image banner only (no dots on top)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: imageHeight,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      if (mounted) setState(() => _currentPage = index);
                    },
                    itemCount: _ads.length,
                    itemBuilder: (context, index) {
                      final ad = _ads[index];
                      return GestureDetector(
                        onTap: () {
                          if (ad.link.isNotEmpty) _openLink(ad.link);
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              ad.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image_outlined, size: 48),
                              ),
                            ),
                            if (ad.title != null && ad.title!.isNotEmpty)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.all(Responsive.spacing(context, 12)),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                                    ),
                                  ),
                                  child: Text(
                                    ad.title!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Responsive.fontSize(context, 14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Promoted Ad label on image
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.spacing(context, 8),
                        vertical: Responsive.spacing(context, 4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Promoted Ad',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.fontSize(context, 10),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Container after image: white strip with page dots
          Container(
            height: indicatorStripHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            alignment: Alignment.center,
            child: _ads.length > 1
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _ads.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPage
                              ? const Color(0xFF7C1D54)
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
