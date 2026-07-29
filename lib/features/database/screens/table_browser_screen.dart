import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/empty_state.dart';
import 'package:supa_app/core/widgets/skeleton_loader.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/core/services/project_context.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supa_app/core/widgets/project_selection_required.dart';
import 'package:supa_app/core/widgets/vibe_widgets.dart';
import 'package:supa_app/features/database/screens/data_view_screen.dart';
import 'package:supa_app/features/storage/screens/bucket_view_screen.dart';
import 'package:supa_app/core/widgets/project_slots_dialog.dart';
import 'package:supa_app/features/premium/screens/pulse_premium_screen.dart';
import 'package:supa_app/features/project/screens/logs_screen.dart';

class TableBrowserScreen extends StatefulWidget {
  final bool isDemoMode;
  const TableBrowserScreen({super.key, this.isDemoMode = false});

  @override
  State<TableBrowserScreen> createState() => _TableBrowserScreenState();
}

class _TableBrowserScreenState extends State<TableBrowserScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ProjectContext _projectContext = ProjectContext();
  final ApiService _apiService = ApiService();

  String _searchQuery = '';
  int? _expandedIndex = null;
  bool _isLoading = true;
  bool _isProjectSwitching = false; // for premium project-switch animation
  List<dynamic> _projects = [];
  List<dynamic> _resources = [];
  String _activeTab = 'TABLES';
  final _random = Random();
  Timer? _telemetryTimer;
  final Map<String, Map<String, double>> _projectMetrics = {};
  bool _isPro = false;

  // Real health data
  Map<String, dynamic> _healthData = {};
  bool _isHealthLoading = false;

  late AnimationController _logoController;
  late AnimationController _glowController;
  late Animation<double> _logoScale;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut);
    _glowOpacity = Tween<double>(begin: 0.2, end: 0.6).animate(_glowController);

    _projectContext.addListener(_onProjectContextChanged);
    _startTelemetry();
    _loadUserProfile();
    _loadData();
  }

  Future<void> _loadUserProfile() async {
    final profile = await AuthService().getUserProfile();
    if (mounted) {
      setState(() {
        _isPro = profile['isPremium'] ?? false;
      });
    }
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _logoController.dispose();
    _glowController.dispose();
    _projectContext.removeListener(_onProjectContextChanged);
    super.dispose();
  }

  void _onProjectContextChanged() {
    if (mounted) {
      // Show premium project-switching animation
      setState(() {
        _isProjectSwitching = true;
        _expandedIndex = null;
      });
      _logoController.forward(from: 0);
      _loadData().then((_) {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) setState(() => _isProjectSwitching = false);
          });
        }
      });
    }
  }

  void _startTelemetry() {
    _telemetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        for (final project in _projects) {
          final id = project['id'];
          final status = (project['status'] ?? '').toString().toUpperCase();
          final isActive =
              status == 'ACTIVE' || status == 'ACTIVE_HEALTHY' || status == 'COMING_UP';
          if (id == null) continue;
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
      });
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_projects.isEmpty) {
        if (widget.isDemoMode) {
          _projects = [
            {'id': 'demo-proj-1', 'name': 'VECTRAX_DEMO', 'status': 'ACTIVE_HEALTHY'},
            {'id': 'demo-proj-2', 'name': 'NEURAL_BRIDGE_v1', 'status': 'ACTIVE'},
          ];
        } else {
          _projects = await _apiService.listProjects();
        }
      }

      _projects.sort((a, b) {
        final statusA = (a['status'] ?? '').toString().toUpperCase();
        final statusB = (b['status'] ?? '').toString().toUpperCase();
        final aIsActive = (statusA == 'ACTIVE' || statusA == 'ACTIVE_HEALTHY') ? 0 : 1;
        final bIsActive = (statusB == 'ACTIVE' || statusB == 'ACTIVE_HEALTHY') ? 0 : 1;
        if (aIsActive != bIsActive) return aIsActive.compareTo(bIsActive);
        return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      });

      // Auto-select first monitored project by default if none selected or if current selection is locked
      final currentProjId = _projectContext.currentProject?['id'] ?? _projectContext.currentProject?['ref'];
      final isCurrentLocked = !_isPro && currentProjId != null && !ProjectContext().isProjectMonitored(currentProjId.toString());

      if ((_projectContext.currentProject == null || isCurrentLocked) && _projects.isNotEmpty) {
        final defaultProj = _projects.firstWhere(
          (p) {
            final id = (p['id'] ?? p['ref'])?.toString();
            final isMonitored = ProjectContext().isProjectMonitored(id);
            final status = (p['status'] ?? '').toString().toUpperCase();
            return (status == 'ACTIVE' || status == 'ACTIVE_HEALTHY') && isMonitored;
          },
          orElse: () => _projects.firstWhere(
            (p) => ProjectContext().isProjectMonitored((p['id'] ?? p['ref'])?.toString()),
            orElse: () => _projects.first,
          ),
        );
        _projectContext.selectProject(defaultProj);
        return; // selectProject triggers listener which re-calls _loadData
      }

      final ref = _projectContext.currentProject?['ref'] ?? _projectContext.currentProject?['id'];
      if (ref != null) {
        if (_activeTab == 'TABLES') {
          _resources = await _apiService.listTables(ref);
        } else if (_activeTab == 'FUNCTIONS') {
          _resources = await _apiService.listFunctions(ref);
        } else if (_activeTab == 'STORAGE') {
          _resources = await _apiService.listBuckets(ref);
        } else if (_activeTab == 'HEALTH') {
          await _loadHealthData(ref);
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHealthData(String ref) async {
    if (mounted) setState(() => _isHealthLoading = true);
    try {
      // Fetch real health data via SQL queries on the project's own DB
      final rlsResult = await _apiService.executeSql(ref,
          "SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';");
      final statsResult = await _apiService.executeSql(ref,
          "SELECT relname, n_dead_tup, n_live_tup, seq_scan, idx_scan FROM pg_stat_user_tables;");
      final unusedIdxResult = await _apiService.executeSql(ref,
          "SELECT count(*) as cnt FROM pg_stat_user_indexes WHERE idx_scan = 0 AND schemaname = 'public';");
      final dbSizeResult = await _apiService.executeSql(ref,
          "SELECT pg_size_pretty(pg_database_size(current_database())) as size;");

      // Compute health score
      int tablesWithoutRls = 0;
      int totalTables = 0;
      if (rlsResult is List) {
        totalTables = rlsResult.length;
        for (final row in rlsResult) {
          if (row['rowsecurity'] == false) tablesWithoutRls++;
        }
      }

      int totalBloat = 0;
      int tablesWithBloat = 0;
      if (statsResult is List) {
        for (final row in statsResult) {
          final dead = (row['n_dead_tup'] ?? 0) as int;
          final live = (row['n_live_tup'] ?? 0) as int;
          totalBloat += dead;
          if (dead > live * 0.3 && dead > 50) tablesWithBloat++;
        }
      }

      int unusedIndexes = 0;
      if (unusedIdxResult is List && unusedIdxResult.isNotEmpty) {
        unusedIndexes = int.tryParse(unusedIdxResult.first['cnt'].toString()) ?? 0;
      }

      String dbSize = '—';
      if (dbSizeResult is List && dbSizeResult.isNotEmpty) {
        dbSize = dbSizeResult.first['size']?.toString() ?? '—';
      }

      // Score calculation
      int score = 100;
      score -= tablesWithoutRls * 10;
      score -= tablesWithBloat * 8;
      score -= (unusedIndexes > 5 ? 10 : unusedIndexes * 2);
      score = score.clamp(0, 100);

      if (mounted) {
        setState(() {
          _healthData = {
            'score': score,
            'tablesWithoutRls': tablesWithoutRls,
            'totalTables': totalTables,
            'tablesWithBloat': tablesWithBloat,
            'unusedIndexes': unusedIndexes,
            'dbSize': dbSize,
            'totalBloat': totalBloat,
          };
          _isHealthLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Health] ❌ $e');
      if (mounted) setState(() => _isHealthLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _resources
        .where((item) => (item['name'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // dismiss keyboard on blank tap
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VECTRAX DATA',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.accent, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppTheme.accent, blurRadius: 4)],
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .scale(
                        begin: const Offset(1, 1), end: const Offset(1.4, 1.4),
                        duration: 800.ms, curve: Curves.easeInOut,
                      )
                      .fadeOut(duration: 800.ms),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _projectContext.currentProject?['name']?.toString().toUpperCase() ?? 'SELECT PROJECT',
                      style: TextStyle(
                        color: AppTheme.accent.withOpacity(0.8),
                        fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildProjectCarousel(),
            _buildResourceTabs(),
            _buildUpperSearch(),
            Expanded(
              child: Stack(
                children: [
                  !_projectContext.hasProject
                      ? const ProjectSelectionRequired()
                      : _buildMainContent(filteredData),
                  if (_isProjectSwitching) _buildProjectSwitchOverlay(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Premium Project Switch Overlay ────────────────────────────────────────

  Widget _buildProjectSwitchOverlay() {
    final projectName = _projectContext.currentProject?['name'] ?? '';
    return Positioned.fill(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Container(
                width: 280,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F12).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    )
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accent.withOpacity(0.2),
                          ),
                        ),
                        const SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accent,
                          ),
                        ).animate(onPlay: (c) => c.repeat()).rotate(duration: 2.seconds),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: const Icon(Icons.dns_rounded, color: AppTheme.accent, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'CONNECTING PROJECT',
                      style: GoogleFonts.outfit(
                        color: AppTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      projectName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Syncing database schema...',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildProjectCarousel() {
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final p = _projects[index];
          final isSelected = _projectContext.currentProject?['id'] == p['id'];
          final metrics = _projectMetrics[p['id']] ?? {'cpu': 1.2, 'ram': 158.0};
          
          final isLocked = !_isPro && !ProjectContext().isProjectMonitored(p['id']);
          final status = isLocked ? 'PAUSED' : (p['status'] ?? 'ACTIVE_HEALTHY');
          final isPausedActual = status == 'PAUSED';

          return MiniProjectCard(
            name: p['name'] ?? 'Unknown',
            status: status,
            isSelected: isSelected,
            onTap: () {
              if (isLocked) {
                HapticFeedback.vibrate();
                ProjectSlotsDialog.show(
                  context,
                  allProjects: _projects,
                  targetProject: p,
                  onSwapped: () {
                    setState(() {});
                  },
                );
                return;
              }
              HapticFeedback.mediumImpact();
              _projectContext.selectProject(p);
              setState(() => _expandedIndex = null);
            },
            cpu: isPausedActual ? '0' : '${metrics['cpu']!.toStringAsFixed(0)} / 60',
            ram: isPausedActual ? '0.0 MB' : '${metrics['ram']!.toStringAsFixed(1)} MB',
          );
        },
      ),
    );
  }

  Widget _buildResourceTabs() {
    final tabs = ['TABLES', 'FUNCTIONS', 'STORAGE'];
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _activeTab = tab;
                  _resources = [];
                  _loadData();
                });
              },
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.background : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? AppTheme.accent : AppTheme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainContent(List<dynamic> filteredData) {
    // Only show skeleton if we have NO data at all
    if (_isLoading && _resources.isEmpty) return _buildSkeletonLoader();
    if (_activeTab == 'HEALTH') return _buildHealthView();

    return Stack(
      children: [
        if (filteredData.isEmpty)
          EmptyState(
            icon: _getTabIcon(),
            title: 'NO $_activeTab DISCOVERED',
            description:
                'No ${_activeTab.toLowerCase()} found for ${_projectContext.currentProject?['name']?.toString() ?? 'this project'}.',
            customAction: null,
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 120),
            itemCount: filteredData.length,
            itemBuilder: (context, index) {
              final item = filteredData[index];
              return _buildResourceRow(item, index);
            },
          ),
        
        // Lower side loading indicator
        if (_isLoading && _resources.isNotEmpty)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.1),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'SYNCING Sector...',
                      style: GoogleFonts.outfit(
                        color: AppTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.5, end: 0),
          ),
      ],
    );
  }

  IconData _getTabIcon() {
    switch (_activeTab) {
      case 'FUNCTIONS': return Icons.bolt_rounded;
      case 'STORAGE': return Icons.folder_rounded;
      case 'HEALTH': return Icons.health_and_safety_rounded;
      default: return Icons.table_rows_rounded;
    }
  }

  Widget _buildResourceRow(dynamic item, int index) {
    String name = item['name'] ?? 'Unknown';
    String sub = _activeTab == 'TABLES'
        ? '${item['rows'] ?? 'SCANNING'} rows'
        : _activeTab == 'FUNCTIONS'
            ? (item['status'] ?? 'ACTIVE').toString().toUpperCase()
            : 'BUCKET';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.015),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                HapticFeedback.lightImpact();
                if (_activeTab == 'TABLES') {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => DataViewScreen(tableName: name)));
                } else if (_activeTab == 'STORAGE') {
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (context) =>
                              BucketViewScreen(bucketName: name, bucketId: item['id'] ?? name)));
                } else if (_activeTab == 'FUNCTIONS') {
                  if (!_isPro) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
                    );
                    _loadUserProfile();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edge Function Logs & Secrets are a Vectrax Pro feature! 💎'),
                          backgroundColor: AppTheme.accent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }
                  final projectRef = _projectContext.currentProject?['id'] ?? '';
                  final projectName = _projectContext.currentProject?['name'] ?? 'Project';
                  if (projectRef.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LogsScreen(
                          projectName: projectName,
                          projectRef: projectRef,
                        ),
                      ),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Icon(_getTabIcon(), color: AppTheme.accent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8, runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(sub.toUpperCase(),
                                style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5)),
                          ),
                          Text(
                            _activeTab == 'TABLES' ? 'PUBLIC SCHEMA'
                                : _activeTab == 'STORAGE' ? 'STORAGE BUCKET'
                                : 'EDGE FUNCTION',
                            style: TextStyle(
                                color: AppTheme.secondary.withOpacity(0.3),
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildActionButtons(item),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
)
        .animate()
        .fadeIn(delay: (index * 40).ms)
        .scale(begin: const Offset(1.02, 1.02), end: const Offset(1, 1));
  }

  Widget _buildActionButtons(dynamic item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'purge') _confirmDeletion(item);
          },
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white24, size: 18),
          color: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'purge',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                  SizedBox(width: 12),
                  Text('Purge Sector',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white10, size: 14),
      ],
    );
  }

  Future<void> _confirmDeletion(dynamic item) async {
    final name = item['name'] ?? 'Resource';
    final type = _activeTab.toLowerCase().substring(0, _activeTab.length - 1);
    final isTable = type == 'table';
    final actionWord = isTable ? 'DROP' : (type == 'function' ? 'UNDEPLOY' : 'DELETE');
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('$actionWord ${type.toUpperCase()}',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        content: Text(
            'Are you sure you want to permanently $actionWord the $type "$name" from the cluster? All data will be irreversibly erased.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionWord,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ref = _projectContext.currentProject?['ref'];
      if (ref != null) {
        final id = item['id'] ?? item['name'];
        final success = await _apiService.deleteResource(ref, type, id);
        if (success) {
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Resource purged successfully'),
                  backgroundColor: Colors.redAccent),
            );
          }
        }
      }
    }
  }

  // ─── Real Health View ──────────────────────────────────────────────────────

  Widget _buildHealthView() {
    if (_isHealthLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
            const SizedBox(height: 20),
            Text('Running diagnostics...',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    if (_healthData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.health_and_safety_rounded, color: Colors.white12, size: 48),
            const SizedBox(height: 16),
            Text('No health data available.\nSelect a connected project.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 13, height: 1.6)),
          ],
        ),
      );
    }

    final score = _healthData['score'] as int;
    final tablesWithoutRls = _healthData['tablesWithoutRls'] as int;
    final totalTables = _healthData['totalTables'] as int;
    final tablesWithBloat = _healthData['tablesWithBloat'] as int;
    final unusedIndexes = _healthData['unusedIndexes'] as int;
    final dbSize = _healthData['dbSize'] as String;

    final scoreColor = score >= 80
        ? AppTheme.accent
        : score >= 50
            ? Colors.orangeAccent
            : Colors.redAccent;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scoreColor.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Text(
                  '$score',
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                    height: 1,
                  ),
                ).animate().fadeIn().scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), curve: Curves.easeOutCubic),
                const SizedBox(height: 6),
                Text(
                  'HEALTH SCORE',
                  style: GoogleFonts.inter(
                    color: scoreColor.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    color: scoreColor,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  score >= 80
                      ? 'Infrastructure is healthy 🟢'
                      : score >= 50
                          ? 'Some issues need attention 🟡'
                          : 'Critical issues detected 🔴',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),

          const SizedBox(height: 24),

          // Metric grid
          Row(
            children: [
              Expanded(child: _buildMetricCard('DB SIZE', dbSize, Icons.storage_rounded, Colors.blueAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('TABLES', '$totalTables', Icons.table_rows_rounded, AppTheme.accent)),
            ],
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: _buildMetricCard('UNPROTECTED', '$tablesWithoutRls', Icons.shield_outlined,
                  tablesWithoutRls == 0 ? AppTheme.accent : Colors.redAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('BLOATED', '$tablesWithBloat', Icons.warning_amber_rounded,
                  tablesWithBloat == 0 ? AppTheme.accent : Colors.orangeAccent)),
            ],
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 24),
          Text(
            'DIAGNOSTICS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 12),

          // RLS check
          _buildRealHealthRow(
            title: tablesWithoutRls == 0
                ? 'RLS: All tables protected'
                : 'RLS: $tablesWithoutRls tables unprotected',
            desc: tablesWithoutRls == 0
                ? 'Every public table has Row-Level Security enabled.'
                : '$tablesWithoutRls table(s) are publicly accessible with no access control.',
            icon: Icons.shield_rounded,
            isOk: tablesWithoutRls == 0,
          ),

          // Bloat check
          _buildRealHealthRow(
            title: tablesWithBloat == 0
                ? 'Table Bloat: Clean'
                : 'Table Bloat: $tablesWithBloat tables need VACUUM',
            desc: tablesWithBloat == 0
                ? 'No significant dead row accumulation detected.'
                : '$tablesWithBloat table(s) have >30% dead rows. Run VACUUM ANALYZE.',
            icon: Icons.auto_delete_rounded,
            isOk: tablesWithBloat == 0,
          ),

          // Unused indexes
          _buildRealHealthRow(
            title: unusedIndexes == 0
                ? 'Indexes: All in use'
                : '$unusedIndexes unused indexes detected',
            desc: unusedIndexes == 0
                ? 'All indexes are contributing to query performance.'
                : '$unusedIndexes index(es) have 0 scans. Consider dropping them to reduce write overhead.',
            icon: Icons.speed_rounded,
            isOk: unusedIndexes == 0,
          ),

          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => _loadHealthData(
                _projectContext.currentProject?['ref'] ?? _projectContext.currentProject?['id'] ?? ''),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.accent),
            label: Text('Re-run Diagnostics',
                style: GoogleFonts.inter(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withOpacity(0.6), size: 16),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.robotoMono(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white30,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildRealHealthRow({
    required String title,
    required String desc,
    required IconData icon,
    required bool isOk,
  }) {
    final color = isOk ? AppTheme.accent : Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc,
                    style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
          Icon(
            isOk ? Icons.check_circle_rounded : Icons.error_rounded,
            color: color,
            size: 16,
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                const SkeletonLoader(
                    width: 40,
                    height: 40,
                    borderRadius: BorderRadius.all(Radius.circular(8))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonLoader(width: 120, height: 16),
                      SizedBox(height: 8),
                      SkeletonLoader(width: 80, height: 12),
                    ],
                  ),
                ),
                const SkeletonLoader(
                    width: 24,
                    height: 24,
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpperSearch() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search elements...',
          hintStyle: TextStyle(color: AppTheme.secondary.withOpacity(0.3), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.secondary, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2, end: 0);
  }
}
