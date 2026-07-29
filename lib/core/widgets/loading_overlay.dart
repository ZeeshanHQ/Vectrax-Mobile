import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';

class LoadingOverlay extends StatelessWidget {
  final String message;
  const LoadingOverlay({super.key, this.message = 'SYNCHRONIZING...'});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo with pulse & shimmer
            Image.asset(
              'assets/images/app_logo.png',
              width: 80,
              height: 80,
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1.5.seconds, color: AppTheme.accent.withOpacity(0.3))
                .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.05, 1.05),
                    duration: 1.seconds,
                    curve: Curves.easeInOut),
            const SizedBox(height: 32),
            // App Name with high tracking
            Text(
              'VECTRAX',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 6.0,
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 12),
            // Loading message
            Text(
              message,
              style: TextStyle(
                color: AppTheme.accent.withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
          ],
        ),
      ),
    );
  }
}
