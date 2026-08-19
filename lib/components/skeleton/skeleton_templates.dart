import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

// ─────────────────────────────────────────────
// Chat List Skeleton (sidebar / mobile chat list)
// ─────────────────────────────────────────────

class ChatListSkeleton extends StatelessWidget {
  final int itemCount;
  const ChatListSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const SkeletonCircle(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLine(width: 100 + (index % 3) * 30, height: 13),
                      const SizedBox(height: 6),
                      SkeletonLine(
                        width: 160 + (index % 2) * 40,
                        height: 11,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const SkeletonLine(width: 36, height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Connections Grid Skeleton
// ─────────────────────────────────────────────

class ConnectionsGridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final double cardHeight;

  const ConnectionsGridSkeleton({
    super.key,
    this.crossAxisCount = 3,
    this.cardHeight = 130,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: cardHeight,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const SkeletonCircle(size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLine(width: 80 + (index % 3) * 20, height: 13),
                      const SizedBox(height: 6),
                      SkeletonLine(width: 120 + (index % 2) * 30, height: 10),
                      const SizedBox(height: 6),
                      SkeletonLine(width: 60 + (index % 3) * 15, height: 9),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Messages / Chat Thread Skeleton
// ─────────────────────────────────────────────

class MessagesSkeleton extends StatelessWidget {
  final int itemCount;
  const MessagesSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final isMe = index % 3 == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  const SkeletonCircle(size: 28),
                  const SizedBox(width: 8),
                ],
                SkeletonRect(
                  width: 140 + (index % 4) * 40,
                  height: 36 + (index % 3) * 12,
                  borderRadius: 16,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Settings / List Skeleton
// ─────────────────────────────────────────────

class SettingsListSkeleton extends StatelessWidget {
  final int sectionCount;
  const SettingsListSkeleton({super.key, this.sectionCount = 3});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: sectionCount,
        itemBuilder: (context, sectionIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(
                  width: 80 + (sectionIndex % 2) * 40,
                  height: 11,
                ),
                const SizedBox(height: 12),
                ...List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const SkeletonRect(
                          width: 32,
                          height: 32,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonLine(
                                width: 100 + (i % 3) * 30,
                                height: 13,
                              ),
                              const SizedBox(height: 4),
                              SkeletonLine(
                                width: 180 + (i % 2) * 40,
                                height: 10,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Feed / Post Skeleton
// ─────────────────────────────────────────────

class FeedSkeleton extends StatelessWidget {
  final int itemCount;
  const FeedSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SkeletonCircle(size: 36),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine(
                            width: 90 + (index % 3) * 20,
                            height: 13,
                          ),
                          const SizedBox(height: 4),
                          const SkeletonLine(width: 60, height: 10),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SkeletonLine(height: 12),
                  const SizedBox(height: 6),
                  const SkeletonLine(width: 240, height: 12),
                  const SizedBox(height: 12),
                  if (index % 2 == 0)
                    const SkeletonRect(height: 160, borderRadius: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Profile Skeleton
// ─────────────────────────────────────────────

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SkeletonCircle(size: 80),
            const SizedBox(height: 16),
            const SkeletonLine(width: 140, height: 18),
            const SizedBox(height: 8),
            const SkeletonLine(width: 200, height: 12),
            const SizedBox(height: 24),
            ...List.generate(4, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    const SkeletonRect(width: 28, height: 28, borderRadius: 6),
                    const SizedBox(width: 12),
                    SkeletonLine(width: 160 + (i % 3) * 30, height: 13),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Gmail / Email List Skeleton
// ─────────────────────────────────────────────

class GmailListSkeleton extends StatelessWidget {
  final int itemCount;
  const GmailListSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonCircle(size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonLine(
                            width: 100 + (index % 3) * 25,
                            height: 13,
                          ),
                          const Spacer(),
                          const SkeletonLine(width: 50, height: 10),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SkeletonLine(
                        width: 200 + (index % 2) * 40,
                        height: 12,
                      ),
                      const SizedBox(height: 4),
                      const SkeletonLine(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Simple centered loading (for inline/small areas)
// ─────────────────────────────────────────────

class InlineSkeleton extends StatelessWidget {
  const InlineSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonShimmer(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonRect(width: 48, height: 48, borderRadius: 12),
              SizedBox(height: 12),
              SkeletonLine(width: 100, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
