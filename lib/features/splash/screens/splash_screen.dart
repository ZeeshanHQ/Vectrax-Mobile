import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/features/splash/screens/onboarding_screen.dart';
import 'package:supa_app/features/auth/screens/connect_screen.dart';
import 'package:supa_app/core/widgets/main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    final authService = AuthService();

    // Check if user is logged into the app itself (email OTP / social login)
    final hasVectraxToken = await authService.getAccessToken() != null;
    final hasSupaToken = await authService.isSupabaseConnected();
    final appUser = authService.currentUser;

    // Fast, responsive startup delay (800ms)
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    Widget destination;
    if (hasVectraxToken && hasSupaToken) {
      // User is fully connected: go straight to the main Dashboard screen for instant startup!
      destination = const MainNavigationScreen();
    } else if (hasVectraxToken || appUser != null) {
      // User is logged into the app but hasn't connected Supabase yet
      destination = ConnectScreen(userEmail: appUser?.email);
    } else {
      // User is not logged in at all
      destination = const OnboardingScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/app_logo.png',
              width: 80,
              height: 80,
            )
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    curve: Curves.elasticOut)
                .shimmer(
                    delay: 1.2.seconds,
                    duration: 1.8.seconds,
                    color: AppTheme.accent.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text(
              'VECTRAX',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 4.0,
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }
}
