import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/supa_button.dart';

/// A moving blueprint grid for a "CAD/Engineering" aesthetic.
class CyberBlueprintGrid extends StatelessWidget {
  const CyberBlueprintGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return InfiniteScrollingGrid();
  }
}

class InfiniteScrollingGrid extends StatefulWidget {
  @override
  _InfiniteScrollingGridState createState() => _InfiniteScrollingGridState();
}

class _InfiniteScrollingGridState extends State<InfiniteScrollingGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: GridPainter(progress: _controller.value),
          child: Container(),
        );
      },
    );
  }
}

class GridPainter extends CustomPainter {
  final double progress;
  GridPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accent.withOpacity(0.04)
      ..strokeWidth = 0.5;

    const double spacing = 50.0;
    final double offsetX = (progress * size.width) % spacing;
    final double offsetY = (progress * size.height) % spacing;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      canvas.drawLine(
          Offset(x + offsetX, 0), Offset(x + offsetX, size.height), paint);
    }
    for (double y = -spacing; y < size.height + spacing; y += spacing) {
      canvas.drawLine(
          Offset(0, y + offsetY), Offset(size.width, y + offsetY), paint);
    }

    // Add cross markers at intersections for "Engineering" look
    final markerPaint = Paint()
      ..color = AppTheme.accent.withOpacity(0.1)
      ..strokeWidth = 1.0;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        final center = Offset(x + offsetX, y + offsetY);
        canvas.drawLine(center - const Offset(3, 0),
            center + const Offset(3, 0), markerPaint);
        canvas.drawLine(center - const Offset(0, 3),
            center + const Offset(0, 3), markerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => true;
}

/// A streaming terminal log for AI "Thinking" visualization.
class NeuralTerminalStream extends StatefulWidget {
  const NeuralTerminalStream({super.key});

  @override
  State<NeuralTerminalStream> createState() => _NeuralTerminalStreamState();
}

class _NeuralTerminalStreamState extends State<NeuralTerminalStream> {
  final List<String> _logs = [
    "ATTACHING TO CORE...",
    "EXTRACTING SCHEMA ENTITIES",
    "ANUMERATING pg_tables",
    "DIAGNOSING RLS ENTROPY",
    "MAPPING INDEX VECTORS",
    "SCANNING SEQ_STATS",
    "EVALUATING INTEGRITY PATHS",
    "FLUID_ANALYSIS_MODE_ON",
    "NEURAL_HANDSHAKE_COMPLETE",
    "ISOLATING VULNERABILITIES",
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: List.generate(10, (index) {
          final log = _logs[index % _logs.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  "[${DateTime.now().millisecond}] ",
                  style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 8,
                      fontFamily: 'monospace'),
                ),
                Text(
                  log,
                  style: TextStyle(
                    color: AppTheme.accent.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(
                    duration: 2.seconds,
                    color: AppTheme.accent.withOpacity(0.2))
                .fadeOut(delay: 1.seconds),
          );
        }),
      ),
    );
  }
}

/// A central HUD showing "System Integrity"
class IntegrityHUD extends StatelessWidget {
  final double integrityScore;
  const IntegrityHUD({super.key, required this.integrityScore});

