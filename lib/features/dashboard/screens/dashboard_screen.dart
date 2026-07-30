import 'dart:async';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/glass_card.dart';
import 'package:supa_app/core/widgets/skeleton_loader.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supa_app/features/dashboard/screens/cpu_details_screen.dart';
import 'package:supa_app/features/project/screens/project_detail_screen.dart';
import 'package:supa_app/features/settings/screens/settings_screen.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/core/services/project_context.dart';
import 'package:supa_app/core/services/notification_service.dart';
import 'package:supa_app/features/auth/screens/login_screen.dart';
import 'package:supa_app/features/premium/screens/pulse_premium_screen.dart';
import 'package:supa_app/features/feedback/screens/feedback_screen.dart' as sup;
import 'package:supa_app/core/widgets/project_slots_dialog.dart';
import 'package:supa_app/core/widgets/supa_button.dart';

class DashboardScreen extends StatefulWidget {
  final bool isDemoMode;
  const DashboardScreen({super.key, this.isDemoMode = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _projects = [];
  List<dynamic> _organizations = [];
  String? _selectedOrgId;
  String? _errorMessage;
  Map<String, dynamic> _userProfile = {'email': null, 'name': null};

  Timer? _telemetryTimer;
  double _currentCpu = 15.4;
  double _currentMemory = 1.2;
  bool _isPro = false;
  final Random _random = Random();
  final List<String> _terminalLogs = [
    '[SYS] Pulse Kernel initialization...',
    '[AUTH] Management Session secure.',
    '[NET] Monitoring 12 edge nodes.',
  ];
  final DateTime _bootTime =
      DateTime.now().subtract(const Duration(days: 12, hours: 4, minutes: 28));

  // Track metrics per project for live movement
  final Map<String, Map<String, double>> _projectMetrics = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserProfile();
    _startTelemetry();
  }

  void _startTelemetry() {
    _telemetryTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted) return;
      setState(() {
        final cpuChange =
            (_random.nextDouble() - 0.5) * 6; // Fluctuate by +/- 3%
        _currentCpu = (_currentCpu + cpuChange).clamp(2.0, 98.0);

        final memChange =
            (_random.nextDouble() - 0.5) * 0.2; // Fluctuate by +/- 0.1GB
        _currentMemory = (_currentMemory + memChange).clamp(0.5, 4.0);

        // Update individual project metrics
        for (final project in _projects) {
          final id = project['id'];
          final status = project['status']?.toString().toUpperCase() ?? '';
          final isActive = status == 'ACTIVE' || status == 'ACTIVE_HEALTHY' || status == 'COMING_UP';

          if (!isActive) {
            _projectMetrics[id] = {'cpu': 0.0, 'ram': 0.0};
            continue;
          }
          if (!_projectMetrics.containsKey(id)) {
            _projectMetrics[id] = {
              'cpu': 4.0 + _random.nextInt(4),
              'ram': 22.4 + _random.nextDouble() * 1.5,
            };
          } else {
            final oldCpu = _projectMetrics[id]!['cpu']!;
            final oldRam = _projectMetrics[id]!['ram']!;
            _projectMetrics[id]!['cpu'] =
                (oldCpu + (_random.nextInt(3) - 1)).clamp(3.0, 15.0);
            _projectMetrics[id]!['ram'] =
                (oldRam + (_random.nextDouble() * 0.02)).clamp(15.0, 100.0);
          }
        }

        // Add random terminal logs
        if (_random.nextDouble() > 0.7) {
          final logs = [
            '[IO] Disk write: ${(_random.nextDouble() * 20).toStringAsFixed(1)}MB/s',
            '[NET] Ping Supabase API: ${(_random.nextInt(30) + 15)}ms',
            '[SYS] Load balancing active',
            '[SQL] Connection pool synced',
          ];
          _terminalLogs.insert(0, logs[_random.nextInt(logs.length)]);
          if (_terminalLogs.length > 20) _terminalLogs.removeLast();
        }
      });
    });
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final profile = await AuthService().getUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isPro = profile['isPremium'] ?? false;
      });
    }
  }

  void _checkProjectAlerts() {
    // Check all projects and show notifications globally
    Future.delayed(2.seconds, () {
      if (mounted && _projects.isNotEmpty) {
        for (final project in _projects) {
          final isPaused = project['status'] == 'PAUSED';
          if (isPaused) {
            NotificationService().showNotification(
              title: '⏸️ PROJECT PAUSED',
              body:
                  'Your project "${project['name']}" is paused. Restore it now.',
              payload: project['id'],
            );
          }
        }
      }
    });
  }

  void _loadData() async {
    if (_projects.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    if (widget.isDemoMode) {
      setState(() {
        _projects = [
          {
            'id': 'demo-proj-1',
            'name': 'VECTRAX_DEMO',
            'status': 'ACTIVE_HEALTHY',
            'organization_id': 'demo-org-1',
          },
          {
            'id': 'demo-proj-2',
            'name': 'NEURAL_BRIDGE_v1',
            'status': 'ACTIVE',
            'organization_id': 'demo-org-1',
          },
        ];
        _organizations = [
          {'id': 'demo-org-1', 'name': 'DEMO_CORP'}
        ];
        _selectedOrgId = 'demo-org-1';
        _isLoading = false;
      });
      return;
    }

    try {
      final results = await Future.wait([
        _apiService.listProjects(),
        _apiService.listOrganizations(),
      ]);

      if (mounted) {
        setState(() {
          _projects = results[0];
          // Sort active/healthy projects to the top
          _projects.sort((a, b) {
            final aIsActive =
                (a['status'] == 'ACTIVE_HEALTHY' || a['status'] == 'ACTIVE')
                    ? 0
                    : 1;
            final bIsActive =
                (b['status'] == 'ACTIVE_HEALTHY' || b['status'] == 'ACTIVE')
                    ? 0
                    : 1;
            if (aIsActive != bIsActive) return aIsActive.compareTo(bIsActive);
            return (a['name'] ?? '').compareTo(b['name'] ?? '');
          });

          _organizations = results[1];
          if (_organizations.isNotEmpty && _selectedOrgId == null) {
            _selectedOrgId = _organizations.first['id'];
          }
          _isLoading = false;
        });
        ProjectContext().seedMonitoredProjects(_projects);
        _checkProjectAlerts();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load cloud data';
        });
      }
    }
  }

  void _showFabMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: AppTheme.accent),
              ),
              title: const Text('New Project',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Deploy a new Supabase database',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon!')));
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: AppTheme.secondary),
              ),
              title: const Text('Invite Member',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Add a collaborator to your organization',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon!')));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title:
            const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Switch to a different connection method?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch Method',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 40),
            color: AppTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.business_rounded,
                  color: AppTheme.accent, size: 20),
            ),
            onSelected: (value) {
              HapticFeedback.mediumImpact();
              if (value == 'add') {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Container(
                    padding: const EdgeInsets.all(32),
                    decoration: const BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(top: BorderSide(color: Colors.white12)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 24),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'MULTI-ACCOUNT SYNC',
                          style: GoogleFonts.inter(
                            color: Colors.white24,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'All organizations connected to your current Supabase account are already automatically loaded. If you want to connect a different Supabase user account, please unlink your current account under settings first.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SupaButton(
                          onPressed: () => Navigator.pop(ctx),
                          backgroundColor: Colors.white.withOpacity(0.06),
                          foregroundColor: Colors.white,
                          child: const Center(
                            child: Text('UNDERSTOOD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              ..._organizations.map((org) => PopupMenuItem(
                    value: org['id'],
                    child: Row(
                      children: [
                        const Icon(Icons.rocket_launch_rounded,
                            size: 18, color: AppTheme.accent),
                        const SizedBox(width: 12),
                        Text(org['name'] ?? 'Unknown Org',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  )),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: Colors.white54),
                    SizedBox(width: 12),
                    Text('Add Organization',
                        style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VECTRAX',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'ELITE CONTROL',
              style: TextStyle(
                color: AppTheme.accent.withOpacity(0.8),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const sup.FeedbackScreen()),
              );
            },
            icon: const Icon(Icons.bug_report_rounded,
                color: Colors.white54, size: 20),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadUserProfile();
            },
            icon: _buildPremiumAvatar(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: const [
                SkeletonBentoCard(isLarge: true),
                SkeletonBentoCard(),
                SkeletonBentoCard(),
                SkeletonBentoCard(),
              ],
            )
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                _loadData();
                await Future.delayed(const Duration(milliseconds: 1500));
              },
              backgroundColor: AppTheme.surface,
              color: AppTheme.accent,
              displacement: 20,
              strokeWidth: 3,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    if (widget.isDemoMode) ...[
                      SliverToBoxAdapter(child: _buildConnectBanner(context)),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                    SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.0,
                      ),
                      delegate: SliverChildListDelegate([
                        // Large Card: CPU Usage (Primary Focus) with Hero Chart
                        _buildCpuHeroCard(context),
                        // Medium Card: RAM
                        _buildBentoCard(
                          context,
                          title: 'MEMORY',
                          value: '${_currentMemory.toStringAsFixed(1)}GB',
                          subtitle: 'Healthy',
                          icon: Icons.memory_rounded,
                          isLarge: false,
                          color: Colors.deepPurpleAccent,
                        ),
                        // Medium Card: Nodes
                        _buildBentoCard(
                          context,
                          title: 'NODES',
                          value: '${_projects.length} Items',
                          subtitle: 'Active',
                          icon: Icons.hub_rounded,
                          isLarge: false,
                          color: Colors.cyanAccent,
                        ),
                      ]),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.2,
                      ),
                      delegate: SliverChildListDelegate([
                        // Small Cards: Regions/Status
                        _buildSmallBentoCard(context, 'REGION',
                            _getReadableRegion(ProjectContext().currentProject?['region']),
                            Icons.public_rounded),
                        _buildSmallBentoCard(context, 'STATUS', 'Running',
                            Icons.check_circle_rounded,
                            color: AppTheme.terminalGreen),
                        _buildSmallBentoCard(
                          context,
                          'UPTIME',
                          _calculateUptime(),
                          Icons.timer_rounded,
                          color: AppTheme.warning,
                        ),
                      ]),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    const SliverToBoxAdapter(
                      child: Text(
                        'PROJECTS',
                        style: TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final project = _projects[index];
                          final id = project['id'] ?? '';
                          final metrics =
                              _projectMetrics[id] ?? {'cpu': 0.0, 'ram': 0.0};
                          final status = project['status'] ?? 'UNKNOWN';
                          final isActive =
                              status == 'ACTIVE_HEALTHY' || status == 'ACTIVE';
                          final isLocked = !_isPro && !ProjectContext().isProjectMonitored(id);
                          final isPausedActual = !isActive || status == 'PAUSED';
                          return _buildProjectCard(
                            context,
                            name: project['name'] ?? 'Untitled',
                            ref: id,
                            status: status,
                            cpu: isPausedActual ? '0' : '${metrics['cpu']!.toStringAsFixed(0)} / 60',
                            ram: isPausedActual ? '0.0 MB' : '${metrics['ram']!.toStringAsFixed(1)} MB',
                            rawCpu: isPausedActual ? 0.0 : metrics['cpu']!,
                            rawRam: isPausedActual ? 0.0 : metrics['ram']!,
                            nodeCount: 1,
                            isPaused: isPausedActual,
                            isLocked: isLocked,
                          );
                        },
                        childCount: _projects.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}

  String _calculateUptime() {
    final difference = DateTime.now().difference(_bootTime);
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    return '${days}d ${hours}h';
  }

  String _getReadableRegion(String? code) {
    if (code == null) return 'Global';
    final clean = code.toLowerCase().trim();
    if (clean.contains('ap-southeast-1') || clean.contains('singapore')) return 'Singapore';
    if (clean.contains('ap-southeast-2') || clean.contains('sydney')) return 'Sydney';
    if (clean.contains('ap-northeast-1') || clean.contains('tokyo')) return 'Tokyo';
    if (clean.contains('ap-northeast-2') || clean.contains('seoul')) return 'Seoul';
    if (clean.contains('us-east-1') || clean.contains('virginia')) return 'US East';
    if (clean.contains('us-east-2') || clean.contains('ohio')) return 'Ohio';
    if (clean.contains('us-west-1') || clean.contains('california')) return 'US West';
    if (clean.contains('us-west-2') || clean.contains('oregon')) return 'Oregon';
    if (clean.contains('eu-west-1') || clean.contains('ireland')) return 'Ireland';
    if (clean.contains('eu-central-1') || clean.contains('frankfurt')) return 'Frankfurt';
    if (clean.contains('eu-west-2') || clean.contains('london')) return 'London';
    if (clean.contains('sa-east-1') || clean.contains('sao-paulo')) return 'São Paulo';
    return code.toUpperCase();
  }

  Widget _buildConnectBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.bolt_rounded,
                color: AppTheme.accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to scale?',
                  style: GoogleFonts.outfit(
                    color: AppTheme.accent.withOpacity(0.95),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  'Connect your real Supabase stack for live insight.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _handleLogout(context),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'CONNECT',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildCpuHeroCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CpuDetailsScreen()));
      },
      child: Hero(
        tag: 'cpu_metric_hero',
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Subtle background Sparkline
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.25,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 12),
                              FlSpot(1, 15),
                              FlSpot(2, 14),
                              FlSpot(3, 18),
                              FlSpot(4, 15),
                              FlSpot(5, 17),
                              FlSpot(6, 15.4),
                            ],
                            isCurved: true,
                            color: AppTheme.accent,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accent.withOpacity(0.5),
                                  AppTheme.accent.withOpacity(0.0)
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Foreground content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.speed_rounded,
                                  color: AppTheme.accent, size: 16),
                            ),
                            const Icon(Icons.show_chart_rounded,
                                color: AppTheme.secondary, size: 16),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'CPU USAGE',
                          style: GoogleFonts.jetBrainsMono(
                            color: AppTheme.secondary.withOpacity(0.5),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_currentCpu.toStringAsFixed(1)}%',
                          style: GoogleFonts.jetBrainsMono(
                            color: AppTheme.accent,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'MANAGED NODES',
                          style: GoogleFonts.inter(
                            color: AppTheme.secondary.withOpacity(0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0);
  }


  Widget _buildBentoCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    bool isLarge = false,
    Color? color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (color ?? AppTheme.secondary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color ?? AppTheme.secondary, size: 14),
              ),
              if (isLarge)
                const Icon(Icons.show_chart_rounded,
                    color: AppTheme.accent, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              color: AppTheme.secondary.withOpacity(0.5),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: color ?? Colors.white,
              fontSize: isLarge ? 24 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppTheme.secondary.withOpacity(0.4),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSmallBentoCard(
      BuildContext context, String label, String value, IconData icon,
      {Color? color}) {
    return GlassCard(
      padding: const EdgeInsets.all(10),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color ?? AppTheme.secondary.withOpacity(0.5), size: 12),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
                fontSize: 7,
                color: AppTheme.secondary.withOpacity(0.4),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildProjectCard(
    BuildContext context, {
    required String name,
    required String ref,
    required String status,
    required String cpu,
    required String ram,
    required double rawCpu,
    required double rawRam,
    required int nodeCount,
    required bool isPaused,
    bool isLocked = false,
    bool hasAlert = false,
  }) {
    final isActive = status == 'ACTIVE_HEALTHY' || status == 'ACTIVE';
    final statusColor = hasAlert
        ? AppTheme.error
        : isPaused
            ? AppTheme.secondary
            : isActive
                ? AppTheme.terminalGreen
                : Colors.yellowAccent;

    return Hero(
      tag: 'project_$ref',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (isActive && !isPaused)
                BoxShadow(
                  color: statusColor.withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: GlassCard(
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                final isMonitored = ProjectContext().isProjectMonitored(ref);
                final isLocked = !_isPro && !isMonitored;
                if (isLocked) {
                  ProjectSlotsDialog.show(
                    context,
                    allProjects: _projects,
                    targetProject: {
                      'name': name,
                      'id': ref,
                      'ref': ref,
                      'status': status,
                    },
                    onSwapped: () {
                      setState(() {});
                    },
                  );
                  return;
                }
                ProjectContext().selectProject({
                  'name': name,
                  'id': ref,
                  'ref': ref,
                  'status': status,
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(
                        projectName: name, projectRef: ref, isPaused: isPaused, initialCpu: rawCpu, initialRam: rawRam),
                  ),
                ).then((_) {
                  _loadData();
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildPulseIndicator(isActive, isPaused, statusColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16, // Slightly smaller
                                    fontWeight: FontWeight.w900, // Bolder
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_outline_rounded, color: Colors.white60, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'LOCKED',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white60,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isActive && !isPaused)
                          _buildPingButton(context, ref, name)
                        else if (isPaused)
                          _buildRestoreButton(context, ref, name),
                      ],
                    ),
                    const SizedBox(height: 12), // Reduced spacing
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildTechnicalMetric('CONNECTIONS', cpu, hasAlert),
                            const SizedBox(width: 24),
                            _buildTechnicalMetric('DATABASE SIZE', ram, false),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.hub_rounded, color: AppTheme.secondary, size: 10),
                            const SizedBox(width: 6),
                            Text(
                              status.replaceFirst('ACTIVE_', '').toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRestoreButton(BuildContext context, String ref, String name) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.heavyImpact();
        final success = await AuthService().restoreProject(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? 'Restore initiated for $name! 🏗️'
                  : 'Failed to restore $name. Check settings.'),
              backgroundColor: success ? AppTheme.accent : AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
        ),
        child: const Text('RESTORE',
            style: TextStyle(
                color: AppTheme.error,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPulseIndicator(bool isActive, bool isPaused, Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          if (isActive && !isPaused)
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
    )
        .animate(
          target: (isActive && !isPaused) ? 1 : 0,
          onPlay: (controller) => controller.repeat(),
        )
        .scale(
          duration: 1.5.seconds,
          begin: const Offset(1, 1),
          end: const Offset(1.3, 1.3),
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          duration: 1.5.seconds,
          begin: const Offset(1.3, 1.3),
          end: const Offset(1, 1),
          curve: Curves.easeInOut,
        );
  }

  Widget _buildPingButton(BuildContext context, String ref, String name) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();

        NotificationService().showNotification(
          title: '💎 PROJECT SECURED',
          body: 'You successfully pinged $name. Idle timer reset!',
        );

        final success = await _apiService.pingProject(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppTheme.accent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ping successful! Supabase inactivity timer reset. ⚡',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.accent, AppTheme.accent.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.bolt_rounded, color: AppTheme.background, size: 16),
            SizedBox(width: 6),
            Text(
              'PING',
              style: TextStyle(
                color: AppTheme.background,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1, 1),
        curve: Curves.elasticOut);
  }

  Widget _buildTechnicalMetric(String label, String value, bool isCritical,
      {bool isStatus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: AppTheme.secondary.withOpacity(0.5),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: isCritical
                ? AppTheme.error
                : (isStatus ? AppTheme.terminalGreen : Colors.white),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumAvatar(BuildContext context) {
    final avatarUrl = _userProfile['avatarUrl'];
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(avatarUrl),
          backgroundColor: AppTheme.surface,
        ),
      );
    }

    final name = _userProfile['name'] ?? '';
    final email = _userProfile['email'] ?? '';
    final hasName = name.isNotEmpty && name != 'Vectrax User';

    String initial = 'Z';
    if (hasName) {
      initial = name.substring(0, 1).toUpperCase();
    } else if (email.isNotEmpty) {
      initial = email.substring(0, 1).toUpperCase();
    } else if (name.isNotEmpty) {
      initial = name.substring(0, 1).toUpperCase();
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AppTheme.surface,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [AppTheme.accent, Colors.blueAccent, AppTheme.accent],
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              color: AppTheme.background,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
