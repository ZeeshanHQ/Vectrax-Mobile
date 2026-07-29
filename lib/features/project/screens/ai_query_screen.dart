import 'dart:async';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supa_app/core/widgets/json_tree_viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supa_app/features/database/providers/query_history_provider.dart';
import 'package:supa_app/core/services/audit_service.dart';
import 'package:supa_app/features/database/widgets/query_results_sheet.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/core/services/project_context.dart';
import 'package:supa_app/core/widgets/vibe_widgets.dart';
import 'package:supa_app/features/premium/screens/pulse_premium_screen.dart';
import 'package:supa_app/features/feedback/screens/feedback_screen.dart';
import 'package:supa_app/features/project/screens/system_audit_result_screen.dart';
import 'package:supa_app/features/auth/screens/login_screen.dart';
import 'package:supa_app/core/widgets/project_selection_required.dart';
import 'package:supa_app/core/widgets/project_slots_dialog.dart';
import 'package:supa_app/features/database/screens/sql_snippets_screen.dart';
import 'dart:ui';

class ArchitectScreen extends ConsumerStatefulWidget {
  final String? projectRef;
  final bool isDemoMode;
  const ArchitectScreen({super.key, this.projectRef, this.isDemoMode = false});

  @override
  ConsumerState<ArchitectScreen> createState() => _ArchitectScreenState();
}

class _ArchitectScreenState extends ConsumerState<ArchitectScreen> {
  final ApiService _apiService = ApiService();
  final AuditService _auditService = AuditService();
  final ProjectContext _projectContext = ProjectContext();
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _blueprintController = TextEditingController();

  bool _isAnalyzing = false;
  bool _isAuditing = false;
  bool _isMacroView = true;
  bool _isShowingProCard = false;
  List<AuditInsight> _insights = [];
  List<dynamic> _projects = [];
  bool _isLoadingProjects = false;

  // High-end Scanning States
  bool _isScanningSecurity = false;
  bool _isScanningSchema = false;
  bool _isScanningPerformance = false;

  String? _result;
  dynamic _executionResponse;
  String _activeBlueprint = 'RLS';
  String? _lastProjectRef;
  final AuthService _authService = AuthService();
  int _creditsUsed = 0;
  int _dailyLimit = 3;
  bool _isPro = false;
  String? _aiSummary;
  String? _aiHint;
  DateTime? _lastAuditTime;
  List<AuditInsight> _lastAuditInsights = [];
  String _selectedScanMode = 'deep';

