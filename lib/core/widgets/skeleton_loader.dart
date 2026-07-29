import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(
          duration: 1.2.seconds,
          color: Colors.white.withOpacity(0.05),
        );
  }
}

class SkeletonProjectCard extends StatelessWidget {
  const SkeletonProjectCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonLoader(
                  width: 12,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(6))),
              const SizedBox(width: 12),
              const SkeletonLoader(width: 120, height: 16),
              const Spacer(),
              const SkeletonLoader(width: 60, height: 12),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonLoader(width: 80, height: 30),
              SkeletonLoader(width: 80, height: 30),
              SkeletonLoader(width: 80, height: 30),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonBentoCard extends StatelessWidget {
  final bool isLarge;
  const SkeletonBentoCard({super.key, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(width: 20, height: 20),
          const Spacer(),
          const SkeletonLoader(width: 40, height: 8),
          const SizedBox(height: 8),
          SkeletonLoader(width: isLarge ? 80 : 60, height: isLarge ? 28 : 20),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 50, height: 10),
        ],
      ),
    );
  }
}
