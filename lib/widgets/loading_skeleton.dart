import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_constants.dart';

/// Post card için skeleton loading
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (avatar + name + time)
            Row(
              children: [
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: baseColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        child: Container(
                          height: 16,
                          width: 120,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Shimmer.fromColors(
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        child: Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content lines
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                height: 14,
                width: 250,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                4,
                (index) => Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Container(
                    height: 24,
                    width: 60,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// User list item için skeleton
class UserListItemSkeleton extends StatelessWidget {
  const UserListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListTile(
        leading: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: baseColor,
          ),
        ),
        title: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            height: 16,
            width: 150,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 12,
              width: 100,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Test card için skeleton
class TestCardSkeleton extends StatelessWidget {
  const TestCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                height: 20,
                width: 200,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                height: 14,
                width: 180,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic skeleton list
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
