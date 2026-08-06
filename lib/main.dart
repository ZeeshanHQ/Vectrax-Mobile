import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/features/splash/screens/splash_screen.dart';
import 'package:supa_app/core/services/notification_service.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/core/services/premium_service.dart';
import 'package:supa_app/core/widgets/main_navigation_screen.dart';
import 'package:supa_app/core/widgets/biometric_lock_wrapper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService().init();
    await PremiumService().init();
  } catch (e) {
    debugPrint('[Notifications/Premium] Non-fatal init error: $e');
  }

  await Supabase.initialize(
    url: 'https://crlrgszzibpkqfixlmbw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNybHJnc3p6aWJwa3FmaXhsbWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3MDYzMTYsImV4cCI6MjEwMDI4MjMxNn0.bvvinUdrMQ8ecQrEi6eLlaTYzNQhKDLRehS0Rn5zMhk',
  );

  runApp(
    const ProviderScope(
      child: SupaApp(),
    ),
  );
}

class SupaApp extends StatefulWidget {
  const SupaApp({super.key});

  @override
  State<SupaApp> createState() => _SupaAppState();
}

class _SupaAppState extends State<SupaApp> {
  late final AppLinks _appLinks;
  StreamSubscription<AuthState>? _authSubscription;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    // Listen for incoming deep links
    _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[DeepLink] 🔗 Received: $uri');
      Supabase.instance.client.auth.getSessionFromUrl(uri);
    });

    // Listen for auth state changes — ensure profile row exists on every sign-in
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      debugPrint('[Auth] 🔑 Event: ${data.event}');
      final session = data.session;
      if (session != null) {
        const storage = FlutterSecureStorage();
        await storage.write(key: 'vectrax_access_token', value: session.accessToken);
        await storage.write(key: 'vectrax_refresh_token', value: session.refreshToken);
      }
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        // Ensure profile row exists (Google/GitHub OAuth won't trigger Flutter-side upsert otherwise)
        AuthService().ensureProfileExists();
      }
    });
  }

  void _navigateToDashboard() {
    _navigatorKey.currentState?.pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
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
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Vectrax',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return BiometricLockWrapper(child: child!);
      },
      home: const SplashScreen(),
    );
  }
}
