import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/widgets/main_navigation_screen.dart';

class SyncingScreen extends StatefulWidget {
  const SyncingScreen({super.key});

  @override
  State<SyncingScreen> createState() => _SyncingScreenState();
}

class _SyncingScreenState extends State<SyncingScreen> {
  final ApiService _apiService = ApiService();
  String _status = 'INITIALIZING SECURE CHANNEL';
  double _progress = 0.1;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    // Stage 1: Initializing
    await Future.delayed(800.ms);
    if (!mounted) return;
    setState(() {
      _status = 'ESTABLISHING HANDSHAKE...';
      _progress = 0.3;
    });

    // Stage 2: Fetching Data
    await Future.delayed(1.seconds);
    if (!mounted) return;
    setState(() {
      _status = 'SYNCING PROJECTS & ORGANIZATIONS...';
      _progress = 0.6;
    });

    try {
      // Trigger listProjects which now handles caching/merging
      await Future.wait([
        _apiService.listProjects(),
        _apiService.listOrganizations(),
      ]);
    } catch (e) {
      debugPrint('[SyncingScreen] Error during initial sync: $e');
    }

    // Stage 3: Finalizing
    if (!mounted) return;
    setState(() {
      _status = 'AUTHENTICATION VERIFIED';
      _progress = 1.0;
    });

    await Future.delayed(1.2.seconds);
    if (!mounted) return;
    setState(() => _isComplete = true);

    await Future.delayed(400.ms);
    if (!mounted) return;
    _navigateToDashboard();
  }

  void _navigateToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (context, animation, secondaryAnimation) => 
            const MainNavigationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with premium animation
            Stack(
              alignment: Alignment.center,
              children: [
                // Inner Glow
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accent.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                 .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 2.seconds),

                Image.asset(
                  'assets/images/app_logo.png',
                  width: 100,
                  height: 100,
                ).animate()
                 .fadeIn(duration: 800.ms)
                 .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack)
                 .shimmer(delay: 1.seconds, duration: 2.seconds, color: Colors.white24),
              ],
            ),
            
            const SizedBox(height: 48),

            // Status Text
            Text(
              _status,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ).animate(target: _isComplete ? 1 : 0)
             .fadeOut(duration: 400.ms),

            const SizedBox(height: 24),

            // Progress Bar
            Container(
              width: 200,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(1),
              ),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: 600.ms,
                    width: 200 * _progress,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate(target: _isComplete ? 1 : 0)
             .fadeOut(duration: 400.ms),

            const SizedBox(height: 40),
            
            // Completion Indicator
            if (_isComplete)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.accent,
                size: 32,
              ).animate()
               .scale(duration: 400.ms, curve: Curves.elasticOut)
               .fadeIn(),
          ],
        ),
      ),
    );
  }
}