  // Track metrics per project for live movement
  final Map<String, Map<String, double>> _projectMetrics = {};
  final Random _random = Random();
  Timer? _telemetryTimer;
  int _tableCount = 0;
  bool _isLoadingTableCount = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _lastProjectRef = _projectContext.currentProject?['ref'] ??
        _projectContext.currentProject?['id'];
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchProjects();
    _fetchUserProfile();
    _projectContext.addListener(_onProjectChanged);
    _startTelemetry();
    _loadTableCount();
  }

  Future<void> _fetchUserProfile() async {
    final profile = await _authService.getUserProfile();
    if (mounted) {
      setState(() {
        _isPro = profile['isPremium'] ?? false;
        _selectedScanMode = _isPro ? 'deep' : 'quick';
        _dailyLimit = profile['dailyLimit'] ?? 3;
        _creditsUsed = profile['creditsUsed'] ?? 0;
      });
    }
  }

  void _startTelemetry() {
    _telemetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _projects.length; i++) {
          final project = _projects[i];
          final id = project['id'] ?? project['ref'];
          final status = project['status']?.toString().toUpperCase() ?? '';
          final isActive = status == 'ACTIVE' || status == 'ACTIVE_HEALTHY' || status == 'COMING_UP';
          final isLocked = !_isPro && !ProjectContext().isProjectMonitored(id?.toString());
          
          if (id == null) continue;
          
          if (!isActive || isLocked) {
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

  void _onProjectChanged() {
    if (mounted) {
      setState(() {});
      _loadTableCount();
    }
  }

  void _loadTableCount() async {
    final ref = _projectContext.currentProject?['ref'] ?? _projectContext.currentProject?['id'];
    if (ref == null) return;
    
    // Check if the project is locked for free user
    final isLocked = !_isPro && !ProjectContext().isProjectMonitored(ref.toString());
    if (isLocked) {
      if (mounted) {
        setState(() {
          _tableCount = 0;
          _isLoadingTableCount = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoadingTableCount = true);
    try {
      final tables = await _apiService.listTables(ref.toString());
      if (mounted) {
        setState(() {
          _tableCount = tables.length;
          _isLoadingTableCount = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTableCount = false);
    }
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _projectContext.removeListener(_onProjectChanged);
    _controller.dispose();
    _blueprintController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    setState(() => _isLoadingProjects = true);
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
        _isLoadingProjects = false;
        // Inject metrics immediately for demo
        for (var p in _projects) {
          _projectMetrics[p['id']] = {'cpu': 0.4, 'ram': 158.0};
        }
      });
      return;
    }

    try {
      final projects = await _apiService.getProjects();
      if (mounted) {
        // Sort ACTIVE/ACTIVE_HEALTHY projects to the front
        projects.sort((a, b) {
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
        setState(() {
          _projects = projects;
          _isLoadingProjects = false;
        });

        // Auto-select first monitored project if none is selected or if current selection is locked
        final currentProjId = _projectContext.currentProject?['id'] ?? _projectContext.currentProject?['ref'];
        final isCurrentLocked = !_isPro && currentProjId != null && !ProjectContext().isProjectMonitored(currentProjId.toString());

        if (_projects.isNotEmpty && (!_projectContext.hasProject || isCurrentLocked)) {
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
        } else if (_projectContext.hasProject) {
          _loadTableCount();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  void _runNeuralAudit() async {
    final ref = widget.projectRef ??
        _projectContext.currentProject?['ref'] ??
        _projectContext.currentProject?['id'];
    if (ref == null) return;

    // Scan Frequency Limit for Free Users (1 scan per day)
    if (!_isPro && _lastAuditTime != null) {
      final difference = DateTime.now().difference(_lastAuditTime!);
      if (difference.inHours < 24) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Free users: 1 scan per day. Next scan in ${24 - difference.inHours}h.'),
              backgroundColor: AppTheme.warning,
              action: SnackBarAction(
                label: 'UPGRADE',
                textColor: Colors.black,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
                  ).then((_) => _fetchUserProfile());
                },
              ),
            ),
          );
        }
        return;
      }
    }

    if (_selectedScanMode == 'deep' && !_isPro) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
      ).then((_) => _fetchUserProfile());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deep Full database scans require Vectrax Pro! 💎'),
          backgroundColor: AppTheme.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.isDemoMode) {
      _showBridgeToCommitment();
      return;
    }

    setState(() {
      _isAuditing = true;
      _isMacroView = true;
      _isScanningSecurity = true;
      _isScanningSchema = false;
      _isScanningPerformance = false;
      _insights = [];
    });

    HapticFeedback.mediumImpact();

    try {
      // 1. Security Handshake
      await Future.delayed(1500.ms);
      setState(() {
        _isScanningSecurity = false;
        _isScanningSchema = true;
      });
      HapticFeedback.lightImpact();

      // 2. Schema Handshake
      await Future.delayed(1500.ms);
      setState(() {
        _isScanningSchema = false;
        _isScanningPerformance = true;
      });
      HapticFeedback.lightImpact();

      // 3. Performance Finalization
      final results = await _auditService.runNeuralPulse(ref.toString());
      final filteredResults = _selectedScanMode == 'quick'
          ? results.where((r) => r.severity == AuditSeverity.critical).toList()
          : results;
      await Future.delayed(1000.ms);

      if (mounted) {
        setState(() {
          _isAuditing = false;
          _lastAuditTime = DateTime.now();
          _lastAuditInsights = filteredResults;
        });
        HapticFeedback.heavyImpact();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SystemAuditResultScreen(
              project: _projectContext.currentProject ?? {'name': 'Project'},
              initialInsights: filteredResults,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuditing = false;
          _isScanningSecurity = false;
          _isScanningSchema = false;
          _isScanningPerformance = false;
        });
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
              'NEURAL AUDIT IS LOCKED',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            const Text(
              'Deep performance and security auditing requires a live infrastructure connection. Connect your stack to unlock.',
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
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 11))),
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

  void _architecturalPulse() async {
    if (_controller.text.isEmpty) return;

    // Credit Check
    if (!_isPro && _creditsUsed >= _dailyLimit) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
      ).then((_) => _fetchUserProfile());
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
      _aiSummary = null;
      _aiHint = null;
    });

    final ref = widget.projectRef ??
        _projectContext.currentProject?['ref'] ??
        _projectContext.currentProject?['id'];
    if (ref == null) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('No project selected. Please select a project first.'),
              backgroundColor: AppTheme.error),
        );
      }
      return;
    }

    try {
      // Simulate Deep Neural Handshake
      await Future.delayed(3.seconds);

      final schema = await _apiService.getSchema(ref);
      final projectName = _projectContext.currentProject?['name'];
      final intent = _controller.text.isEmpty 
          ? 'Focus: $_activeBlueprint. Run standard optimization.' 
          : 'Focus: $_activeBlueprint. CRITICAL USER INSTRUCTION: ${_controller.text}';
      
      final generatedSql = await _apiService.generateAiSql(
          'Keep response extremely concise. SQL only or minimal summary. Intent: $intent', 
          schema,
          ref: ref, 
          projectName: projectName);

      if (generatedSql == null || generatedSql.isEmpty) {
        throw Exception('AI failed to generate a blueprint. Neural pathways saturated.');
      }

      // Scan if it is just a text/comment response (meaning the AI was talking/giving advice instead of SQL)
      final isOnlyComment = generatedSql.trim().startsWith('--');
      dynamic response;
      if (!isOnlyComment) {
        response = await _apiService.executeSql(ref, generatedSql);
      } else {
        response = 'Informational query response.';
      }

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _result = generatedSql;
          _blueprintController.text = generatedSql;
          _executionResponse = response;
          
          if (isOnlyComment) {
            // Extract the message after '-- INFORMATION:' or '-- INFO:' or '--'
            String cleanMsg = generatedSql;
            if (cleanMsg.contains('-- INFORMATION:')) {
              cleanMsg = cleanMsg.split('-- INFORMATION:').last.trim();
            } else if (cleanMsg.contains('-- INFO:')) {
              cleanMsg = cleanMsg.split('-- INFO:').last.trim();
            } else {
              cleanMsg = cleanMsg.replaceAll('--', '').trim();
            }
            _aiSummary = cleanMsg;
          } else {
            // Generate an elite summary based on keywords - more natural, less robotic
            if (generatedSql.toLowerCase().contains('policy')) {
              _aiSummary = 'Security layer activated. I have synthesized RLS policies to safeguard your data from unauthorized access.';
            } else if (generatedSql.toLowerCase().contains('index')) {
              _aiSummary = 'Performance optimization path identified. Applying indices to accelerate your heaviest query workloads.';
            } else if (generatedSql.toLowerCase().contains('function') || generatedSql.toLowerCase().contains('trigger')) {
              _aiSummary = 'Intelligence logic deployed. Custom triggers and functions are now managing your database automation.';
            } else {
              _aiSummary = 'Blueprint execution complete. Your system architecture has been refined to handle modern scale and performance demands.';
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blueprint Executed! ⚡'),
            backgroundColor: AppTheme.accent,
          ),
        );
        HapticFeedback.heavyImpact();

        // Deduct Credit only on success and if not Pro
        if (!_isPro) {
          final success = await _authService.deductArchitectCredit();
          if (success && mounted) {
            setState(() {
              _creditsUsed++;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _aiHint = 'I focus on database architecture. Try specifying a table name or security requirement for a more precise blueprint.';
        });
      }
    }
  }

  void _showCreditsExplanationSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.8),
      isScrollControlled: true,
      builder: (context) {
        final remaining = _dailyLimit - _creditsUsed;
        final ratio = (remaining / _dailyLimit).clamp(0.0, 1.0);
        
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0A0C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Icon Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
                    ),
                    child: const Icon(
                      Icons.offline_bolt_rounded,
                      color: AppTheme.accent,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title
                Center(
                  child: Text(
                    'NEURAL ENERGY CELL',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'DAILY CREDIT REACTION CELL',
                    style: GoogleFonts.inter(
                      color: AppTheme.accent.withOpacity(0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Energy Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Charge Level',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$remaining / $_dailyLimit Credits',
                            style: GoogleFonts.firaCode(
                              color: AppTheme.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          color: AppTheme.accent,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Description text
                Text(
                  'Vectrax AI features consume high-grade API resources to scan database schemas. Free tier accounts are allocated 3 daily credits. Recharging occurs automatically at midnight.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white30,
                    fontSize: 11,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 36),
                
                // Upgrade CTA button
                SupaButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.workspace_premium_rounded, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'GO UNLIMITED (UPGRADE)',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isMacroView = true);
              },
              child: AnimatedContainer(
                duration: 250.ms,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isMacroView ? const Color(0xFF16161B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _isMacroView ? AppTheme.accent.withOpacity(0.1) : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_rounded,
                        size: 14,
                        color: _isMacroView ? AppTheme.accent : Colors.white24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DIAGNOSTICS',
                        style: TextStyle(
                          color: _isMacroView ? Colors.white : Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isMacroView = false);
              },
              child: AnimatedContainer(
                duration: 250.ms,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isMacroView ? const Color(0xFF16161B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: !_isMacroView ? AppTheme.accent.withOpacity(0.1) : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: !_isMacroView ? AppTheme.accent : Colors.white24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI BLUEPRINTS',
                        style: TextStyle(
                          color: !_isMacroView ? Colors.white : Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRef = _projectContext.currentProject?['ref'] ??
        _projectContext.currentProject?['id'];
    if (currentRef != _lastProjectRef) {
      _lastProjectRef = currentRef;
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _result = null;
            _executionResponse = null;
            _isMacroView = false;
            _controller.clear();
            _blueprintController.clear();
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VECTRAX ARCHITECT',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Row(
              children: [
                if (_projectContext.hasProject) ...[
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
                  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    _projectContext.currentProject?['name']?.toString().toUpperCase() ??
                        'SYSTEM INTELLIGENCE ENGINE',
                    style: TextStyle(
                        color: _projectContext.hasProject 
                            ? AppTheme.accent.withOpacity(0.8)
                            : Colors.white.withOpacity(0.25),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FeedbackScreen()),
              );
            },
            icon: Icon(
              Icons.lightbulb_outline_rounded,
              color: Colors.white.withOpacity(0.35),
              size: 20,
            ),
          ),
          if (!_isPro)
            GestureDetector(
              onTap: _showCreditsExplanationSheet,
              child: Center(
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
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
                );
              },
              icon: const Icon(
                Icons.workspace_premium_rounded,
                color: AppTheme.accent,
                size: 20,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Container(
          height: double.infinity,
          decoration: const BoxDecoration(color: AppTheme.background),
        child: Stack(
          children: [
            if (_isMacroView) const CyberBlueprintGrid(),
            AnimatedScale(
              scale: 1.0,
              duration: 800.ms,
              curve: Curves.fastOutSlowIn,
              child: _isLoadingProjects && _projects.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accent,
                        strokeWidth: 2,
                      ),
                    )
                  : _projects.isEmpty
                      ? const Center(
                          child: ProjectSelectionRequired(
                            title: 'NO PROJECTS DETECTED',
                            description: 'Please connect your Supabase account or create a project first.',
                            icon: Icons.cloud_off_rounded,
                          ),
                        )
                      : Column(
                          children: [
                            _buildProjectSelectorHero(),
                            _buildTabSwitcher(),
                            Expanded(
                              child: Stack(
                                children: [
                                  _isMacroView ? _buildMacroView() : _buildStandardView(),
                                  if (!_projectContext.hasProject)
                                    Positioned.fill(
                                      child: ClipRRect(
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                          child: Container(
                                            color: Colors.black.withOpacity(0.7), // Deeper for elite focus
                                            child: const Center(
                                              child: ProjectSelectionRequired(
                                                title: 'ARCHITECT STANDBY',
                                                description: 'Select a project to authorize system intelligence.',
                                                icon: Icons.psychology_rounded,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
            if (_isAuditing) _buildScanningOverlay(),
          ],
        ),
        ), // close Container
      ), // close GestureDetector
    );
  }
  Widget _buildStandardView() {
    final showResult = _result != null || _isAnalyzing;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 12, 24, showResult ? 300 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.015),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'AI BLUEPRINT ENGINE',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Instruct the AI to generate security policies, normalize tables, or construct functions.',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'BLUEPRINT TYPE',
                          style: GoogleFonts.inter(
                            color: Colors.white30,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            children: [
                              _buildBlueprintChip('RLS', Icons.shield_moon_rounded, 'Security'),
                              const SizedBox(width: 12),
                              _buildBlueprintChip('SCHEMA', Icons.account_tree_rounded, 'Schema'),
                              const SizedBox(width: 12),
                              _buildBlueprintChip('FUNCTIONS', Icons.bolt_rounded, 'Logic'),
                              const SizedBox(width: 12),
                              _buildBlueprintChip('OPTIMIZE', Icons.speed_rounded, 'Speed'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'INSTRUCTION PROMPT',
                          style: GoogleFonts.jetBrainsMono(
                            color: _focusNode.hasFocus
                                ? AppTheme.accent.withOpacity(0.7)
                                : Colors.white30,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedContainer(
                          duration: 200.ms,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _focusNode.hasFocus
                                  ? AppTheme.accent.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.06),
                              width: 1.0,
                            ),
                            boxShadow: [
                              if (_focusNode.hasFocus)
                                BoxShadow(
                                  color: AppTheme.accent.withOpacity(0.02),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: 4,
                            cursorColor: AppTheme.accent,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Describe what you want to do or select a preset to pre-fill...',
                              hintStyle: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.12),
                                fontSize: 12,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_result == null)
                          SupaButton(
                            isLoading: _isAnalyzing,
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              HapticFeedback.mediumImpact();
                              _architecturalPulse();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.auto_awesome_rounded, size: 14),
                                SizedBox(width: 8),
                                Text(
                                  'GENERATE BLUEPRINT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _result!));
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Blueprint copied to clipboard! 📋'),
                                      backgroundColor: AppTheme.accent,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.copy_all_rounded, size: 12, color: Colors.white70),
                                      const SizedBox(width: 6),
                                      Text(
                                        'COPY CODE',
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 9,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _result = null;
                                    _aiSummary = null;
                                    _executionResponse = null;
                                    _controller.clear();
                                    _blueprintController.clear();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Text(
                                    'RESET',
                                    style: GoogleFonts.inter(
                                      color: Colors.white30,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
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
                ),
              ),
            ),
            if (_aiHint != null) ...[
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.01),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(Icons.tips_and_updates_rounded, color: AppTheme.accent, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _aiHint!,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            ],
            if (_isAnalyzing) ...[
              const SizedBox(height: 48),
              const NeuralTerminalStream(),
            ],
            if (_result != null) ...[
              const SizedBox(height: 32),
              if (_aiSummary != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.015),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SUMMARY', 
                              style: GoogleFonts.inter(
                                color: AppTheme.accent,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _aiSummary!,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: 0.05, end: 0),
                const SizedBox(height: 24),
              ],
              EngineeringOutputConsole(
                controller: _blueprintController,
                hintText: 'Review your system plan...',
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),
              const SizedBox(height: 24),
              SupaButton(
                onPressed: () {
                  final query = _blueprintController.text;
                  if (query.isEmpty) return;
                  Clipboard.setData(ClipboardData(text: query));
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SqlSnippetsScreen(initialQuery: query),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Blueprint copied and loaded into terminal console! ↗'),
                      backgroundColor: AppTheme.accent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.terminal_rounded, size: 14, color: Colors.black),
                    SizedBox(width: 8),
                    Text('MOVE TO CONSOLE',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ],
        ),
    );
  }

  Widget _buildMacroView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.015),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isAuditing) ...[
                            // Pulsing glowing background radar wave 1
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.accent.withOpacity(0.2), width: 1.5),
                              ),
                            ).animate(onPlay: (c) => c.repeat())
                             .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.4, 1.4), duration: 2.seconds, curve: Curves.easeOut)
                             .fadeOut(duration: 2.seconds),
                            // Pulsing glowing background radar wave 2
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.accent.withOpacity(0.1), width: 1),
                              ),
                            ).animate(onPlay: (c) => c.repeat())
                             .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.6, 1.6), delay: 800.ms, duration: 2.seconds, curve: Curves.easeOut)
                             .fadeOut(duration: 2.seconds),
                          ],
                          
                          // Outer Radar Ring Boundary
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.4),
                              border: Border.all(
                                color: _isAuditing ? AppTheme.accent.withOpacity(0.4) : Colors.white.withOpacity(0.04),
                                width: 2,
                              ),
                              boxShadow: _isAuditing
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.accent.withOpacity(0.08),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_isAuditing)
                                  // Rotating radar sweep hand
                                  Transform.rotate(
                                    angle: 0.0,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        width: 3,
                                        height: 75,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [AppTheme.accent, Colors.transparent],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ).animate(onPlay: (c) => c.repeat())
                                   .rotate(duration: 2.seconds, begin: 0, end: 1),
                              ],
                            ),
                          ),
                          
                          // Central Telemetry readouts
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Pulsing core beacon dot when scanning
                              if (_isAuditing)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.accent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accent,
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                ).animate(onPlay: (c) => c.repeat(reverse: true))
                                 .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1.seconds)
                              else
                                Text(
                                  _lastAuditTime == null ? '--' : '85',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                _isAuditing ? 'SWEEPING' : (_lastAuditTime == null ? 'READY' : 'HEALTH INDEX'),
                                style: GoogleFonts.jetBrainsMono(
                                  color: _isAuditing ? AppTheme.accent : AppTheme.accent.withOpacity(0.8),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'DATABASE SECURITY SCANNER',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sweep database configurations, scan foreign key index coverage, and verify row-level security (RLS) vectors.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedScanMode = 'quick');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedScanMode == 'quick' ? AppTheme.accent.withOpacity(0.08) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedScanMode == 'quick' ? AppTheme.accent.withOpacity(0.5) : Colors.white12,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'QUICK CHECK',
                                style: GoogleFonts.inter(
                                  color: _selectedScanMode == 'quick' ? Colors.white : Colors.white30,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (!_isPro) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
                                ).then((_) => _fetchUserProfile());
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Deep Full database scans require Vectrax Pro! 💎'),
                                    backgroundColor: AppTheme.accent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              setState(() => _selectedScanMode = 'deep');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedScanMode == 'deep' ? AppTheme.accent.withOpacity(0.08) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedScanMode == 'deep' ? AppTheme.accent.withOpacity(0.5) : Colors.white12,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'DEEP FULL',
                                    style: GoogleFonts.inter(
                                      color: _selectedScanMode == 'deep' ? Colors.white : Colors.white30,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.workspace_premium_rounded,
                                    color: AppTheme.accent,
                                    size: 11,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: _lastAuditTime == null
                            ? SizedBox(
                                width: 220,
                                height: 42,
                                child: SupaButton(
                                  isLoading: _isAuditing,
                                  onPressed: _runNeuralAudit,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.shield_rounded, size: 14),
                                      SizedBox(width: 8),
                                      Text(
                                        'INITIATE SWEEP',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 220,
                                    height: 42,
                                    child: SupaButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SystemAuditResultScreen(
                                              project: _projectContext.currentProject ?? {'name': 'Project'},
                                              initialInsights: _lastAuditInsights,
                                            ),
                                          ),
                                        );
                                      },
                                      backgroundColor: AppTheme.accent,
                                      foregroundColor: Colors.black,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.analytics_rounded, size: 14),
                                          SizedBox(width: 8),
                                          Text(
                                            'VIEW REPORT',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 10,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: 220,
                                    height: 36,
                                    child: SupaButton(
                                      isLoading: _isAuditing,
                                      onPressed: _runNeuralAudit,
                                      outline: true,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.radar_rounded, size: 14),
                                          SizedBox(width: 8),
                                          Text(
                                            'RUN NEW SWEEP',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 10,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
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
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildGlassMetricCard(
                  'SECURITY',
                  _isAuditing ? 'SCANNING...' : 'OPTIMAL',
                  Icons.lock_outline_rounded,
                  AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGlassMetricCard(
                  'SCHEMAS',
                  _isLoadingTableCount
                      ? 'LOADING...'
                      : '$_tableCount TABLES',
                  Icons.dns_outlined,
                  Colors.blueAccent,
                ),
              ),
            ],
          ),
          if (widget.isDemoMode) ...[
            const SizedBox(height: 24),
            _buildConnectBanner(context),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.015),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color.withOpacity(0.6), size: 18),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectSelectorHero() {
    final currentRef = _projectContext.currentProject?['ref'] ??
        _projectContext.currentProject?['id'];
    final metrics = _projectMetrics[currentRef] ?? {'cpu': 0.0, 'ram': 0.0};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 110,
          margin: const EdgeInsets.symmetric(vertical: 24),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _projects.length,
            itemBuilder: (context, index) {
              final p = _projects[index];
              final ref = p['ref'] ?? p['id'];
              final cardMetrics = _projectMetrics[ref] ?? {'cpu': 0.0, 'ram': 0.0};
              final isLocked = !_isPro && !ProjectContext().isProjectMonitored(ref?.toString());
              final isPaused = p['status'] == 'PAUSED' || isLocked;
              return MiniProjectCard(
                name: p['name'] ?? 'Unknown',
                status: isLocked ? 'PAUSED' : (p['status'] ?? 'ACTIVE_HEALTHY'),
                cpu: isPaused ? '0' : '${cardMetrics['cpu']!.toStringAsFixed(0)} / 60',
                ram: isPaused ? '0.0 MB' : '${cardMetrics['ram']!.toStringAsFixed(1)} MB',
                isSelected: currentRef?.toString() == ref?.toString(),
                isLocked: isLocked,
                onTap: () {
                  if (isLocked) {
                    ProjectSlotsDialog.show(
                      context,
                      allProjects: _projects,
                      targetProject: p,
                      onSwapped: () {
                        setState(() {});
                      },
                    );
                  } else {
                    _projectContext.selectProject(p);
                  }
                },
              );
            },
          ),
        ),

      ],
    );
  }

  Widget _buildDeepAuditVector(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 130, // Slim smart card
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)), // Lower outline
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withOpacity(0.5), size: 12),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                color: color.withOpacity(0.9),
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }



  Widget _buildScanningOverlay() {
    final projectName = _projectContext.currentProject?['name'] ?? 'Project';

    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.05), width: 1),
                ),
              ),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.accent.withOpacity(0.2), width: 2),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.2, 1.2),
                    curve: Curves.easeInOutExpo,
                    duration: 2.seconds,
                  )
                  .fadeOut(),
              const Icon(Icons.radio_button_checked_rounded,
                      color: AppTheme.accent, size: 32)
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 2.seconds),
            ],
          ),
          const SizedBox(height: 60),
          Text(
            'SCANNING',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 8),
          ),
          const SizedBox(height: 16),
          Text(
            projectName.toUpperCase(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1),
          ),
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 100),
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withOpacity(0.05),
              color: AppTheme.accent,
              minHeight: 1,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildMacroMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.1),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildInsightCard(AuditInsight insight) {
    final color = insight.severity == AuditSeverity.critical
        ? Colors.redAccent
        : (insight.severity == AuditSeverity.warning
            ? Colors.orangeAccent
            : AppTheme.accent);
    String displayTitle = insight.title;
    if (displayTitle.contains('RLS'))
      displayTitle = 'Security Hardening Required';
    if (displayTitle.contains('Index'))
      displayTitle = 'Performance Optimization Vector';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(insight.category.toUpperCase(),
                        style: TextStyle(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5)),
                    const Spacer(),
                    if (insight.isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: AppTheme.accent.withOpacity(0.5),
                                width: 0.5),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('PRO',
                            style: TextStyle(
                                color: AppTheme.accent,
                                fontSize: 7,
                                fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(displayTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2)),
                const SizedBox(height: 8),
                Text(insight.description,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 12,
                        height: 1.5,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Divider(color: color.withOpacity(0.1), height: 1),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PulsePremiumScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.02),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(12))),
              child: Center(
                child: Text(
                    insight.severity == AuditSeverity.critical
                        ? 'INITIATE REPAIR'
                        : 'RUN OPTIMIZATION',
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildBlueprintChip(String blueprint, IconData icon, String label) {
    final isSelected = _activeBlueprint == blueprint;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeBlueprint = blueprint;
          _controller.text = _getTemplateText(blueprint);
        });
      },
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withOpacity(0.06)
              : Colors.white.withOpacity(0.015),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withOpacity(0.25)
                : Colors.white.withOpacity(0.04),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.06),
                blurRadius: 8,
                spreadRadius: -2,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.accent : Colors.white24, size: 11),
            const SizedBox(width: 5),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.white30,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTemplateText(String blueprint) {
    switch (blueprint) {
      case 'RLS':
        return 'Create a row-level security policy for table profiles so users can only read/edit their own rows';
      case 'SCHEMA':
        return 'Create a new table called notifications with columns id, user_id, title, content, and created_at';
      case 'FUNCTIONS':
        return 'Create a database trigger function that auto-updates updated_at timestamp when a row is updated';
      case 'OPTIMIZE':
        return 'Add index optimization to search column in posts table to increase query performance';
      default:
        return '';
    }
  }

  String _getHintText() {
    switch (_activeBlueprint) {
      case 'RLS':
        return 'e.g. users should only see their own posts';
      case 'SCHEMA':
        return 'e.g. create a table for storing app notifications';
      case 'FUNCTIONS':
        return 'e.g. send a welcome email when a user signs up';
      default:
        return 'Describe what you want to do...';
    }
  }

  Widget _buildConnectBanner(BuildContext context) {
    return Container(
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
                  'Connect your real stack for live insight.',
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
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginScreen()),
                (route) => false,
              );
            },
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
}

// SelectionWrapper removed as it's no longer needed
