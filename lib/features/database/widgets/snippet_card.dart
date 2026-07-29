import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/features/database/models/sql_snippet.dart';

class SnippetCard extends StatelessWidget {
  final SqlSnippet snippet;
  final VoidCallback onPlay;
  final VoidCallback onTap;

  const SnippetCard({
    super.key,
    required this.snippet,
    required this.onPlay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            snippet.category.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      snippet.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snippet.query,
                      style: TextStyle(
                        color: AppTheme.secondary.withOpacity(0.5),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildPlayButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onPlay();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 56,
          height: 100, // Large button as requested
          decoration: BoxDecoration(
            color:
                const Color(0xFF10B981).withOpacity(0.1), // Emerald Green tint
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Color(0xFF10B981),
            size: 32,
          ),
        ),
      ),
    );
  }
}
