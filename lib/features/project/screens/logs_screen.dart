import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/services/api_service.dart';

class LogsScreen extends StatefulWidget {
  final String projectName;
  final String projectRef;
  const LogsScreen({super.key, required this.projectName, required this.projectRef});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _activeService = 'postgres'; // 'postgres', 'api', 'auth', 'edge-function'
  final List<dynamic> _fetchedLogs = [];

  final List<Map<String, String>> _services = [
    {'id': 'postgres', 'label': 'DATABASE'},
    {'id': 'api', 'label': 'API GATEWAY'},
    {'id': 'auth', 'label': 'AUTH'},
    {'id': 'edge-function', 'label': 'FUNCTIONS'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _apiService.listLogs(widget.projectRef, service: _activeService);
    if (mounted) {
      setState(() {
        _fetchedLogs.clear();
        _fetchedLogs.addAll(logs);
        _isLoading = false;
      });
    }
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
              'UNIFIED LOGS',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              widget.projectName.toUpperCase(),
              style: TextStyle(
                color: AppTheme.secondary.withOpacity(0.4),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _services.map((svc) {
                final isSelected = _activeService == svc['id'];
                return GestureDetector(
                  onTap: () {
                    if (_activeService == svc['id']) return;
                    setState(() => _activeService = svc['id']!);
                    _loadLogs();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? AppTheme.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      svc['label']!,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : Colors.white30,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
        : _fetchedLogs.isEmpty
            ? _buildEmptyState()
            : _buildLogsList(),
    );
  }

  Widget _buildLogsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _fetchedLogs.length,
      itemBuilder: (context, index) {
        final log = _fetchedLogs[index];
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
                log['message'] ?? 'No message provided',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              if (log['detail'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  log['detail']!,
                  style: TextStyle(
                    color: AppTheme.secondary.withOpacity(0.5),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(delay: (index * 30).ms).slideY(begin: 0.05, end: 0);
      },
    );
  }

  Widget _buildEmptyState() {
    final String serviceName = _services.firstWhere((s) => s['id'] == _activeService)['label']!;
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
            'NO $serviceName LOGS',
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
              'No diagnostic entries recorded in the last 24 hours for $serviceName.',
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
}
