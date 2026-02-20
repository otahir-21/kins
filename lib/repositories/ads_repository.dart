import 'package:flutter/foundation.dart';
import 'package:kins_app/core/network/backend_api_client.dart';
import 'package:kins_app/models/promoted_ad_model.dart';

/// Active promoted ads from GET /api/v1/ads/active (no auth).
class AdsRepository {
  /// Fetches active ads. No Authorization header.
  static Future<List<PromotedAdModel>> getActiveAds() async {
    try {
      final raw = await BackendApiClient.get('/ads/active', useAuth: false);
      final list = raw['ads'];
      if (list is! List || list.isEmpty) return [];
      final ads = <PromotedAdModel>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            ads.add(PromotedAdModel.fromJson(item));
          } catch (e) {
            debugPrint('⚠️ Skip invalid ad item: $e');
          }
        }
      }
      ads.sort((a, b) => a.order.compareTo(b.order));
      return ads;
    } catch (e) {
      debugPrint('❌ Failed to fetch active ads: $e');
      return [];
    }
  }
}
