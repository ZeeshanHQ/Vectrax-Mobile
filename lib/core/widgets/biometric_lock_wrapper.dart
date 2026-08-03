import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/theme/app_theme.dart';

class BiometricLockWrapper extends StatefulWidget {
  final Widget child;
  const BiometricLockWrapper({super.key, required this.child});

  @override
  State<BiometricLockWrapper> createState() => _BiometricLockWrapperState();
}

class _BiometricLockWrapperState extends State<BiometricLockWrapper> with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isLocked = false;
  bool _isAuthenticating = false;
  
  // Track whether we should prompt the biometric dialog when the app resumes.
  // Set to true on cold-boot and when the app goes fully to background (paused).
  bool _shouldAuthenticateOnResume = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[BiometricLock] Lifecycle change: $state');
    
    if (state == AppLifecycleState.paused) {
      // App went to the background
      _shouldAuthenticateOnResume = true;
      if (!_isAuthenticating) {
        _lockApp();
      }
    } else if (state == AppLifecycleState.inactive) {
      // App lost focus (multitasking view or system dialog)
      if (!_isAuthenticating) {
        _lockApp();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App returned to foreground
      _checkBiometricLock();
    }
  }

  Future<void> _lockApp() async {
    final prefs = await SharedPreferences.getInstance();
    final isBiometricEnabled = prefs.getBool('face_id_enabled') ?? false;
    if (isBiometricEnabled) {
      setState(() {
        _isLocked = true;
      });
    }
  }

  Future<void> _checkBiometricLock() async {
    final prefs = await SharedPreferences.getInstance();
    final isBiometricEnabled = prefs.getBool('face_id_enabled') ?? false;
    
    if (isBiometricEnabled) {
      if (_shouldAuthenticateOnResume) {
        setState(() {
          _isLocked = true;
        });
        _authenticate();
      }
    } else {
      setState(() {
        _isLocked = false;
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() {
          _isLocked = false;
          _isAuthenticating = false;
          _shouldAuthenticateOnResume = false;
        });
        return;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Please authenticate to unlock Vectrax',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        setState(() {
          _isLocked = false;
          _shouldAuthenticateOnResume = false; // Successfully authenticated
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('[BiometricLock] Authentication error: $e');
    } finally {
      // Small delay before resetting authenticating state to prevent overlapping trigger runs
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Blurred background representing current app state snapshot
          Opacity(
            opacity: 0.15,
            child: widget.child,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: Colors.black.withOpacity(0.85),
            ),
          ),
          
          // Lock UI Screen
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock Icon inside premium circle glow
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withOpacity(0.08),
                    border: Border.all(
                      color: AppTheme.accent.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.accent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Vectrax is Secured',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Biometric authentication is required.',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 48),
                // Re-authenticate button
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () {
                      // Triggering manually always forces authentication attempt
                      _shouldAuthenticateOnResume = true;
                      _authenticate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'UNLOCK',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
