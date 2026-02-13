import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/providers/follow_provider.dart';
import 'package:kins_app/widgets/skeleton/skeleton_loaders.dart';

/// Followers list from backend API. Follow/Unfollow per user.
class FollowersScreen extends ConsumerWidget {
  const FollowersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = currentUserId;
    final async = ref.watch(followersListProvider(uid));
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
        title: const Text('Followers', style: TextStyle(color: Colors.black)),
      ),
      body: async.when(
        data: (res) {
          final followers = res.items;
          if (followers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No followers yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(followersListProvider(uid)),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: followers.length,
              itemBuilder: (context, index) {
                final f = followers[index];
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
                  trailing: _FollowButton(
                    userId: f.id,
                    isFollowed: f.isFollowedByMe,
                    onFollow: () async {
                      try {
                        await followRepo.follow(f.id);
                        if (context.mounted) ref.invalidate(followersListProvider(uid));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      }
                    },
                    onUnfollow: () async {
                      try {
                        await followRepo.unfollow(f.id);
                        if (context.mounted) ref.invalidate(followersListProvider(uid));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      }
                    },
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
                onPressed: () => ref.invalidate(followersListProvider(uid)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final String userId;
  final bool isFollowed;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;

  const _FollowButton({
    required this.userId,
    required this.isFollowed,
    required this.onFollow,
    required this.onUnfollow,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isFollowed ? onUnfollow : onFollow,
      child: Text(
        isFollowed ? 'Unfollow' : 'Follow',
        style: TextStyle(
          color: isFollowed ? Colors.red.shade700 : const Color(0xFF6B4C93),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
