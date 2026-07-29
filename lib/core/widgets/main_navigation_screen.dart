import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:supa_app/features/database/screens/table_browser_screen.dart';
import 'package:supa_app/features/project/screens/ai_query_screen.dart';

import 'package:supa_app/features/database/screens/sql_snippets_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final bool isDemoMode;
  const MainNavigationScreen({super.key, this.isDemoMode = false});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    DashboardScreen(isDemoMode: widget.isDemoMode),
    TableBrowserScreen(isDemoMode: widget.isDemoMode),
    SqlSnippetsScreen(isDemoMode: widget.isDemoMode), // New Library tab
    ArchitectScreen(isDemoMode: widget.isDemoMode),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: 64,
        margin: const EdgeInsets.only(left: 32, right: 32, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSleekNavItem(Icons.dns_rounded, 'Vectrax', 0),
                _buildSleekNavItem(Icons.table_rows_rounded, 'Data', 1),
                _buildSleekNavItem(Icons.terminal_rounded, 'Terminal', 2),
                _buildSleekNavItem(Icons.auto_awesome_rounded, 'Architect', 3),
              ],
            ),
          ),
        ),
      ).animate().slideY(
          begin: 1.2, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildSleekNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: 300.ms,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accent.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppTheme.accent
                  : AppTheme.secondary.withOpacity(0.4),
            )
                .animate(target: isSelected ? 1 : 0)
                .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
            ).animate().scale().fadeIn(),
        ],
      ),
    );
  }
}
