import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/repositories/feed_repository.dart';

/// Provider for feed repository (backend API, no Firebase)
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository();
});
