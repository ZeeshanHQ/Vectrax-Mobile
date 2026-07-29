import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/json_tree_viewer.dart';
import 'package:supa_app/core/widgets/skeleton_loader.dart';
import 'package:supa_app/features/database/providers/sql_snippets_provider.dart';
import 'package:supa_app/features/database/providers/query_history_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class QueryResultsSheet extends ConsumerWidget {
  final String query;
  final String title;
  final String projectRef;
  final bool autoRefresh;

  const QueryResultsSheet({
    super.key,
    required this.query,
    required this.title,
    required this.projectRef,
    this.autoRefresh = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryKey = QueryKey(query, projectRef);
    final executionState = ref.watch(queryExecutionProvider(queryKey));

    // ELITE LOGIC: Only add to history if successfully run
    ref.listen(queryExecutionProvider(queryKey), (previous, next) {
      if (next is AsyncData && next.value != null) {
        // Use a slight delay to avoid modifying state during build
        Future.microtask(() {
          ref.read(queryHistoryProvider.notifier).addQuery(query);
        });
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle for swiping
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QUERY RESULTS',
                          style: TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Expanded(
              child: executionState.when(
                data: (results) => _buildResults(results, scrollController),
                loading: () => _buildLoading(),
                error: (err, stack) => _buildError(err.toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(
      List<Map<String, dynamic>> results, ScrollController scrollController) {
    if (results.isEmpty) {
      return const Center(
          child: Text('No results returned',
              style: TextStyle(color: AppTheme.secondary)));
    }

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: JsonTreeView(
              data: results.length == 1 ? results.first : results,
              initialExpanded: true,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.04),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  ),
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1.5.seconds, curve: Curves.easeInOutSine),
            const SizedBox(height: 24),
            Text(
              'EXECUTING COMMAND',
              style: GoogleFonts.jetBrainsMono(
                color: AppTheme.accent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Connecting to database node proxy...',
              style: GoogleFonts.inter(
                color: Colors.white24,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return _AdvancedErrorView(error: error);
  }
}

class _AdvancedErrorView extends StatefulWidget {
  final String error;
  const _AdvancedErrorView({required this.error});

  @override
  State<_AdvancedErrorView> createState() => _AdvancedErrorViewState();
}

class _AdvancedErrorViewState extends State<_AdvancedErrorView> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    // Extract a cleaner message if it contains "message":"..."
    String displayMsg = 'Execution Failed';
    if (widget.error.contains('"message":"')) {
      final match = RegExp(r'"message":"([^"]+)"').firstMatch(widget.error);
      if (match != null) {
        displayMsg = match.group(1)?.replaceAll('\\n', '\n') ?? 'Query Error';
      }
    } else {
      displayMsg = widget.error.split(':').last.trim();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.terminal_rounded,
                    color: Colors.redAccent, size: 32),
              ),
              const SizedBox(height: 24),
              const Text(
                'NEURAL OVERLOAD / SYNTAX ERROR',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                displayMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => setState(() => _showDetails = !_showDetails),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showDetails ? 'HIDE TRACE' : 'VIEW RAW TRACE',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showDetails
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 14,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showDetails) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: SelectableText(
                    widget.error,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                ).animate().fadeIn(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
