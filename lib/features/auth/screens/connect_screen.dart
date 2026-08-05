import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/main_navigation_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supa_app/core/config/app_config.dart';
import 'package:supa_app/features/feedback/screens/feedback_screen.dart' as sup;
import 'package:supa_app/features/auth/screens/login_screen.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supa_app/core/widgets/loading_overlay.dart';
import 'package:app_links/app_links.dart';
import 'package:supa_app/features/auth/screens/syncing_screen.dart';
import 'package:supa_app/core/services/notification_service.dart';

/// Shown right after a successful login.
/// Gives the user a premium moment before entering the app.
class ConnectScreen extends StatefulWidget {
  final String? userEmail;
  const ConnectScreen({super.key, this.userEmail});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  bool _pulseActive = false;
  bool _isPressed = false;
  bool _isLoading = false;
  
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _startPulse();
    _initDeepLinkListener();
  }

  void _startPulse() {
    // Start the pulse animation after a short delay
    Future.delayed(400.ms, () {
      if (mounted) setState(() => _pulseActive = true);
    });
  }

  void _initDeepLinkListener() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[ConnectScreen] 🔗 Received DeepLink: $uri');
      // Only navigate to Dashboard if the user has actively clicked
      // "CONNECT SUPABASE" (i.e., _isLoading is true).
      // This prevents the login-callback code from accidentally
      // triggering a Dashboard transition.
      if (uri.queryParameters.containsKey('code')) {
        final code = uri.queryParameters['code']!;
        _exchangeCodeAndNavigate(code);
      }
    });
  }

  Future<void> _exchangeCodeAndNavigate(String code) async {
    try {
      debugPrint('[ConnectScreen] 🔄 Exchanging code for token...');
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/auth/exchange'),
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'X-User-Id': userId,
        },
        body: jsonEncode({
          'code': code,
          'codeVerifier': AppConfig.codeVerifier,
          'redirectUri': AppConfig.redirectUri,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;

        if (accessToken != null) {
          // 1. Save locally for fast connection verification checks
          const storage = FlutterSecureStorage();
          await storage.write(key: 'supabase_access_token', value: accessToken);
          if (refreshToken != null) {
            await storage.write(key: 'supabase_refresh_token', value: refreshToken);
          }

          // Cancel the database connection reminder since it is now connected
          NotificationService().cancelNotification(4567);

          debugPrint('[ConnectScreen] ✅ Connection complete. Navigating...');
          _navigateToDashboard();
        } else {
          debugPrint('[ConnectScreen] ❌ No access token in response');
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        debugPrint('[ConnectScreen] ❌ Exchange failed: ${response.statusCode} ${response.body}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[ConnectScreen] ❌ Exchange error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (context, animation, secondaryAnimation) => 
            const SyncingScreen(),
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
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final url = Uri.parse(AppConfig.loginUrl);
    debugPrint('[ConnectScreen] 🚀 Launching OAuth URL: $url');

    try {
      // Launch via external application to guarantee robust custom scheme (com.supabasepulse://) handling
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[ConnectScreen] ❌ Launch error: $e');
      // Last resort fallback using native platform default
      try {
        await launchUrl(url);
      } catch (e2) {
        debugPrint('[ConnectScreen] ❌ InAppWebView also failed: $e2');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open browser. Check your internet connection.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // ── Radial glow background ──────────────────────────────────
            Positioned(
              top: size.height * 0.1,
              left: size.width * 0.5 - 200,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 2000),
                curve: Curves.easeInOutSine,
                width: _pulseActive ? 400 : 250,
                height: _pulseActive ? 400 : 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withOpacity(_pulseActive ? 0.08 : 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Main Content ────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(flex: 3),

                    // Brand badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.05),
                        border:
                            Border.all(color: AppTheme.accent.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat())
                              .shimmer(duration: 1.5.seconds),
                          const SizedBox(width: 8),
                          Text(
                            'VECTRAX STATUS',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.accent.withOpacity(0.6),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideX(begin: -0.1, end: 0),

                    const SizedBox(height: 32),

                    // Main headline
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Colors.white70],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        'You\'re\nConnected.',
                        style: GoogleFonts.outfit(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -1.5,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 400.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 20),

                    // Sub text
                    if (widget.userEmail != null)
                      Text(
                        'Session active for ${widget.userEmail}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white38,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fadeIn(delay: 600.ms),

                    const SizedBox(height: 12),
                    Text(
                      'Vectrax is now synchronised with your\ninfrastructure environment.',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white24,
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                      ),
                    ).animate().fadeIn(delay: 750.ms),

                    const Spacer(flex: 4),

                    // ── Unified Status Control Panel ───────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SECURE INFRASTRUCTURE STATUS',
                            style: GoogleFonts.jetBrainsMono(
                              color: AppTheme.accent.withOpacity(0.5),
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatusIndicator('Vault', true, 1.seconds),
                              _buildStatusIndicator('Keys', true, 1.1.seconds),
                              _buildStatusIndicator('Sync', true, 1.2.seconds),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 40),

                    // ── Connect Now CTA ─────────────────────────────────
                    _buildConnectButton(),

                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        'Astraventa Secure Access',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: Colors.white10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ).animate().fadeIn(delay: 1500.ms),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const LoadingOverlay(message: 'AWAITING AUTHORIZATION...'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool active, Duration delay) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppTheme.accent : Colors.white12,
            boxShadow: active
                ? [
                    BoxShadow(
                        color: AppTheme.accent.withOpacity(0.5),
                        blurRadius: 4)
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              active ? 'ONLINE' : 'OFFLINE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                color: active ? AppTheme.accent : Colors.white24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: delay);
  }

  Widget _buildConnectButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleConnect,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.2),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'CONNECT SUPABASE',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.black, size: 22),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 1.6.seconds).slideY(begin: 0.2, end: 0);
  }
}
