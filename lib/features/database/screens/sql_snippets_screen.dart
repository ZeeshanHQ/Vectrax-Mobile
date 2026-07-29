import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/features/database/models/sql_snippet.dart';
import 'package:supa_app/features/database/providers/sql_snippets_provider.dart';
import 'package:supa_app/core/services/project_context.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/features/database/widgets/query_results_sheet.dart';
import 'package:supa_app/features/database/widgets/sql_editor.dart';
import 'package:supa_app/features/database/widgets/pulse_ai_sheet.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supa_app/core/widgets/project_selection_required.dart';
import 'package:supa_app/core/widgets/vibe_widgets.dart';
import 'package:supa_app/features/database/providers/query_history_provider.dart';
import 'package:supa_app/features/premium/screens/pulse_premium_screen.dart';
import 'package:supa_app/core/widgets/project_slots_dialog.dart';

class SqlSnippetsScreen extends ConsumerStatefulWidget {
  final bool isDemoMode;
  final String? initialQuery;
  const SqlSnippetsScreen({super.key, this.isDemoMode = false, this.initialQuery});

  @override
  ConsumerState<SqlSnippetsScreen> createState() => _SqlSnippetsScreenState();
}

class _SqlSnippetsScreenState extends ConsumerState<SqlSnippetsScreen> {
  final ProjectContext _projectContext = ProjectContext();
  final ApiService _apiService = ApiService();
  final SqlEditingController _manualSqlController = SqlEditingController();
  bool _isLoading = true;
  List<dynamic> _projects = [];
  final _random = Random();
  Timer? _telemetryTimer;
  final Map<String, Map<String, double>> _projectMetrics = {};
  bool _isPro = false;
  bool _isShowingProCard = false;
  int _dailyLimit = 0;
  int _creditsUsed = 0;
  bool _isProjectSwitching = false;
  
