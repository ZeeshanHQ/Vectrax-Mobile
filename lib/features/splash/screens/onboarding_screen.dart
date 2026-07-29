import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/main_navigation_screen.dart';
import 'package:supa_app/features/auth/screens/login_screen.dart';

// ─── DATA MODEL ──────────────────────────────────────────────────
class OnboardingSlide {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;

  const OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
  });
}

// ─── MAIN SCREEN ─────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _orbitCtrl;
  late AnimationController _breathCtrl;

  static const _slides = [
    OnboardingSlide(
      title: 'Guarded',
      subtitle: 'AUTOPILOT SECURITY',
      description:
          'AI watches policies, roles, and access patterns\nso your Postgres never drifts out of spec.',
      icon: Icons.shield_rounded,
    ),
    OnboardingSlide(
      title: 'Live',
      subtitle: 'REAL-TIME TELEMETRY',
      description:
          'Slow queries, connections, CPU and row-level metrics\nin one streaming timeline.',
      icon: Icons.bolt_rounded,
    ),
    OnboardingSlide(
      title: 'In Control',
      subtitle: 'ONE DB COCKPIT',
      description:
          'Indexes, storage, logs and AI repairs —\nall from a single command center.',
      icon: Icons.rocket_launch_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _breathCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildBackground(),
            _buildPages(),
            _buildTopBar(),
            _buildBottom(),
          ],
        ),
      ),
    );
  }

  // ─── BACKGROUND ────────────────────────────────────────────────
  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _orbitCtrl,
      builder: (_, __) {
        final a = _orbitCtrl.value * 2 * math.pi;
        return Stack(
          children: [
            // Ambient glow at screen center
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.32,
              left: MediaQuery.sizeOf(context).width / 2 - 200,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppTheme.accent.withOpacity(0.07),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            // Orbit dot A
            _orbitDot(a, 200, 5, 0.55),
            // Orbit dot B (slower, smaller)
            _orbitDot(a * 0.6 + math.pi, 150, 3, 0.25),

            // Subtle horizontal line
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.62,
              left: 0,
              right: 0,
              child: Container(
                height: 0.5,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ],
        );
      },
    );
  }

  Positioned _orbitDot(
      double angle, double radius, double size, double opacity) {
    final cx = MediaQuery.sizeOf(context).width / 2;
    final cy = MediaQuery.sizeOf(context).height * 0.42;
    return Positioned(
      left: cx + radius * math.cos(angle) - size / 2,
      top: cy + radius * math.sin(angle) - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.accent.withOpacity(opacity),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(opacity * 0.8),
              blurRadius: size * 3,
            ),
          ],
        ),
      ),
    );
  }

  // ─── PAGES ─────────────────────────────────────────────────────
  Widget _buildPages() {
    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (i) {
        HapticFeedback.lightImpact();
        setState(() => _currentPage = i);
      },
      itemCount: _slides.length,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double page = _currentPage.toDouble();
            if (_pageController.hasClients &&
                _pageController.position.haveDimensions) {
              page = _pageController.page ?? _currentPage.toDouble();
            }
            final delta = (page - index).clamp(-1.0, 1.0);
            final scale = 1 - (0.06 * delta.abs());
            final opacity = 1 - (0.35 * delta.abs());

            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 26 * delta.abs()),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
            );
          },
          child: _buildSlide(index),
        );
      },
    );
  }

  Widget _buildSlide(int i) {
    final slide = _slides[i];
    final size = MediaQuery.sizeOf(context);

    return Padding(
      padding:
          EdgeInsets.fromLTRB(24, size.height * 0.12, 24, size.height * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero DB composition
          SizedBox(
            height: size.height * 0.30,
            child: Center(
              child: _buildIconZone(slide, i)
                  .animate(key: ValueKey('core$i'))
                  .fadeIn(duration: 700.ms)
                  .scale(
                    begin: const Offset(1.06, 1.06),
                    end: const Offset(1.0, 1.0),
                    curve: Curves.easeOutCubic,
                    duration: 800.ms,
                  ),
            ),
          ),

          SizedBox(height: size.height * 0.05),

          // Microcopy subtitle
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppTheme.accent,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          )
              .animate(key: ValueKey('s$i'))
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .slideY(begin: 0.4, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 10),

          // Main headline
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              height: 1.1,
            ),
          )
              .animate(key: ValueKey('t$i'))
              .fadeIn(duration: 600.ms)
              .scale(
                begin: const Offset(0.92, 0.92),
                duration: 700.ms,
                curve: Curves.easeOutBack,
              )
              .shimmer(
                delay: 1300.ms,
                duration: 2200.ms,
                color: Colors.white24,
              ),

          const SizedBox(height: 18),

          // Description
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.60),
              fontSize: 15,
              height: 1.8,
              fontWeight: FontWeight.w400,
            ),
          )
              .animate(key: ValueKey('d$i'))
              .fadeIn(delay: 420.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }

  // ─── ICON ZONE ─────────────────────────────────────────────────
  Widget _buildIconZone(OnboardingSlide slide, int index) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathCtrl, _orbitCtrl]),
      builder: (_, __) {
        final breath = _breathCtrl.value;
        final angle = _orbitCtrl.value * 2 * math.pi;

        final floatY = (breath - 0.5) * 2; // -1..1

        // Per-slide variations so each onboarding step feels unique
        final badgeLabel = switch (index) {
          0 => 'RLS WATCH',
          1 => 'QUERY HEAT',
          _ => 'INDEX HEALTH',
        };

        final metricLabel = switch (index) {
          0 => 'POLICIES OK',
          1 => 'AVG LATENCY',
          _ => 'INDEX COVER',
        };

        final metricValue = switch (index) {
          0 => '24 / 24',
          1 => '12.4 ms',
          _ => '98.2 %',
        };

        final barHeights = switch (index) {
          0 => [8.0, 14.0, 18.0, 16.0, 10.0],
          1 => [10.0, 18.0, 26.0, 20.0, 14.0],
          _ => [6.0, 12.0, 20.0, 24.0, 18.0],
        };

        return SizedBox(
          width: 260,
          height: 220,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background glow
              Positioned(
                top: 40,
                left: 10,
                right: 10,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [
                        AppTheme.accent.withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Main "query editor" panel
              Transform.translate(
                offset: Offset(0, floatY * 8),
                child: Container(
                  width: 230,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.65),
                        blurRadius: 32,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top line: three dots + live pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.25),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.black.withOpacity(0.6),
                              border: Border.all(
                                color: AppTheme.accent.withOpacity(0.55),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              badgeLabel,
                              style: GoogleFonts.inter(
                                color: AppTheme.accent,
                                fontSize: 8,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Fake query + result grid
                      Expanded(
                        child: Row(
                          children: [
                            // Left: query text lines
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _codeLine(widthFactor: 0.9),
                                  _codeLine(widthFactor: 0.7),
                                  _codeLine(widthFactor: 0.55),
                                  _codeLine(widthFactor: 0.8, dim: true),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Right: tiny bar chart
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(5, (j) {
                                    final h = barHeights[j];
                                    return Container(
                                      width: 4,
                                      height: h + floatY * 2,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            AppTheme.accent.withOpacity(0.9),
                                            AppTheme.accent.withOpacity(0.1),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating metric card
              Transform.translate(
                offset: Offset(70 * math.cos(angle), -40 + floatY * 4),
                child: Container(
                  width: 120,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.black.withOpacity(0.9),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.10), width: 0.8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        metricLabel,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 8,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        metricValue,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accent,
                              Colors.greenAccent.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _codeLine({required double widthFactor, bool dim = false}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(dim ? 0.14 : 0.32),
        ),
      ),
    );
  }

  // ─── BOTTOM CONTROLS ───────────────────────────────────────────
  Widget _buildBottom() {
    final isLast = _currentPage == _slides.length - 1;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 48,
          left: 32,
          right: 32,
          top: 48,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black,
              Colors.black.withOpacity(0.96),
              Colors.transparent
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = _currentPage == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutQuart,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.accent : Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color: AppTheme.accent.withOpacity(0.55),
                                blurRadius: 10,
                                spreadRadius: 1)
                          ]
                        : [],
                  ),
                );
              }),
            ),

            const SizedBox(height: 44),

            // CTA
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                    scale: Tween(begin: 0.94, end: 1.0).animate(anim),
                    child: child),
              ),
              child: isLast ? _finalButtons() : _nextButton(),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  // ─── TOP BAR (SKIP BUTTON) ──────────────────────────────────────
  Widget _buildTopBar() {
    final isLast = _currentPage == _slides.length - 1;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 20,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isLast ? 0.0 : 1.0,
        child: IgnorePointer(
          ignoring: isLast,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SKIP',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nextButton() {
    return SizedBox(
      key: const ValueKey('next'),
      width: double.infinity,
      height: 60,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _nextPage();
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                AppTheme.accent,
                const Color(0xFF00B0FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'NEXT',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.black,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _finalButtons() {
    return SizedBox(
      key: const ValueKey('final'),
      width: double.infinity,
      height: 60,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                AppTheme.accent,
                const Color(0xFF00B0FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'GET STARTED',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.rocket_launch_rounded,
                color: Colors.black,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