  @override
  Widget build(BuildContext context) {
    final color = integrityScore > 80
        ? AppTheme.accent
        : (integrityScore > 50 ? Colors.orangeAccent : Colors.redAccent);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: integrityScore / 100,
                strokeWidth: 2,
                color: color.withOpacity(0.3),
                backgroundColor: Colors.white.withOpacity(0.05),
              ),
            ),
            SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                value: integrityScore / 100,
                strokeWidth: 0.5,
                color: color,
              ),
            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 10.seconds),
            Column(
              children: [
                Text(
                  "${integrityScore.toInt()}%",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1),
                ),
                Text(
                  "INTEGRITY",
                  style: TextStyle(
                      color: color.withOpacity(0.6),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// A high-end, Pulse Pro membership card for the "No-Fluff" upgrade path.
class PulseProMembershipCard extends StatelessWidget {
  final VoidCallback onUpgrade;
  final VoidCallback onClose;

  const PulseProMembershipCard({
    super.key,
    required this.onUpgrade,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        color: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PULSE PRO',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white24, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 80),
            const Text(
              'The Architect\'s\nComplete Cure.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Manual patching is for hobbyists. Senior architects automate the fix. Unlock the 1-Click Repair engine and secure your project for a lifetime.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 80),
            _buildFeature(
                'UNLIMITED NEURAL FIXES', 'Remove the daily limit and authorize unlimited system repairs.'),
            _buildFeature(
                'FULL FLEET ACCESS', 'Unlock the Architect for all your projects, not just the first three.'),
            _buildFeature('GHOST PULSE',
                'Real-time anomaly detection and traffic alerts.'),
            SupaButton(
              onPressed: onUpgrade,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              child: const Center(
                child: Text(
                  'UPGRADE TO PRO — \$10 / MO',
                  style:
                      TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'NO COMMITMENT • CANCEL ANYTIME',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.15),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.fastOutSlowIn);
  }

  Widget _buildFeature(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// A prominent, hero-style launchpad for project audits.
class NeuralAuditLaunchpad extends StatelessWidget {
  final VoidCallback onTap;
  final String projectName;

  const NeuralAuditLaunchpad({
    super.key,
    required this.onTap,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: AppTheme.accent, size: 24),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'START FULL SYSTEM SCAN',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Target: ${projectName.toUpperCase()}',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white10, size: 16),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 800.ms).slideX(begin: 0.05, end: 0);
  }
}

/// A premium engineering HUD for AI output.
class EngineeringOutputConsole extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const EngineeringOutputConsole({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF030303),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.02),
            blurRadius: 20,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded,
                    size: 12, color: Colors.white24),
                const SizedBox(width: 8),
                const Text(
                  'SYSTEM_INJECTION_BUFFER',
                  style: TextStyle(
                      color: Colors.white24,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5),
                ),
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: AppTheme.accent, shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.5, 1.5),
                      duration: 1.seconds,
                    )
                    .fadeOut(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: TextField(
              controller: controller,
              maxLines: 12,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.accent,
                fontSize: 13,
                height: 1.6,
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.05)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String label;
  const SectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

/// A large, glowing floating card for high-level metrics.
/// Achieves a "Spotify Premium" expensive aesthetic.
class MacroHealthCard extends StatelessWidget {
  final String title;
  final String value;
  final Color themeColor;
  final IconData icon;
  final VoidCallback onTap;

  const MacroHealthCard({
    super.key,
    required this.title,
    required this.value,
    required this.themeColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF030303),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: themeColor.withOpacity(0.1), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: themeColor, size: 20),
                Text(
                  'STABLE',
                  style: TextStyle(
                    color: themeColor.withOpacity(0.4),
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms)
        .slideY(begin: 0.05, end: 0, curve: Curves.fastOutSlowIn);
  }
}

/// A horizontal scrollable row of glassmorphic pills for switching projects.
class ExecutiveProjectSelector extends StatelessWidget {
  final List<dynamic> projects;
  final String? selectedRef;
  final Function(dynamic) onSelected;

  const ExecutiveProjectSelector({
    super.key,
    required this.projects,
    required this.selectedRef,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: projects.length,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        itemBuilder: (context, index) {
          final project = projects[index];
          final ref = project['ref'] ?? project['id'];
          final isSelected = ref == selectedRef;

          return GestureDetector(
            onTap: () => onSelected(project),
            child: AnimatedContainer(
              duration: 300.ms,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color:
                    isSelected ? Colors.white : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Center(
                child: Text(
                  (project['name'] as String).toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A bold, high-contrast button for "Killer" scan semantics.
class ScanCommandButton extends StatelessWidget {
  final String label;
  final String subLabel;
  final Color themeColor;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  final bool isNeon;

  const ScanCommandButton({
    super.key,
    required this.label,
    required this.subLabel,
    required this.themeColor,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.isNeon = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: themeColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (isNeon)
              BoxShadow(
                color: themeColor.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: -5,
              ),
          ],
          gradient: isNeon
              ? LinearGradient(
                  colors: [themeColor, themeColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            else
              const Icon(Icons.bolt_rounded,
                  color: Colors.black,
                  size: 24), // Use one black zap as requested
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A minimalist mini-card for project selection.
/// Used in the "Full Zoom Out" Vectrax view.
class MiniProjectCard extends StatelessWidget {
  final String name;
  final String status;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;
  final String cpu;
  final String ram;

  const MiniProjectCard({
    super.key,
    required this.name,
    required this.status,
    required this.isSelected,
    required this.onTap,
    this.isLocked = false,
    this.cpu = '0.0%',
    this.ram = '0MB',
  });

  @override
  Widget build(BuildContext context) {
    final bool isPaused = status == 'PAUSED';
    final bool isActive = status == 'ACTIVE_HEALTHY' || status == 'ACTIVE';
    final Color statusColor =
        isPaused ? Colors.redAccent : (isActive ? AppTheme.accent : Colors.orangeAccent);

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: AnimatedContainer(
        duration: 400.ms,
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withOpacity(0.06) : Colors.white.withOpacity(0.015),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withOpacity(0.5)
                : Colors.white.withOpacity(isLocked ? 0.02 : 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.08),
                blurRadius: 16,
                spreadRadius: -4,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Opacity(
                opacity: isLocked ? 0.35 : 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (isLocked)
                            const Icon(Icons.lock_outline_rounded,
                                color: Colors.white38, size: 8)
                          else
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: statusColor.withOpacity(0.4),
                                        blurRadius: 4)
                                  ]),
                            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                          const SizedBox(width: 6),
                          Text(
                            isLocked || isPaused
                                ? 'PAUSED'
                                : (isActive ? 'ONLINE' : 'STANDBY'),
                            style: GoogleFonts.inter(
                              color: isLocked ? Colors.white38 : statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildMiniMetric('CONN', cpu, AppTheme.accent),
                      const Spacer(),
                      _buildMiniMetric('SIZE', ram, Colors.blueAccent),
                    ],
                  ),
                ],
              ),
              if (isLocked)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('PRO',
                        style: GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
              color: Colors.white30,
              fontSize: 7,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.robotoMono(
              color: color.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
