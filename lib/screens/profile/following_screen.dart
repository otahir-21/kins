import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/providers/follow_provider.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

/// Following list from backend API. Unfollow per user.
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = currentUserId;
    final async = ref.watch(followingListProvider(uid));
    final followRepo = ref.read(followRepositoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text('Following', style: TextStyle(color: Colors.black)),
      ),
      body: async.when(
        data: (res) {
          final following = res.items;
          if (following.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_alt_1_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Not following anyone yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(followingListProvider(uid)),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: following.length,
              itemBuilder: (context, index) {
                final f = following[index];
                final name = f.name?.trim().isNotEmpty == true ? f.name! : (f.username ?? 'Unknown');
                return ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF6B4C93).withOpacity(0.2),
                    backgroundImage: f.profilePictureUrl != null ? NetworkImage(f.profilePictureUrl!) : null,
                    child: f.profilePictureUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Color(0xFF6B4C93), fontWeight: FontWeight.w600),
                          )
                        : null,
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: f.username != null && f.username!.isNotEmpty ? Text('@${f.username}') : null,
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await followRepo.unfollow(f.id);
                        if (context.mounted) ref.invalidate(followingListProvider(uid));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unfollowed')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      }
                    },
                    child: Text('Unfollow', style: TextStyle(color: Colors.red.shade700)),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const SkeletonFollowList(),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(followingListProvider(uid)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
