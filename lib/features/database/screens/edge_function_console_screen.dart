import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supa_app/features/premium/screens/pulse_premium_screen.dart';

class EdgeFunctionConsoleScreen extends StatefulWidget {
  final String functionName;
  final Map<String, dynamic> functionDetails;
  final String projectRef;
  final String projectName;

  const EdgeFunctionConsoleScreen({
    super.key,
    required this.functionName,
    required this.functionDetails,
    required this.projectRef,
    required this.projectName,
  });

  @override
  State<EdgeFunctionConsoleScreen> createState() => _EdgeFunctionConsoleScreenState();
}

class _EdgeFunctionConsoleScreenState extends State<EdgeFunctionConsoleScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  // Logs state
  bool _isLoadingLogs = true;
  final List<dynamic> _logs = [];

  // Secrets state
  bool _isLoadingSecrets = true;
  final List<dynamic> _secrets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
    _loadSecrets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoadingLogs = true);
    final allLogs = await _apiService.listLogs(widget.projectRef, service: 'edge-function');
    
    // Filter logs specific to this function
    final filtered = allLogs.where((log) {
      final msg = (log['message'] ?? '').toString().toLowerCase();
      final detail = (log['detail'] ?? '').toString().toLowerCase();
      final metadata = (log['metadata'] ?? '').toString().toLowerCase();
      final name = widget.functionName.toLowerCase();
      return msg.contains(name) || detail.contains(name) || metadata.contains(name);
    }).toList();

    if (mounted) {
      setState(() {
        _logs.clear();
        _logs.addAll(filtered);
        _isLoadingLogs = false;
      });
    }
  }

  Future<void> _loadSecrets() async {
    setState(() => _isLoadingSecrets = true);
    final secrets = await _apiService.listSecrets(widget.projectRef);
    if (mounted) {
      setState(() {
        _secrets.clear();
        _secrets.addAll(secrets);
        _isLoadingSecrets = false;
      });
    }
  }

  Future<void> _handleAddSecret() async {
    HapticFeedback.mediumImpact();
    final nameController = TextEditingController();
    final valueController = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D11),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'NEW CONFIG SECRET',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'SECRET NAME',
                  labelStyle: const TextStyle(color: AppTheme.secondary, fontSize: 10),
                  hintText: 'e.g. SENDGRID_API_KEY',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valueController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'SECRET VALUE',
                  labelStyle: const TextStyle(color: AppTheme.secondary, fontSize: 10),
                  hintText: 'Enter secret value',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SupaButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SupaButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty && valueController.text.isNotEmpty) {
                          Navigator.pop(ctx, true);
                        }
                      },
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      child: const Text('UPSERT'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      setState(() => _isLoadingSecrets = true);
      final success = await _apiService.upsertSecrets(widget.projectRef, [
        {'name': nameController.text.trim().toUpperCase(), 'value': valueController.text.trim()}
      ]);

      if (success) {
        _showToast('Secret updated successfully.');
        _loadSecrets();
      } else {
        _showToast('Failed to save secret.', isError: true);
        setState(() => _isLoadingSecrets = false);
      }
    }
  }

  Future<void> _handleDeleteSecret(String secretName) async {
    HapticFeedback.heavyImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[950],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Text('DELETE SECRET', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete the secret "$secretName"? This cannot be undone.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoadingSecrets = true);
      final success = await _apiService.deleteSecrets(widget.projectRef, [secretName]);
      if (success) {
        _showToast('Secret deleted successfully.');
        _loadSecrets();
      } else {
        _showToast('Failed to delete secret.', isError: true);
        setState(() => _isLoadingSecrets = false);
      }
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : AppTheme.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.functionName,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'EDGE FUNCTION CONSOLE',
              style: TextStyle(
                color: AppTheme.accent.withOpacity(0.8),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadLogs();
              _loadSecrets();
            },
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accent,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              tabs: const [
                Tab(text: 'DIAGNOSTIC LOGS', icon: Icon(Icons.terminal_rounded, size: 16)),
                Tab(text: 'SECRETS & ENVS', icon: Icon(Icons.lock_rounded, size: 16)),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsTab(),
          _buildSecretsTab(),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    if (_isLoadingLogs) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2));
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.code_off_rounded, color: AppTheme.accent, size: 48),
            ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'NO FUNCTION LOGS FOUND',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'No diagnostic logs have been recorded for "${widget.functionName}" in the last 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.secondary.withOpacity(0.5),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final String level = (log['level'] ?? 'INFO').toUpperCase();
        final bool isError = level == 'ERROR';
        final bool isWarning = level == 'WARNING';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isError
                ? AppTheme.error.withOpacity(0.04)
                : (isWarning ? Colors.orangeAccent.withOpacity(0.04) : Colors.transparent),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.02)),
              left: BorderSide(
                color: isError
                    ? AppTheme.error
                    : (isWarning ? Colors.orangeAccent : Colors.transparent),
                width: 2.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isError
                          ? AppTheme.error.withOpacity(0.15)
                          : (isWarning ? Colors.orangeAccent.withOpacity(0.15) : Colors.white10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      level,
                      style: TextStyle(
                        color: isError ? AppTheme.error : (isWarning ? Colors.orangeAccent : AppTheme.secondary),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Text(
                    log['timestamp'] ?? 'Just now',
                    style: TextStyle(
                      color: AppTheme.secondary.withOpacity(0.3),
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                log['message'] ?? 'No message',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (index * 20).ms).slideY(begin: 0.05, end: 0);
      },
    );
  }

  Widget _buildSecretsTab() {
    if (_isLoadingSecrets) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ENVIRONMENT CONFIG',
                    style: GoogleFonts.outfit(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_secrets.length} Secrets Configured',
                    style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _handleAddSecret,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent.withOpacity(0.08),
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accent, width: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('ADD SECRET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Secrets List
        Expanded(
          child: _secrets.isEmpty
              ? Center(
                  child: Text(
                    'No custom environment secrets configured.',
                    style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _secrets.length,
                  itemBuilder: (context, index) {
                    final sec = _secrets[index];
                    final name = sec['name'] ?? 'UNKNOWN_KEY';
                    final hashVal = sec['value'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.015),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.vpn_key_rounded, color: AppTheme.secondary, size: 16),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hashVal.isNotEmpty
                                      ? 'SHA-256: ${hashVal.substring(0, 12)}...'
                                      : 'Hidden Value',
                                  style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _handleDeleteSecret(name),
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (index * 30).ms).slideX(begin: -0.05, end: 0);
                  },
                ),
        ),
      ],
    );
  }
}
