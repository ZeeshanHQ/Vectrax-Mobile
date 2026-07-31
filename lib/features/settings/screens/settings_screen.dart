import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supa_app/features/auth/screens/login_screen.dart';
import 'package:supa_app/features/feedback/screens/feedback_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supa_app/features/auth/screens/connect_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _faceIdEnabled = true;
  bool _notificationsEnabled = true;
  bool _hapticsEnabled = true;
  Map<String, dynamic> _userProfile = {'email': null, 'name': null};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load from local first for instant UI
    if (mounted) {
      setState(() {
        _faceIdEnabled = prefs.getBool('face_id_enabled') ?? false;
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _hapticsEnabled = prefs.getBool('haptics_enabled') ?? true;
      });
    }

    // 2. Sync from Cloud DB
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final client = Supabase.instance.client;
        final response = await client
            .from('user_settings')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null && mounted) {
          setState(() {
            _faceIdEnabled = response['biometric_access'] ?? _faceIdEnabled;
            _notificationsEnabled = response['notifications_enabled'] ?? _notificationsEnabled;
            _hapticsEnabled = response['haptic_feedback'] ?? _hapticsEnabled;
          });
          
          // Update local cache
          await prefs.setBool('face_id_enabled', _faceIdEnabled);
          await prefs.setBool('notifications_enabled', _notificationsEnabled);
          await prefs.setBool('haptics_enabled', _hapticsEnabled);
        }
      }
    } catch (e) {
      debugPrint('[Settings] Cloud sync error: $e');
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    // Sync to Cloud
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final client = Supabase.instance.client;
        final updates = <String, dynamic>{'user_id': user.id};
        
        if (key == 'face_id_enabled') updates['biometric_access'] = value;
        if (key == 'notifications_enabled') updates['notifications_enabled'] = value;
        if (key == 'haptics_enabled') updates['haptic_feedback'] = value;

        await client.from('user_settings').upsert(updates);
      }
    } catch (e) {
      debugPrint('[Settings] Cloud save error: $e');
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    // If turning off, just off and save
    if (!value) {
      setState(() => _faceIdEnabled = false);
      await _saveSetting('face_id_enabled', false);
      if (_hapticsEnabled) HapticFeedback.lightImpact();
      return;
    }

    // If turning on, authenticate first
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.surface,
              content: Text(
                  'Biometrics not configured or supported on this device',
                  style: TextStyle(color: Colors.white70)),
            ),
          );
        }
        return;
      }

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Enable Biometric Lock for Vectrax',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        setState(() => _faceIdEnabled = true);
        await _saveSetting('face_id_enabled', true);
        if (_hapticsEnabled) HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('[Settings] Biometric error: $e');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _saveSetting('notifications_enabled', value);
    if (_hapticsEnabled) HapticFeedback.lightImpact();
  }

  Future<void> _toggleHaptics(bool value) async {
    setState(() => _hapticsEnabled = value);
    await _saveSetting('haptics_enabled', value);
    if (value) HapticFeedback.vibrate();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _authService.getUserProfile();
    if (mounted) {
      setState(() => _userProfile = profile);
    }
  }

  String get _email => _userProfile['email'] ?? 'Synchronizing...';
  String get _name => _userProfile['name'] ?? '';

  Future<void> _handleSignOut() async {
    if (_hapticsEnabled) HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.05))),
        title: const Text('Sign Out',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        content: const Text(
            'Are you sure you want to sign out of your account?',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL',
                  style: TextStyle(
                      color: Colors.white24,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SIGN OUT',
                  style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleDisconnectSupabase() async {
    if (_hapticsEnabled) HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.05))),
        title: const Text('Disconnect Supabase',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        content: const Text(
            'This will disconnect your currently authorized Supabase account and clear all synced projects. You will need to re-authenticate to use the cockpit.',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL',
                  style: TextStyle(
                      color: Colors.white24,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DISCONNECT',
                  style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (_hapticsEnabled) HapticFeedback.mediumImpact();
      
      // 1. Clear local secure storage
      const storage = FlutterSecureStorage();
      await storage.delete(key: 'supabase_access_token');
      await storage.delete(key: 'supabase_refresh_token');

      // 2. Clear from Cloud DB
      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId != null) {
          await client.from('supabase_connections').delete().eq('user_id', userId);
        }
      } catch (e) {
        debugPrint('[Settings] Failed to delete connection row: $e');
      }

      // 3. Pop settings and redirect to ConnectScreen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ConnectScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showEditProfile() {
    if (_hapticsEnabled) HapticFeedback.mediumImpact();
    final nameController = TextEditingController(text: _name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('EDIT PROFILE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white24),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TextField(
                autofocus: true,
                controller: nameController,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'DISPLAY NAME',
                  labelStyle: TextStyle(
                      color: AppTheme.accent.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2),
                  enabledBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.05))),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.accent)),
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      color: AppTheme.accent, size: 20),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: SupaButton(
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      await _authService.updateUserProfile(
                          name: nameController.text.trim());
                      await _loadUserProfile();
                      if (mounted) Navigator.pop(context);
                      if (_hapticsEnabled) HapticFeedback.mediumImpact();
                    }
                  },
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  child: const Center(
                      child: Text('SAVE CHANGES',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white24, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('SETTINGS',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSection(),
            const SizedBox(height: 48),
            _buildSectionLabel('SECURITY & ACCESS'),
            const SizedBox(height: 16),
            _buildSettingsCard([
              _buildSwitchRow(
                label: 'Biometric Access',
                subtitle: 'Secure app with FaceID / TouchID',
                icon: Icons.face_rounded,
                value: _faceIdEnabled,
                onChanged: _toggleBiometrics,
              ),
              const Divider(color: Colors.white10, height: 1),
              _buildSwitchRow(
                label: 'Push Notifications',
                subtitle: 'Critical project health alerts',
                icon: Icons.notifications_active_rounded,
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionLabel('SYSTEM PREFERENCES'),
            const SizedBox(height: 16),
            _buildSettingsCard([
              _buildSwitchRow(
                label: 'Haptic Feedback',
                subtitle: 'Tactile vibration clicks. Note: System touch vibrations must be enabled in Android settings.',
                icon: Icons.vibration_rounded,
                value: _hapticsEnabled,
                onChanged: _toggleHaptics,
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionLabel('HELP & SUPPORT'),
            const SizedBox(height: 16),
            _buildSettingsCard([
              _buildSettingsRow(
                label: 'Report an Issue',
                icon: Icons.bug_report_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                  );
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              _buildSettingsRow(
                label: 'Documentation',
                icon: Icons.menu_book_rounded,
                onTap: () {
                  if (_hapticsEnabled) HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF0F0F0F),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: Colors.white.withOpacity(0.05))),
                      content: const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              color: AppTheme.accent, size: 16),
                          SizedBox(width: 12),
                          Text('Pulse Docs | Coming soon!',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(24),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              _buildSettingsRow(
                label: 'Disconnect Supabase',
                icon: Icons.link_off_rounded,
                color: Colors.orangeAccent,
                onTap: _handleDisconnectSupabase,
              ),
              const Divider(color: Colors.white10, height: 1),
              _buildSettingsRow(
                label: 'Sign Out',
                icon: Icons.logout_rounded,
                color: Colors.redAccent,
                onTap: _handleSignOut,
              ),
            ]),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
          color: Colors.white60,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 2),
    );
  }

  Widget _buildSettingsRow({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final activeColor = color ?? Colors.white24;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color != null ? color.withOpacity(0.08) : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: activeColor, size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: color != null ? color : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            Icon(Icons.chevron_right_rounded, color: color != null ? color.withOpacity(0.3) : Colors.white10),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    final rawName = _userProfile['name']?.toString() ?? '';
    final hasName = rawName.isNotEmpty && rawName != 'Vectrax User';
    final email = _userProfile['email']?.toString() ?? '';
    
    final displayName = hasName
        ? rawName.toUpperCase()
        : 'SET DISPLAY NAME';
    final initials = hasName
        ? rawName.substring(0, 1).toUpperCase()
        : (email.isNotEmpty ? email.substring(0, 1).toUpperCase() : 'U');
    final avatarUrl = _userProfile['avatarUrl'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF070707),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 40,
              spreadRadius: -10),
        ],
      ),
      child: InkWell(
        onTap: _showEditProfile,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accent.withOpacity(0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: Color(0xFF0F0F0F), shape: BoxShape.circle),
                  child: Center(
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(avatarUrl,
                                width: 64, height: 64, fit: BoxFit.cover))
                        : Text(initials,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: Colors.white,
                                letterSpacing: -1)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(displayName,
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: hasName ? Colors.white : Colors.white54,
                                letterSpacing: -0.5)),
                        if (!hasName) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_rounded, color: AppTheme.accent, size: 14),
                        ]
                      ],
                    ),
                  ),
                  if (email.isNotEmpty)
                    Text(email,
                        style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_userProfile['isPremium'] == true) ? AppTheme.accent.withOpacity(0.08) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: (_userProfile['isPremium'] == true) ? AppTheme.accent.withOpacity(0.2) : Colors.white12),
                    ),
                    child: Text(
                      (_userProfile['isPremium'] == true) ? 'VECTRAX PRO 👑' : 'VECTRAX FREE',
                      style: TextStyle(
                          color: (_userProfile['isPremium'] == true) ? AppTheme.accent : Colors.white30,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
                onPressed: _showEditProfile,
                icon: const Icon(Icons.edit_rounded, color: AppTheme.accent, size: 20)),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF030303),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(children: children),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSwitchRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white24, size: 20),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white10,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
            activeTrackColor: AppTheme.accent.withOpacity(0.2),
          ),
        ],
      ),
    );
  }
}