  late AnimationController _logoController;
  late AnimationController _glowController;
  late Animation<double> _logoScale;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _manualSqlController.text = widget.initialQuery!;
    }
    _projectContext.addListener(_onProjectContextChanged);
    _startTelemetry();
    _fetchUserProfile();
    _loadProjects();
  }

  Future<void> _fetchUserProfile() async {
    final profile = await AuthService().getUserProfile();
    if (mounted) {
      setState(() {
        _isPro = profile['isPremium'] ?? false;
        _dailyLimit = profile['dailyLimit'] ?? 3;
        _creditsUsed = profile['creditsUsed'] ?? 0;
      });
    }
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _projectContext.removeListener(_onProjectContextChanged);
    _manualSqlController.dispose();
    super.dispose();
  }

  Future<void> _onProjectContextChanged() async {
    if (mounted) {
      setState(() {
        _isProjectSwitching = true;
      });
      _loadProjects();
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        setState(() {
          _isProjectSwitching = false;
        });
      }
    }
  }

  void _startTelemetry() {
    _telemetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        for (final project in _projects) {
          final id = project['id'];
          final status = (project['status'] ?? '').toString().toUpperCase();
          final isActive = status == 'ACTIVE' || status == 'ACTIVE_HEALTHY' || status == 'COMING_UP';

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

  Future<void> _loadProjects() async {
    if (!mounted) return;
    
    // Efficiency: don't show full loader if we already have projects
    bool showSkeleton = _projects.isEmpty;
    if (showSkeleton) setState(() => _isLoading = true);
    
    try {
      if (widget.isDemoMode) {
        _projects = [
          {'id': 'demo-proj-1', 'name': 'VECTRAX_DEMO', 'status': 'ACTIVE_HEALTHY'},
          {'id': 'demo-proj-2', 'name': 'NEURAL_BRIDGE_v1', 'status': 'ACTIVE'},
        ];
      } else {
        final result = await _apiService.listProjects();
        if (result.isNotEmpty || _projects.isEmpty) {
          _projects = result;
        }
      }

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

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  bool _isManualMode = true;

  @override
  Widget build(BuildContext context) {
    final snippets = ref.watch(sqlSnippetsProvider);
    final currentProject = _projectContext.currentProject;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VECTRAX TERMINAL',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppTheme.accent, blurRadius: 4)
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SECURE CHANNEL • ${currentProject?['name']?.toString().toUpperCase() ?? 'SELECT PROJECT'}',
                      style: TextStyle(
                        color: AppTheme.accent.withOpacity(0.8),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
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
            if (!_isPro)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: AppTheme.accent, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        '${_dailyLimit - _creditsUsed}/$_dailyLimit',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).scale(),
            if (!widget.isDemoMode)
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PulsePremiumScreen()),
                  ).then((_) => _fetchUserProfile());
                },
                icon: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppTheme.accent,
                  size: 20,
                ),
              ),
            IconButton(
              onPressed: () => _showAddSnippetDialog(context),
              icon: const Icon(Icons.add_box_rounded,
                  size: 22, color: AppTheme.accent),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (_isLoading && _projects.isEmpty)
                  const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    color: AppTheme.accent,
                    minHeight: 1,
                  ),
                _buildProjectCarousel(),
                _buildQuickActions(),
                Expanded(
                  child: !_projectContext.hasProject
                      ? const ProjectSelectionRequired(
                          title: 'TERMINAL STANDBY',
                          description: 'Select a project to authorize a secure SQL channel.',
                          icon: Icons.terminal_rounded,
                        )
                      : _buildManualView(snippets),
                ),
              ],
            ),
            if (_isShowingProCard)
              Positioned.fill(
                child: PulseProMembershipCard(
                  onUpgrade: () {
                    HapticFeedback.heavyImpact();
                    setState(() => _isShowingProCard = false);
                  },
                  onClose: () => setState(() => _isShowingProCard = false),
                ),
              ),
            if (_isProjectSwitching) _buildProjectSwitchOverlay(),
          ],
        ),
      ),
    );
  }

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
                          child: const Icon(Icons.terminal_rounded, color: AppTheme.accent, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'CONNECTING TERMINAL',
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
                      'Authorizing SQL console...',
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

  Widget _buildModeToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _buildToggleItem('MANUAL ENTRY', _isManualMode,
                  () => setState(() => _isManualMode = true))),
          Expanded(
              child: _buildToggleItem('ARCHITECT AI', !_isManualMode,
                  () => setState(() => _isManualMode = false))),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : AppTheme.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualView(List<dynamic> snippets) {
    final history = ref.watch(queryHistoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE COMMAND CONSOLE',
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              TextButton.icon(
                onPressed: () => _openAiArchitectIntoEditor(context),
                icon: const Icon(Icons.auto_awesome_rounded, size: 12, color: AppTheme.accent),
                label: Text(
                  'AI GENERATE',
                  style: GoogleFonts.inter(
                    color: AppTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: AppTheme.accent.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.accent.withOpacity(0.15)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              SqlEditor(
                controller: _manualSqlController,
                onExecute: () {
                  final query = _manualSqlController.text;
                  if (query.isNotEmpty) {
                    _runManualQuery(context, query);
                  }
                },
              ),
              Positioned(
                top: 14, // Moved lower
                right: 12, // Adjusted for beauty
                child: IconButton(
                  onPressed: () {
                    _manualSqlController.clear();
                    HapticFeedback.lightImpact();
                  },
                  icon: Icon(Icons.close_rounded,
                      color: Colors.white.withOpacity(0.15), size: 14),
                  tooltip: 'Clear Console',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RECENT SUCCESSFUL QUERIES',
                  style: TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    ref.read(queryHistoryProvider.notifier).clearHistory();
                  },
                  icon: Icon(Icons.delete_sweep_rounded,
                      color: Colors.redAccent.withOpacity(0.5), size: 18),
                  tooltip: 'Clear History',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHistoryCarousel(history),
            const SizedBox(height: 32),
          ],
          const Text(
            'SAVED SNIPPET LIBRARY',
            style: TextStyle(
              color: AppTheme.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          if (snippets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No scripts in your library.',
                  style: TextStyle(color: AppTheme.secondary),
                ),
              ),
            )
          else
            ...snippets.asMap().entries.map((entry) =>
                _buildProfessionalSnippetCard(context, entry.value, entry.key)),
          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildHistoryCarousel(List<QueryHistoryItem> history) {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];
          return _buildHistoryCard(context, item);
        },
      ),
    );
  }

  void _showHistoryDetailsSheet(BuildContext context, QueryHistoryItem item, WidgetRef ref) {
    HapticFeedback.mediumImpact();
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUERY HISTORY DETAIL',
                      style: GoogleFonts.jetBrainsMono(
                        color: AppTheme.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Executed at ${_formatTimestamp(item.timestamp)}',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.vibrate();
                        ref.read(queryHistoryProvider.notifier).removeQuery(item.id);
                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Query history item removed'),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      tooltip: 'Remove from history',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                  item.query,
                  style: GoogleFonts.firaCode(
                    color: Colors.white.withOpacity(0.87),
                    fontSize: 12,
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
                      _manualSqlController.text = item.query;
                      Navigator.pop(sheetCtx);
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SQL query loaded into console! ⚡'),
                          backgroundColor: AppTheme.accent,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'LOAD TO CONSOLE',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _runManualQuery(context, item.query);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'EXECUTE NOW',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
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

  Widget _buildHistoryCard(BuildContext context, QueryHistoryItem item) {
    return GestureDetector(
      onTap: () => _showHistoryDetailsSheet(context, item, ref),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.015),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Color(0xFF10B981), blurRadius: 4)
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(item.timestamp),
                            style: TextStyle(
                              color: AppTheme.secondary.withOpacity(0.4),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ClipRect(
                      child: Text(
                        item.query,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.white60,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95));
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _runManualQuery(BuildContext context, String query) {
    final ref = _projectContext.currentProject?['ref'] ??
        _projectContext.currentProject?['id'];
    if (ref == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QueryResultsSheet(
        query: query,
        title: 'MANUAL COMMAND RESULT',
        projectRef: ref.toString(),
      ),
    );
  }

  void _openAiArchitectIntoEditor(BuildContext context) {
    if (!_isPro && _creditsUsed >= _dailyLimit) {
      HapticFeedback.vibrate();
      setState(() => _isShowingProCard = true);
      return;
    }

    final refProject = _projectContext.currentProject?['ref'] ??
        _projectContext.currentProject?['id'];
    if (refProject == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PulseAiSheet(
        onQueryGenerated: (query) async {
          // Deduct credit if not pro
          if (!_isPro) {
            await AuthService().deductArchitectCredit();
            _fetchUserProfile(); // Refresh credits
          }

          // Load directly into editor
          setState(() {
            _manualSqlController.text = query;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SQL query generated and loaded into console! ⚡'),
                backgroundColor: AppTheme.accent,
              ),
            );
          }
        },
      ),
    );
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
              if (_projectContext.currentProject?['id'] != p['id']) {
                setState(() {
                  _projectContext.selectProject(p);
                  _manualSqlController.clear();
                });
              }
            },
            cpu: isPausedActual ? '0' : '${metrics['cpu']!.toStringAsFixed(0)} / 60',
            ram: isPausedActual ? '0.0 MB' : '${metrics['ram']!.toStringAsFixed(1)} MB',
          );
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 24, top: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          _buildActionChip('SECURITY (RLS)', Icons.security_rounded),
          const SizedBox(width: 12),
          _buildActionChip('OPTIMIZATION', Icons.speed_rounded),
          const SizedBox(width: 12),
          _buildActionChip('WEBHOOKS', Icons.webhook_rounded),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.015),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.accent, size: 14),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalSnippetCard(
      BuildContext context, dynamic snippet, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.015),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: const Icon(Icons.code_rounded,
                          color: AppTheme.accent, size: 18),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snippet.title,
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                          Text(
                            snippet.category.toUpperCase(),
                            style: TextStyle(
                                color: AppTheme.secondary.withOpacity(0.5),
                                fontSize: 9,
                                fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.vibrate();
                        ref
                            .read(sqlSnippetsProvider.notifier)
                            .removeSnippet(snippet.id);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.delete_forever_rounded,
                          color: Colors.redAccent.withOpacity(0.3), size: 16),
                    ),
                    IconButton(
                      onPressed: () => _runQuery(context, snippet),
                      icon: const Icon(Icons.play_circle_fill_rounded,
                          color: AppTheme.accent, size: 32),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.02)),
                ),
                child: Text(
                  snippet.query,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppTheme.secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, delay: (index * 50).ms);
  }

  void _runQuery(BuildContext context, SqlSnippet snippet) {
    final ref = _projectContext.currentProject?['ref'] ??
        _projectContext.currentProject?['id'];
    if (ref == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QueryResultsSheet(
        query: snippet.query,
        title: snippet.title,
        projectRef: ref.toString(),
      ),
    );
  }

  void _showAddSnippetDialog(BuildContext context) {
    String title = '';
    String query = '';
    String category = 'General';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'NEW SNIPPET',
                style: TextStyle(
                  color: AppTheme.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: _inputDecoration('Snippet Title'),
                onChanged: (val) => title = val,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: _inputDecoration('Category (e.g., Auth, Users)'),
                onChanged: (val) => category = val,
              ),
              const SizedBox(height: 12),
              SqlEditor(
                onChanged: (val) => query = val,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (title.isNotEmpty && query.isNotEmpty) {
                    final snippet = SqlSnippet(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: title,
                      query: query,
                      category: category,
                    );
                    ref.read(sqlSnippetsProvider.notifier).addSnippet(snippet);
                    Navigator.pop(context);
                    HapticFeedback.heavyImpact();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Snippet',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.secondary.withOpacity(0.5)),
      filled: true,
      fillColor: AppTheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
    );
  }
}
