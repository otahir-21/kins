import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:kins_app/providers/follow_provider.dart';

/// Following list: real data from Firestore. Unfollow = unfollow that user.
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = currentUserId;
    final followingAsync = ref.watch(followingListStreamProvider(uid));
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
      body: followingAsync.when(
        data: (following) {
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
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: following.length,
            itemBuilder: (context, index) {
              final f = following[index];
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
                      await followRepo.unfollow(currentUid: uid, targetUid: f.uid);
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
