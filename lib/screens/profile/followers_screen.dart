import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/providers/follow_provider.dart';

/// Followers list: real data from Firestore. Remove = remove that follower.
class FollowersScreen extends ConsumerWidget {
  const FollowersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = currentUserId;
    final followersAsync = ref.watch(followersListStreamProvider(uid));
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
      body: followersAsync.when(
        data: (followers) {
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
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final f = followers[index];
              final name = f.name?.trim().isNotEmpty == true ? f.name! : 'Unknown';
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
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await followRepo.removeFollower(currentUid: uid, followerUid: f.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      }
                    }
                  },
                  child: Text('Remove', style: TextStyle(color: Colors.red.shade700)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
