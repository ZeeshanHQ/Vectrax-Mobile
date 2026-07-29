import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';

class PrivacyOverlay extends StatelessWidget {
  final VoidCallback onUnlock;
  final bool isAuthenticating;

  const PrivacyOverlay({
    super.key,
    required this.onUnlock,
    this.isAuthenticating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Deep Blur Layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withOpacity(0.8),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 40,
                    color: AppTheme.accent,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.05, 1.05),
                    duration: 1.5.seconds),
                const SizedBox(height: 32),
                const Text(
                  'Supa-app is Locked',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Authentication is required to view your infrastructure.',
                  style: TextStyle(color: AppTheme.secondary, fontSize: 14),
                ),
                const SizedBox(height: 48),
                if (isAuthenticating)
                  const CircularProgressIndicator(color: AppTheme.accent)
                else
                  ElevatedButton.icon(
                    onPressed: onUnlock,
                    icon: const Icon(Icons.face_retouching_natural_rounded),
                    label: const Text('Unlock with Biometrics'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
        ],
      ),
    );
  }
}
