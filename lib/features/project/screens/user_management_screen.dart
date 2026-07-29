import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'dart:math';

class UserManagementScreen extends StatefulWidget {
  final String projectRef;
  final String projectName;

  const UserManagementScreen({super.key, required this.projectRef, required this.projectName});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final List<Map<String, dynamic>> _mockUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await ApiService().listUsers(widget.projectRef);
    if (mounted) {
      setState(() {
        _mockUsers.clear();
        for (var u in users) {
          _mockUsers.add({
            'id': u['id']?.toString() ?? 'unknown',
            'email': u['email'] ?? 'No email',
            'provider': u['raw_app_meta_data']?['provider'] ?? 'email',
            'created_at': u['created_at'] ?? DateTime.now().toIso8601String(),
            'last_sign_in': u['last_sign_in_at'] ?? u['updated_at'] ?? 'Never',
          });
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white24, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('USER MANAGEMENT',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 2),
            Text(widget.projectName.toUpperCase(),
                style: TextStyle(
                    color: AppTheme.secondary.withOpacity(0.5),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0)),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : _mockUsers.isEmpty 
          ? _buildEmptyState()
          : _buildUserList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.03),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.05),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.person_off_rounded,
              size: 64,
              color: AppTheme.accent.withOpacity(0.5),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .shimmer(duration: 3.seconds, color: AppTheme.accent.withOpacity(0.1))
           .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 2.seconds),
          const SizedBox(height: 32),
          Text(
            'NO USERS DISCOVERED',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
          Text(
            'Your identity cluster is currently empty.\nUsers will appear here as they join.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.secondary.withOpacity(0.5),
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 48),
          SupaButton(
            onPressed: _loadUsers,
            backgroundColor: AppTheme.surface,
            foregroundColor: Colors.white,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('SYNC DATA KERNEL'),
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      itemCount: _mockUsers.length,
      itemBuilder: (context, index) {
        final user = _mockUsers[index];
        final provider = user['provider'];
        
        IconData pIcon = Icons.email_rounded;
        Color pColor = AppTheme.accent;
        
        if (provider == 'google') { pIcon = Icons.g_mobiledata_rounded; pColor = Colors.redAccent; }
        else if (provider == 'github') { pIcon = Icons.code_rounded; pColor = Colors.white70; }
        else if (provider == 'apple') { pIcon = Icons.apple_rounded; pColor = Colors.white; }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: pColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pColor.withOpacity(0.1)),
                ),
                child: Icon(pIcon, color: pColor, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['email'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${user['id'].toString().toUpperCase().substring(0, 12)}... • SEEN ${user['last_sign_in'].toString().substring(0, 10)}',
                      style: TextStyle(
                        color: AppTheme.secondary.withOpacity(0.4),
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _showUserActions(user);
                },
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white24, size: 20),
              )
            ],
          ),
        ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.05, end: 0);
      },
    );
  }

  void _showUserActions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'], 
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildActionTile(Icons.shield_rounded, 'Revoke Session', Colors.orangeAccent),
            _buildActionTile(Icons.delete_forever_rounded, 'Delete User', AppTheme.error),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String label, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action restricted in management shell.'))
        );
      },
    );
  }
}
