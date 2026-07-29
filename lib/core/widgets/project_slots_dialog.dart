import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/services/project_context.dart';
import 'package:supa_app/features/premium/screens/pulse_premium_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectSlotsDialog extends StatelessWidget {
  final List<dynamic> allProjects;
  final Map<String, dynamic> targetProject;
  final VoidCallback onSwapped;

  const ProjectSlotsDialog({
    super.key,
    required this.allProjects,
    required this.targetProject,
    required this.onSwapped,
  });

  static void show(
    BuildContext context, {
    required List<dynamic> allProjects,
    required Map<String, dynamic> targetProject,
    required VoidCallback onSwapped,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (_) => ProjectSlotsDialog(
        allProjects: allProjects,
        targetProject: targetProject,
        onSwapped: onSwapped,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectCtx = ProjectContext();
    final activeIds = projectCtx.monitoredProjectIds;
    
    // Find project details for the active slots
    final activeProjects = allProjects.where((p) {
      final id = p['id'] ?? p['ref'] ?? '';
      return activeIds.contains(id.toString());
    }).toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar Indicator
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Icon and Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        color: AppTheme.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'MONITORING SLOTS FULL',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '2/2 SLOTS',
                        style: GoogleFonts.inter(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Your free tier allows monitoring up to 2 Supabase projects simultaneously. Tap an active project below to deactivate it and monitor "${targetProject['name'] ?? 'New Project'}" instead.',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Active Projects List
                if (activeProjects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No active projects configured.',
                        style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ...activeProjects.map((proj) {
                    final projId = (proj['id'] ?? proj['ref'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () async {
                          HapticFeedback.heavyImpact();
                          
                          // Check for swap limit (3 swaps per 24 hours)
                          final prefs = await SharedPreferences.getInstance();
                          final now = DateTime.now();
                          List<String> swapTimestamps = prefs.getStringList('project_swap_timestamps') ?? [];
                          
                          // Filter timestamps from the last 24 hours
                          final last24Hours = swapTimestamps.where((tStr) {
                            try {
                              final dt = DateTime.parse(tStr);
                              return now.difference(dt).inHours < 24;
                            } catch (_) {
                              return false;
                            }
                          }).toList();
                          
                          if (last24Hours.length >= 3) {
                            // Block and show notice
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                backgroundColor: Colors.grey[950],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: const BorderSide(color: Colors.white10),
                                ),
                                title: Text(
                                  'SWAP LIMIT EXCEEDED',
                                  style: GoogleFonts.outfit(
                                    color: Colors.redAccent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                content: Text(
                                  'Free tier users are limited to 3 project swaps per 24 hours. Upgrade to Vectrax Pro to monitor unlimited projects simultaneously.',
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx),
                                    child: const Text('Close', style: TextStyle(color: Colors.white54)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accent,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: const Text('Upgrade Pro'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          
                          // Record the new swap timestamp
                          last24Hours.add(now.toIso8601String());
                          await prefs.setStringList('project_swap_timestamps', last24Hours);
                          
                          // Perform swap
                          await projectCtx.swapProjectSlot(projId, (targetProject['id'] ?? targetProject['ref'] ?? '').toString());
                          projectCtx.selectProject(targetProject);
                          Navigator.pop(context);
                          onSwapped();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.accent,
                              content: Text(
                                'Swapped slot: "${proj['name']}" deactivated. "${targetProject['name']}" is now active! ⚡',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.015),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, color: AppTheme.terminalGreen, size: 10),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (proj['name'] ?? 'Untitled').toString().toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ref: $projId',
                                      style: GoogleFonts.inter(
                                        color: Colors.white30,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                                ),
                                child: Text(
                                  'SWAP',
                                  style: GoogleFonts.inter(
                                    color: Colors.redAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                const SizedBox(height: 16),

                // Divider Or
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white12)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR UNLOCK ALL',
                        style: GoogleFonts.inter(
                          color: Colors.white24,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Colors.white12)),
                  ],
                ),
                const SizedBox(height: 20),

                // Upgrade Button
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Upgrade to Vectrax Pro',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
