import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/services/project_context.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supa_app/features/database/widgets/sql_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supa_app/features/database/providers/query_history_provider.dart';

class PulseAiSheet extends ConsumerStatefulWidget {
  final Function(String query) onQueryGenerated;
  const PulseAiSheet({super.key, required this.onQueryGenerated});

  @override
  ConsumerState<PulseAiSheet> createState() => _PulseAiSheetState();
}

class _PulseAiSheetState extends ConsumerState<PulseAiSheet> {
  final ApiService _apiService = ApiService();
  final ProjectContext _projectContext = ProjectContext();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _sqlEditController = TextEditingController();

  bool _isScanning = false;
  bool _isGenerating = false;
  String? _generatedSql;
  Map<String, dynamic>? _schema;

  Future<void> _startBrain() async {
    if (_promptController.text.isEmpty) return;

    setState(() {
      _isScanning = true;
      _generatedSql = null;
    });

    final ref = _projectContext.currentProject?['ref'];
    if (ref == null) return;

    // 1. Scan Schema
    try {
      _schema = await _apiService.getSchema(ref);
      await Future.delayed(800.ms); // Visual feedback for "scanning"

      if (mounted) {
        setState(() {
          _isScanning = false;
          _isGenerating = true;
        });
      }

      // 2. Generate SQL via Real AI (Gemini/OpenRouter)
      final projectName = _projectContext.currentProject?['name'];
      final sql = await _apiService.generateAiSql(
          _promptController.text, _schema!,
          ref: ref, projectName: projectName);

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatedSql = sql;
          if (sql != null) {
            _sqlEditController.text = sql;
          }
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) setState(() => _isScanning = _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'NEURAL ARCHITECT ENGINE',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            if (_generatedSql == null) ...[
              const SizedBox(height: 8),
              const Text(
                'Specify your architectural intent...',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: TextField(
                  controller: _promptController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'e.g. show me all users who are paid and active',
                    hintStyle:
                        TextStyle(color: AppTheme.secondary.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (!_isScanning && !_isGenerating && _generatedSql == null)
              SupaButton(
                onPressed: _startBrain,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 18),
                    SizedBox(width: 12),
                    Text('GENERATE'),
                  ],
                ),
              ),
            if (_isScanning || _isGenerating) _buildProcessingIndicator(),
            if (_generatedSql != null) ...[
              const SizedBox(height: 12),
              const Text(
                'NEURAL BLUEPRINT GENERATED',
                style: TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: _sqlEditController,
                  maxLines: 8,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppTheme.accent,
                      fontSize: 13,
                      height: 1.5),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Edit generated blueprint...',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _generatedSql = null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.white10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('RETRY',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SupaButton(
                      onPressed: () {
                        final finalQuery = _sqlEditController.text;
                        if (finalQuery.isNotEmpty) {
                          // 1. Add to history immediately for manual console tracking
                          ref
                              .read(queryHistoryProvider.notifier)
                              .addQuery(finalQuery);

                          // 2. Pop first to clear context
                          Navigator.pop(context);

                          // 3. Execute callback
                          widget.onQueryGenerated(finalQuery);
                        }
                      },
                      child: const Text('EXECUTE'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2),
          const SizedBox(height: 24),
          Text(
            _isScanning
                ? 'SCANNING NEURAL PATHWAYS...'
                : 'COMPILING CORE BLUEPRINT...',
            style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2),
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(duration: 500.ms)
              .fadeOut(delay: 500.ms),
        ],
      ),
    );
  }
}
