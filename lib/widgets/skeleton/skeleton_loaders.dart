import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// App-wide skeleton loaders. Use instead of CircularProgressIndicator.
/// Replace all loading states with these skeleton UIs.

/// Skeleton for feed/post list (Discover screen initial load)
class SkeletonFeedList extends StatelessWidget {
  final int itemCount;

  const SkeletonFeedList({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        itemCount: itemCount,
        itemBuilder: (_, __) => _SkeletonPostCard(),
      ),
    );
  }
}

class _SkeletonPostCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade300),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 18,
                      width: 140,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 14,
                      width: 80,
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 16,
            width: double.infinity,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Container(
            height: 16,
            width: 200,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.favorite_border, size: 22, color: Colors.grey.shade400),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline, size: 22, color: Colors.grey.shade400),
              const SizedBox(width: 16),
              Icon(Icons.repeat, size: 22, color: Colors.grey.shade400),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for loading more posts at bottom of feed
class SkeletonFeedItem extends StatelessWidget {
  const SkeletonFeedItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: _SkeletonPostCard(),
    );
  }
}

/// Skeleton for profile screen
class SkeletonProfile extends StatelessWidget {
  const SkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 44, backgroundColor: Colors.grey.shade300),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 22,
                        width: 150,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 16,
                        width: 200,
                        color: Colors.grey.shade200,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _skeletonStat(),
                _skeletonStat(),
                _skeletonStat(),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                5,
                (_) => Container(
                  height: 32,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 20,
              width: 100,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            ...List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _SkeletonPostCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonStat() {
    return Column(
      children: [
        Container(
          height: 20,
          width: 40,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 4),
        Container(
          height: 14,
          width: 60,
          color: Colors.grey.shade200,
        ),
      ],
    );
  }
}

/// Skeleton for comments list
class SkeletonCommentList extends StatelessWidget {
  final int itemCount;

  const SkeletonCommentList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 20, backgroundColor: Colors.grey.shade300),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 120,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 14,
                      width: 180,
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for interest/topic chips (Create Post screen)
class SkeletonInterestChips extends StatelessWidget {
  const SkeletonInterestChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
          8,
          (_) => Container(
            height: 36,
            width: 90,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for notifications list
class SkeletonNotificationList extends StatelessWidget {
  final int itemCount;

  const SkeletonNotificationList({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade300),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 180,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for chat list
class SkeletonChatList extends StatelessWidget {
  final int itemCount;

  const SkeletonChatList({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade300),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 140,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 200,
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for followers/following list
class SkeletonFollowList extends StatelessWidget {
  final int itemCount;

  const SkeletonFollowList({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (_, __) => ListTile(
          leading: CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade300),
          title: Container(
            height: 16,
            width: 120,
            color: Colors.grey.shade300,
          ),
          subtitle: Container(
            height: 12,
            width: 80,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.only(top: 8),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for account settings / simple form screen
class SkeletonSettings extends StatelessWidget {
  const SkeletonSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 100,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 48,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small inline skeleton for buttons (e.g. send, load more)
class SkeletonInline extends StatelessWidget {
  final double size;

  const SkeletonInline({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Skeleton for horizontal filter chips (interests)
class SkeletonFilterChips extends StatelessWidget {
  const SkeletonFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        height: 40,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              6,
              (_) => Container(
                height: 32,
                width: 70,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for poll options loading (options only)
class SkeletonPollContent extends StatelessWidget {
  const SkeletonPollContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(3, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 44,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        )),
      ),
    );
  }
}

/// Skeleton for post card placeholder (e.g. when checking like status)
class SkeletonPostCardPlaceholder extends StatelessWidget {
  const SkeletonPostCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade300),
                const SizedBox(width: 12),
                Container(height: 16, width: 120, color: Colors.grey.shade300),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Container(height: 14, width: 180, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for home screen (map + cards)
class SkeletonHome extends StatelessWidget {
  const SkeletonHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 24),
            ...List.generate(6, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 16, width: 150, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Container(height: 12, width: 100, color: Colors.grey.shade200),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for nearby kins / map list
class SkeletonMapList extends StatelessWidget {
  const SkeletonMapList({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.all(24),
              color: Colors.grey.shade200,
            ),
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade300),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 16,
                            width: 120,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: 80,
                            color: Colors.grey.shade200,
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
    );
  }
}
