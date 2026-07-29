import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/supa_button.dart';

class SqlEditor extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onExecute;
  final SqlEditingController? controller;

  const SqlEditor({
    super.key,
    this.initialValue = '',
    this.onChanged,
    this.onExecute,
    this.controller,
  });

  @override
  State<SqlEditor> createState() => _SqlEditorState();
}

class _SqlEditorState extends State<SqlEditor> {
  late SqlEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? SqlEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(SqlEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      _controller = widget.controller!;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                const Text(
                  'SQL ENGINE v1.0',
                  style: TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              TextField(
                controller: _controller,
                maxLines: null,
                minLines: 8,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.6,
                  color: Colors.white,
                ),
                cursorColor: AppTheme.accent,
                onChanged: widget.onChanged,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(20),
                  border: InputBorder.none,
                  hintText: '-- Describe your intent or write SQL...',
                  hintStyle: TextStyle(color: Colors.white12),
                ),
              ),
              if (widget.onExecute != null)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onExecute?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppTheme.accent.withOpacity(0.2)),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppTheme.accent,
                        size: 20,
                      ),
                    ),
                  ).animate().fadeIn().scale(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SqlEditingController extends TextEditingController {
  SqlEditingController({super.text});

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final List<TextSpan> children = [];

    // PREMIUM Highlighting: Keywords, Functions, Operators, Strings
    final keywords = RegExp(
      r'\b(SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|JOIN|ON|GROUP BY|ORDER BY|LIMIT|OFFSET|HAVING|AND|OR|IN|NOT|NULL|IS|AS|CREATE|TABLE|DROP|ALTER|TRUNCATE|DATABASE|SCHEMA|VIEW|INDEX|PROCEDURE|FUNCTION|TRIGGER|WITH|RECURSIVE|UNION|ALL|EXCEPT|INTERSECT|DISTINCT|CASE|WHEN|THEN|ELSE|END|PUBLIC|GRANT|REVOKE)\b',
      caseSensitive: false,
    );

    final functions = RegExp(
        r'\b(COUNT|SUM|AVG|MIN|MAX|NOW|DATE_TRUNC|COALESCE|NULLIF|CAST|TO_JSON|JSON_AGG|PG_SIZE_PRETTY|PG_TOTAL_RELATION_SIZE)\b',
        caseSensitive: false);
    final values = RegExp(r"'.*?'|\b\d+\b");
    final operators = RegExp(r'[=<>!+\-*/%|&]');

    text.splitMapJoin(
      RegExp(
          '${keywords.pattern}|${functions.pattern}|${values.pattern}|${operators.pattern}'),
      onMatch: (m) {
        final match = m[0]!;
        if (keywords.hasMatch(match)) {
          children.add(TextSpan(
              text: match,
              style: style?.copyWith(
                  color: AppTheme.accent, fontWeight: FontWeight.bold)));
        } else if (functions.hasMatch(match)) {
          children.add(TextSpan(
              text: match,
              style: style?.copyWith(
                  color: const Color(0xFF60A5FA),
                  fontWeight: FontWeight.w600)));
        } else if (values.hasMatch(match)) {
          children.add(TextSpan(
              text: match,
              style: style?.copyWith(color: const Color(0xFFFBBF24))));
        } else if (operators.hasMatch(match)) {
          children.add(TextSpan(
              text: match,
              style:
                  style?.copyWith(color: Colors.pinkAccent.withOpacity(0.8))));
        } else {
          children.add(TextSpan(text: match, style: style));
        }
        return '';
      },
      onNonMatch: (n) {
        children.add(TextSpan(text: n, style: style));
        return '';
      },
    );

    return TextSpan(children: children, style: style);
  }
}
