import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/core/services/premium_service.dart';

class PulsePremiumScreen extends StatelessWidget {
  const PulsePremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white38, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'VECTRAX PRO',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -150,
            right: -150,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Database Intelligence.\nWithout limits.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    'Upgrade to unlock unlimited AI prompts, diagnostics, and functions management.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white30,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 32),

                  // Premium Features List
                  _buildPremiumFeature(
                    'Neural AI Architect',
                    'Generate, deploy, and inspect complex database schemas with unlimited prompts.',
                    Icons.auto_awesome_rounded,
                    AppTheme.accent,
                  ),
                  _buildPremiumFeature(
                    'Infinite Projects Sync',
                    'Connect and monitor unlimited Supabase projects simultaneously (free tier is limited to 2).',
                    Icons.cloud_sync_rounded,
                    Colors.blueAccent,
                  ),
                  _buildPremiumFeature(
                    'Performance Diagnostics',
                    'Analyze real-time CPU, RAM load, database bloat, and run unlimited scans.',
                    Icons.speed_rounded,
                    Colors.orangeAccent,
                  ),
                  _buildPremiumFeature(
                    'Threat Protection',
                    'Scan for Row-Level Security (RLS) vulnerabilities and secure open tables.',
                    Icons.shield_rounded,
                    Colors.purpleAccent,
                  ),
                  _buildPremiumFeature(
                    'Edge Functions Console',
                    'Create, list, and control unlimited Supabase Edge Functions with visual logs.',
                    Icons.terminal_rounded,
                    Colors.redAccent,
                  ),

                  const SizedBox(height: 36),

                  // Pricing Hero Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.015),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                'DEVELOPER PLAN',
                                style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '\$9.99',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '/ month',
                                    style: GoogleFonts.inter(
                                      color: Colors.white38,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Cancel anytime • Instant activation',
                                style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Sleek Premium Button (Neon, Pill, Balanced Size)
                              SizedBox(
                                width: 200,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    HapticFeedback.heavyImpact();
                                    bool success = await PremiumService().purchasePremium(context);
                                    if (success && context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Vectrax Pro Membership Activated! 💎'),
                                          backgroundColor: AppTheme.accent,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    elevation: 0,
                                    shadowColor: AppTheme.accent.withOpacity(0.2),
                                  ),
                                  child: Text(
                                    'Upgrade to Pro',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'VECTRAX CORE • PREMIUM EDITION v2.0',
                      style: GoogleFonts.inter(
                        color: Colors.white10,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(
      String title, String description, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.015),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }
}
