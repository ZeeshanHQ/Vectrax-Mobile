import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';

class SuccessCheck extends StatelessWidget {
  final String label;

  const SuccessCheck({
    super.key,
    this.label = 'SUCCESS',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.1),
            shape: BoxShape.circle,
            border:
                Border.all(color: AppTheme.accent.withOpacity(0.5), width: 2),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppTheme.accent,
            size: 48,
          ),
        )
            .animate()
            .scale(
              duration: 600.ms,
              curve: Curves.elasticOut,
              begin: const Offset(0, 0),
            )
            .shimmer(
                delay: 400.ms,
                duration: 1.seconds,
                color: Colors.white.withOpacity(0.5)),
        const SizedBox(height: 24),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.0,
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
      ],
    );
  }
}
