import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/repositories/post_repository.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  final bunnyCDN = ref.watch(bunnyCDNServiceProvider);
  return PostRepository(bunnyCDN: bunnyCDN);
});
