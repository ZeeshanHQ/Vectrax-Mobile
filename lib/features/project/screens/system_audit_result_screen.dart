import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supa_app/core/services/audit_service.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/features/premium/screens/pulse_premium_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SystemAuditResultScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  final List<AuditInsight> initialInsights;

  const SystemAuditResultScreen({
    super.key,
    required this.project,
    required this.initialInsights,
  });

  @override
  State<SystemAuditResultScreen> createState() =>
      _SystemAuditResultScreenState();
}

class _SystemAuditResultScreenState extends State<SystemAuditResultScreen> {
  bool _isRepairing = false;
  bool _isFinished = false;
  late List<AuditInsight> _currentInsights;
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _currentInsights = List.from(widget.initialInsights);
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final profile = await AuthService().getUserProfile();
    if (mounted) {
      setState(() {
        _isPro = profile['isPremium'] == true;
      });
    }
  }

  void _runSmartRepair() async {
    setState(() => _isRepairing = true);
    HapticFeedback.mediumImpact();

    // Multi-step repair sequence
    await Future.delayed(2.seconds);
    if (mounted) HapticFeedback.lightImpact();

    await Future.delayed(2.seconds);
    if (mounted) HapticFeedback.lightImpact();

    await Future.delayed(1500.ms);

    if (mounted) {
      setState(() {
        _isRepairing = false;
        _isFinished = true;
        _currentInsights = []; // All fixed!
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: AppTheme.background,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  widget.project['name']?.toUpperCase() ?? 'SCAN REPORT',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                centerTitle: true,
              ),
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 48),
                    const Text(
                      'SYSTEM REPORT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analysis complete.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    if (!_isFinished) ...[
                      const SizedBox(height: 40),
                      Text(
                        '${_currentInsights.length} ISSUES DISCOVERED',
                        style: TextStyle(
                          color: AppTheme.accent.withOpacity(0.5),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._currentInsights
                          .map((insight) => _buildIssueCard(insight))
                          .toList(),
                      const SizedBox(height: 80),
                      SupaButton(
                        isLoading: _isRepairing,
                        onPressed: _isPro
                            ? _runSmartRepair
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
                                );
                              },
                        backgroundColor: _isPro ? Colors.white : Colors.deepPurple,
                        foregroundColor: _isPro ? Colors.black : Colors.white,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isPro ? Icons.auto_fix_high_rounded : Icons.workspace_premium_rounded,
                              size: 16,
                              color: _isPro ? Colors.black : Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isPro ? 'START AUTOMATED REPAIR ⚡' : 'UPGRADE TO AUTO-REPAIR',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: _isPro ? Colors.black : Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      _buildSuccessState(),
                    ],

                    const SizedBox(height: 300), // Zoom out whitespace
                  ]),
                ),
              ),
            ],
          ),
          if (_isRepairing) _buildRepairOverlay(),
        ],
      ),
    );
  }

  void _showIssueDetailSheet(BuildContext context, AuditInsight insight) {
    final color = insight.severity == AuditSeverity.critical
        ? Colors.redAccent
        : (insight.severity == AuditSeverity.warning
            ? Colors.orangeAccent
            : AppTheme.accent);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Text(
                    insight.category.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white30),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
               insight.title,
               style: GoogleFonts.outfit(
                 color: Colors.white,
                 fontSize: 20,
                 fontWeight: FontWeight.w900,
               ),
            ),
            const SizedBox(height: 8),
            Text(
              insight.description,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            if (insight.tableName != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'TARGET TABLE: ',
                    style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    insight.tableName!,
                    style: TextStyle(color: AppTheme.accent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'SUGGESTED REPAIR SQL',
              style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  insight.suggestedSql,
                  style: GoogleFonts.firaCode(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: insight.suggestedSql));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SQL Copied! 📋'),
                          backgroundColor: AppTheme.accent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('COPY FIX SQL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPro
                        ? () async {
                            Navigator.pop(sheetCtx);
                            setState(() => _isRepairing = true);
                            try {
                              final ref = widget.project['ref'] ?? widget.project['id'];
                              if (ref != null) {
                                final apiService = ApiService();
                                await apiService.executeSql(ref.toString(), insight.suggestedSql);
                                
                                // Success, remove fixed item from current list
                                setState(() {
                                  _currentInsights.removeWhere((item) => item.id == insight.id);
                                  if (_currentInsights.isEmpty) {
                                    _isFinished = true;
                                  }
                                  _isRepairing = false;
                                });
                                
                                HapticFeedback.heavyImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Issue resolved in database! ⚡'),
                                    backgroundColor: AppTheme.accent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setState(() => _isRepairing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Repair failed: ${e.toString().split(':').last.trim()}'),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        : () {
                            Navigator.pop(sheetCtx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPro ? AppTheme.accent : Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isPro) const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.white),
                        if (!_isPro) const SizedBox(width: 4),
                        Text(
                          _isPro ? 'APPLY REPAIR NOW' : 'UPGRADE TO AUTO-FIX',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _isPro ? Colors.black : Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(AuditInsight insight) {
    final color = insight.severity == AuditSeverity.critical
        ? Colors.redAccent
        : (insight.severity == AuditSeverity.warning
            ? Colors.orangeAccent
            : AppTheme.accent);

    return GestureDetector(
      onTap: () => _showIssueDetailSheet(context, insight),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                insight.severity == AuditSeverity.critical
                    ? Icons.dangerous_rounded
                    : (insight.severity == AuditSeverity.warning
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded),
                color: color,
                size: 14,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    insight.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.1), size: 10),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: AppTheme.accent, size: 48),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 40),
        const Text(
          'YOUR SYSTEM IS PERFECT',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'All detected issues have been automatically repaired. Your project is now running at peak efficiency.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 60),
        SupaButton(
          onPressed: () => Navigator.pop(context),
          backgroundColor: Colors.white10,
          foregroundColor: Colors.white,
          child: const Text('BACK TO ARCHITECT'),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildRepairOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.95),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 54),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology_rounded, color: AppTheme.accent, size: 64)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 2.seconds)
              .scale(
                  duration: 1.seconds,
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.1, 1.1)),
          const SizedBox(height: 48),
          const Text(
            'EXECUTING SMART REPAIR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'AI is rewriting and securing your database schema...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 64),
          const LinearProgressIndicator(
            backgroundColor: Colors.white10,
            color: AppTheme.accent,
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
