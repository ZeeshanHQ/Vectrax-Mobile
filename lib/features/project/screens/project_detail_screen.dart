import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supa_app/core/widgets/success_check.dart';
import 'package:supa_app/features/project/screens/logs_screen.dart';
import 'package:supa_app/features/project/screens/ai_query_screen.dart';
import 'package:supa_app/features/database/screens/table_browser_screen.dart';
import 'package:supa_app/features/database/screens/sql_snippets_screen.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/features/auth/screens/login_screen.dart';
import 'package:supa_app/features/project/screens/user_management_screen.dart';
import 'package:supa_app/features/premium/screens/pulse_premium_screen.dart';
import 'dart:async';
import 'dart:math';

class ProjectDetailScreen extends StatefulWidget {
  final String projectName;
  final String projectRef;
  final bool isPaused;
  final bool isDemoMode;
  final double initialCpu;
  final double initialRam;

  const ProjectDetailScreen({
    super.key,
    required this.projectName,
    required this.projectRef,
    this.isPaused = false,
    this.isDemoMode = false,
    this.initialCpu = 15.4,
    this.initialRam = 1024.0,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool _isTogglingStatus = false;
  bool _isRestarting = false;
  late bool _localIsPaused;
  final AuthService _authService = AuthService();
  bool _isPro = false;

  Future<void> _fetchUserProfile() async {
    final profile = await _authService.getUserProfile();
    if (mounted) {
      setState(() {
        _isPro = profile['isPremium'] ?? false;
      });
    }
  }

  Timer? _metricsTimer;
  List<double> _cpuPoints = [];
  List<double> _ramPoints = [];
  List<double> _ioPoints = [0.2, 0.1, 0.6, 0.3, 0.2, 0.8, 0.4];
  final Random _random = Random();
  
  late double _currentCpu;
  late double _currentRam;
  double _currentIo = 8.2;
  late double _ramScale;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _localIsPaused = widget.isPaused;
    _currentCpu = _localIsPaused ? 0.0 : widget.initialCpu;
    _currentRam = _localIsPaused ? 0.0 : widget.initialRam;
    _ramScale = max(1024.0, _currentRam * 1.5);

    _cpuPoints = List.generate(
        7,
        (i) => _localIsPaused
            ? 0.0
            : max(0.01, (_currentCpu / 100) + (_random.nextDouble() - 0.5) * 0.1));
    _ramPoints = List.generate(
        7,
        (i) => _localIsPaused
            ? 0.0
            : max(0.01, (_currentRam / _ramScale) + (_random.nextDouble() - 0.5) * 0.1));
    
    _startLiveMetrics();
  }

  void _startLiveMetrics() {
    if (_localIsPaused) return; // Don't animate if paused
    _metricsTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted || _localIsPaused) return;
      setState(() {
        _cpuPoints.removeAt(0);
        final nextCpu = max(0.01, min(1.0, _cpuPoints.last + (_random.nextDouble() - 0.5) * 0.1));
        _cpuPoints.add(nextCpu);
        _currentCpu = nextCpu * 100;
        
        _ramPoints.removeAt(0);
        final nextRam = max(0.01, min(1.0, _ramPoints.last + (_random.nextDouble() - 0.5) * 0.05));
        _ramPoints.add(nextRam);
        _currentRam = nextRam * _ramScale;
        
        _ioPoints.removeAt(0);
        final nextIo = max(0.01, min(1.0, _ioPoints.last + (_random.nextDouble() - 0.5) * 0.2));
        _ioPoints.add(nextIo);
        _currentIo = nextIo * 20;
      });
    });
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    super.dispose();
  }

  Future<void> _showConfirmationBottomSheet({
    required String title,
    required String description,
    required String actionLabel,
    required Color actionColor,
    required Future<void> Function() onConfirm,
  }) async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: AppTheme.secondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SupaButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                child: Text(actionLabel),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppTheme.secondary)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSecureAction(
      String actionName, Future<void> Function() action) async {
    if (widget.isDemoMode) {
      _showBridgeToCommitment();
      return;
    }
    // Actions now execute directly after user confirmation.
    try {
      await action();
      if (mounted) {
        _showNotification('$actionName successful', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showNotification('$actionName failed', isError: true);
      }
    }
  }

  void _showBridgeToCommitment() {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: AppTheme.accent, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'REAL-TIME CONTROL IS LOCKED',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connecting your own stack unlocks full management capabilities including restarts, pauses, and AI-driven repairs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.secondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 32),
            SupaButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => LoginScreen()));
              },
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              child: const Center(
                  child: Text('CONNECT MY INFRASTRUCTURE',
                      style: TextStyle(fontWeight: FontWeight.w900))),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BACK TO BROWSER',
                  style: TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotification(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(widget.projectName,
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(fontSize: 20)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
      body: Hero(
        tag: 'project_${widget.projectName}',
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('METRICS & HEALTH'),
              const SizedBox(height: 12),
              _buildStatusBadge(),
              const SizedBox(height: 16),
              _buildChartSection(),
              const SizedBox(height: 32),
              _buildSectionHeader('INFRASTRUCTURE CONTROL'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Restart DB',
                      icon: Icons.refresh_rounded,
                      color: Colors.orangeAccent,
                      isLoading: _isRestarting,
                      onPressed: () => _showConfirmationBottomSheet(
                        title: 'Critical: Restart Database',
                        description:
                            'Are you sure you want to restart the database? This will disconnect all active sessions.',
                        actionLabel: 'Confirm Restart',
                        actionColor: Colors.orangeAccent,
                        onConfirm: () async {
                          HapticFeedback.heavyImpact();
                          await _handleSecureAction('Restart', () async {
                            setState(() => _isRestarting = true);
                            final success = await _authService.restartDatabase(widget.projectRef);
                            setState(() => _isRestarting = false);
                            if (success) {
                              _showNotification('Database restarted successfully', isError: false);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  if (_localIsPaused) ...[
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildActionButton(
                        label: 'Restore Project',
                        icon: Icons.settings_backup_restore_rounded,
                        color: AppTheme.accent,
                        isLoading: _isTogglingStatus,
                        onPressed: () => _showConfirmationBottomSheet(
                          title: 'Restore Infrastructure',
                          description: 'Restoring the project will spin up compute services. This usually takes 1–2 minutes.',
                          actionLabel: 'Restore Now',
                          actionColor: AppTheme.accent,
                          onConfirm: () => _handleSecureAction('Restore', () async {
                            setState(() => _isTogglingStatus = true);
                            HapticFeedback.mediumImpact();
                            bool success = await _authService.restoreProject(widget.projectRef);
                            setState(() {
                              _isTogglingStatus = false;
                              if (success) {
                                _localIsPaused = false;
                                _showNotification('Project restoration initiated successfully', isError: false);
                              } else {
                                _showNotification('Failed to restore project. You may have reached the 2 active projects limit on your free plan.', isError: true);
                              }
                            });
                          }),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildActionButton(
                        label: 'Pause Project',
                        icon: Icons.pause_circle_outline_rounded,
                        color: Colors.orangeAccent,
                        isLoading: _isTogglingStatus,
                        onPressed: () => _showConfirmationBottomSheet(
                          title: 'Pause Infrastructure',
                          description: 'Pausing the project will spin down compute services. Your data remains safe, but the API and DB will go offline.',
                          actionLabel: 'Pause Now',
                          actionColor: Colors.orangeAccent,
                          onConfirm: () => _handleSecureAction('Pause', () async {
                            setState(() => _isTogglingStatus = true);
                            HapticFeedback.mediumImpact();
                            bool success = await _authService.pauseProject(widget.projectRef);
                            setState(() {
                              _isTogglingStatus = false;
                              if (success) {
                                _localIsPaused = true;
                                _showNotification('Project pause initiated successfully', isError: false);
                              } else {
                                _showNotification('Failed to pause project. Please try again later.', isError: true);
                              }
                            });
                          }),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionHeader('DATABASE TOOLS'),
              const SizedBox(height: 12),
              _buildQuickAccessTile(
                label: 'Data Pulse',
                subtitle: 'Deep discovery and table management',
                icon: Icons.table_chart_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TableBrowserScreen()),
                  );
                },
              ),
              _buildQuickAccessTile(
                label: 'Pulse Terminal',
                subtitle: 'Direct SQL command access',
                icon: Icons.terminal_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SqlSnippetsScreen()),
                  );
                },
              ),
              _buildQuickAccessTile(
                label: 'Pulse Architect',
                subtitle: 'Authority blueprint engine',
                icon: Icons.auto_awesome_rounded,
                onTap: () {
                  if (widget.isDemoMode) {
                    _showBridgeToCommitment();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ArchitectScreen(projectRef: widget.projectRef)),
                    );
                  }
                },
              ),
              _buildQuickAccessTile(
                label: 'User Management',
                subtitle: 'Auth policies and user list',
                icon: Icons.people_alt_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => UserManagementScreen(
                            projectRef: widget.projectRef,
                            projectName: widget.projectName)),
                  );
                },
              ),
              _buildQuickAccessTile(
                label: 'Unified Log Explorer',
                subtitle: 'Real-time database, api, auth & function traces',
                icon: Icons.history_toggle_off_rounded,
                onTap: () {
                  if (!_isPro) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
                    ).then((_) => _fetchUserProfile());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edge Function Logs & Secrets are a Vectrax Pro feature! 💎'),
                        backgroundColor: AppTheme.accent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            LogsScreen(projectName: widget.projectName, projectRef: widget.projectRef)),
                  );
                },
              ),
              _buildQuickAccessTile(
                label: 'API Settings',
                subtitle: 'Project URL and Keys',
                icon: Icons.api_rounded,
                onTap: _showApiSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppTheme.secondary.withOpacity(0.5),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildChartSection() {
    return Column(
      children: [
        _buildMetricChart(
          'Active Connections',
          _localIsPaused ? '0 / 60' : '${(3 + (_currentCpu / 8)).toStringAsFixed(0)} / 60',
          _cpuPoints,
          AppTheme.accent,
        ),
        const SizedBox(height: 12),
        _buildMetricChart(
          'Read/Write Latency',
          _localIsPaused ? '0.0 ms' : '${(1.5 + (_currentRam / 150)).toStringAsFixed(1)} ms',
          _ramPoints,
          Colors.blueAccent,
        ),
        const SizedBox(height: 12),
        _buildMetricChart(
          'Queries Per Second (QPS)',
          _localIsPaused ? '0.0 QPS' : '${_currentIo.toStringAsFixed(1)} QPS',
          _ioPoints,
          Colors.orangeAccent,
        ),
      ],
    );
  }

  Widget _buildMetricChart(
      String label, String value, List<double> points, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(value,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            width: double.infinity,
            child: CustomPaint(
              painter: SparklinePainter(points, color),
            ).animate(onPlay: (c) => c.repeat()).shimmer(
                duration: 2.seconds, blendMode: BlendMode.srcATop),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SupaButton(
      isLoading: isLoading,
      onPressed: onPressed,
      backgroundColor: color.withOpacity(0.05),
      foregroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final statusColor = _localIsPaused ? AppTheme.error : AppTheme.accent;
    final statusText = _localIsPaused ? 'PAUSED' : 'RESUMED';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat())
           .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1.seconds)
           .fadeOut(duration: 1.seconds),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1, end: 0);
  }

  Widget _buildQuickAccessTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        tileColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Icon(icon, color: AppTheme.accent, size: 20),
        ),
        title: Text(label,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: Icon(Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.2)),
      ),
    );
  }
  void _showApiSettings() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('API INFRASTRUCTURE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white24),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildApiField('Project URL',
                'https://${widget.projectRef}.supabase.co', AppTheme.accent),
            const SizedBox(height: 24),
            _buildApiField('Anon Pub Key',
                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...', AppTheme.secondary),
            const SizedBox(height: 24),
            _buildApiField('Service Role Key',
                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... (Hidden)', AppTheme.error),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: SupaButton(
                onPressed: () => Navigator.pop(context),
                backgroundColor: Colors.white.withOpacity(0.05),
                foregroundColor: Colors.white,
                child: const Text('DISMISS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiField(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
              color: color.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: value));
                  _showNotification('Copied to clipboard', isError: false);
                },
                child: Icon(Icons.copy_rounded, color: color, size: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  Color get sparklineColor => color;

  SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
    );

    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = gradient
              .createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
