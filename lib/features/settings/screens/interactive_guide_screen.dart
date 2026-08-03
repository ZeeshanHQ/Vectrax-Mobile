import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';

class InteractiveGuideScreen extends StatefulWidget {
  const InteractiveGuideScreen({super.key});

  @override
  State<InteractiveGuideScreen> createState() => _InteractiveGuideScreenState();
}

class _InteractiveGuideScreenState extends State<InteractiveGuideScreen> {
  int _activeStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Secure Connection',
      'icon': Icons.vpn_key_rounded,
      'color': Colors.blueAccent,
      'tagline': 'Establish secure Supabase OAuth linkages',
      'description':
          'Vectrax links directly to your Supabase account using official Supabase Management API OAuth. This authorizes the secure exchange of projects, tables, and edge function metadata.',
      'bullets': [
        'Safe token store backed by PostgreSQL',
        'Automatic credential refresh on app start',
        'No direct database password required'
      ]
    },
    {
      'title': 'Vectrax Data Explorer',
      'icon': Icons.table_chart_rounded,
      'color': AppTheme.accent,
      'tagline': 'Real-time database operations & CRUD',
      'description':
          'Browse tables, read records, and check schema health. Swap monitored project slots smoothly on the fly to control your active connections.',
      'bullets': [
        'Inspect table structures and column types',
        'Quick record browsers with search filters',
        'Live schema health calculations'
      ]
    },
    {
      'title': 'Edge Functions Console',
      'icon': Icons.bolt_rounded,
      'color': Colors.purpleAccent,
      'tagline': 'Manage serverless functions & secrets',
      'description':
          'Select any Edge Function to view custom filtered execution logs. Add, edit, or delete secure project secrets variables.',
      'bullets': [
        'Secure write-only environment variable CRUD',
        'Real-time filtered diagnostic logs',
        'Direct project ref routing integrations'
      ]
    },
    {
      'title': 'AI Architect Terminal',
      'icon': Icons.auto_awesome_rounded,
      'color': Colors.orangeAccent,
      'tagline': 'Turn natural language to valid SQL',
      'description':
          'Speak or write queries in natural English. Architect reviews your active table schema context, synthesizes optimized SQL, and runs it safely.',
      'bullets': [
        'Unlocks direct DB queries from prompt',
        'Fully schema-aware code generation',
        'History log of executed query scripts'
      ]
    },
    {
      'title': 'Vulnerability Diagnostics',
      'icon': Icons.shield_rounded,
      'color': Colors.redAccent,
      'tagline': 'Scan & Repair schema issues instantly',
      'description':
          'Run instant audits for security gaps (like missing RLS policies) or optimization alerts. Launch Automated Repair to resolve them with one tap.',
      'bullets': [
        'Checks pg_policies for security gaps',
        'Bypasses prompts for fully healthy projects',
        'Automated repair scripts execution'
      ]
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _steps[_activeStep]['color'].withOpacity(0.06),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom Header
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'VECTRAX GUIDE',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                centerTitle: true,
              ),

              // Page Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Interactive Tutorial',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 8),
                    Text(
                      'Learn how to leverage Vectrax Remote Control to securely monitor and repair your Supabase projects.',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 32),

                    // Interactive Step Indicator Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_steps.length, (index) {
                          final step = _steps[index];
                          final isActive = _activeStep == index;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _activeStep = index);
                            },
                            child: AnimatedContainer(
                              duration: 300.ms,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? step['color'].withOpacity(0.08)
                                    : Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive
                                      ? step['color'].withOpacity(0.3)
                                      : Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    step['icon'],
                                    size: 16,
                                    color: isActive ? step['color'] : Colors.white24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    step['title'],
                                    style: GoogleFonts.inter(
                                      color: isActive ? step['color'] : Colors.white38,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ).animate().fadeIn(delay: 250.ms),

                    const SizedBox(height: 32),

                    // Active Step Card
                    AnimatedSwitcher(
                      duration: 400.ms,
                      child: _buildActiveStepCard(context),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStepCard(BuildContext context) {
    final step = _steps[_activeStep];
    final Color color = step['color'];

    return KeyedSubtree(
      key: ValueKey<int>(_activeStep),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: color.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Highlight Header Icon & Tagline
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.06),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(step['icon'], color: color, size: 36),
                    const SizedBox(height: 16),
                    Text(
                      step['tagline'].toString().toUpperCase(),
                      style: GoogleFonts.inter(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step['title'],
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  step['description'],
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Bullets list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: (step['bullets'] as List<String>).map((bullet) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: color, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              bullet,
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Next / Close Action Row
              Padding(
                padding: const EdgeInsets.all(28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_activeStep > 0)
                      TextButton(
                        onPressed: () {
                          setState(() => _activeStep--);
                        },
                        child: Text(
                          'Back',
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(),
                    ElevatedButton(
                      onPressed: () {
                        if (_activeStep < _steps.length - 1) {
                          setState(() => _activeStep++);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _activeStep < _steps.length - 1 ? 'Next Module' : 'Complete Guide',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
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
    );
  }
}
