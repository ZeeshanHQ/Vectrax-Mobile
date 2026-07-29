import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supa_app/core/widgets/pincode_input.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supa_app/core/widgets/success_check.dart';
import 'package:supa_app/features/auth/screens/connect_screen.dart';
import 'package:supa_app/features/auth/screens/syncing_screen.dart';
import 'package:supa_app/core/widgets/main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  bool _isConnecting = false;
  bool _showSuccess = false;
  String? _errorMessage;

  // Resend Timer
  Timer? _resendTimer;
  int _resendSeconds = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendSeconds > 0) {
            _resendSeconds--;
          } else {
            _canResend = true;
            _resendTimer?.cancel();
          }
        });
      }
    });
  }

  // ─── Social Login ─────────────────────────────────────────────────────────

  Future<void> _handleSocialConnect(String provider) async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final bool success;
      if (provider == 'Google') {
        success = await _authService.signInWithGoogle();
      } else if (provider == 'GitHub') {
        success = await _authService.signInWithGitHub();
      } else {
        success = false;
      }
      if (!mounted) return;

      if (success) {
        // ENSURE PROFILE EXISTS in Cloud Store
        await _authService.ensureProfileExists();

        if (mounted) {
          setState(() {
            _isConnecting = false;
            _showSuccess = true;
          });
          await Future.delayed(1.5.seconds);
          if (mounted) {
            final token = await _authService.getAccessToken();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => token != null
                      ? const SyncingScreen()
                      : ConnectScreen(userEmail: _emailController.text.trim()),
                ),
              );
            }
          }
        }
      } else {
        setState(() {
          _isConnecting = false;
          _errorMessage =
              '$provider sign-in was cancelled or failed. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = 'Sign-in failed: ${e.toString()}';
        });
      }
    }
  }

  // ─── Email OTP Flow ───────────────────────────────────────────────────────

  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Enter a valid email address');
      return;
    }

    final start = DateTime.now();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.sendOtp(email);
      if (mounted) {
        if (success) {
          setState(() {
            _isOtpSent = true;
          });
          _startResendTimer();
        } else {
          setState(() =>
              _errorMessage = 'Failed to send code. Is the backend live?');
        }
      }
    } finally {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(start);
      final minDuration = const Duration(milliseconds: 800);
      if (elapsed < minDuration) {
        await Future.delayed(minDuration - elapsed);
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    final email = _emailController.text.trim();
    final code = _otpController.text.trim();

    if (code.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code');
      return;
    }

    final start = DateTime.now();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.verifyOtp(email, code);
      if (mounted) {
        if (success) {
          // ENSURE PROFILE EXISTS in Cloud Store
          await _authService.ensureProfileExists();

          if (mounted) {
            setState(() => _showSuccess = true);
            await Future.delayed(1.seconds);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 600),
                  pageBuilder: (_, __, ___) =>
                      ConnectScreen(userEmail: _emailController.text.trim()),
                  transitionsBuilder: (_, animation, __, child) => FadeTransition(
                    opacity: Tween<double>(begin: 0, end: 1).animate(
                      CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic),
                    ),
                    child: child,
                  ),
                ),
              );
            }
          }
        } else {
          setState(() => _errorMessage = 'Invalid or expired code.');
        }
      }
    } finally {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(start);
      final minDuration = const Duration(milliseconds: 800);
      if (elapsed < minDuration) {
        await Future.delayed(minDuration - elapsed);
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Build Components ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light, // Light icons on dark background
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: MediaQuery.of(context).size.height),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // App Logo & Brand Name Top Section
                  Container(
                    height: MediaQuery.of(context).size.height * 0.35,
                    width: double.infinity,
                    color: AppTheme.background,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/app_logo.png',
                            width: 80,
                            height: 80,
                          )
                              .animate(target: _isOtpSent ? 1 : 0)
                              .scaleXY(
                                  end:
                                      0.8) // Shrink slightly when moving to OTP
                              .animate()
                              .fadeIn(duration: 800.ms)
                              .scale(
                                  begin: const Offset(0.5, 0.5),
                                  end: const Offset(1, 1),
                                  curve: Curves.elasticOut),
                          const SizedBox(height: 16),
                          Text(
                            'VECTRAX',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.0,
                            ),
                          ).animate().fadeIn(delay: 500.ms),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: const BoxDecoration(
                        color: AppTheme.background, // Match dark theme
                      ),
                      child: _showSuccess
                          ? const Center(
                              child: SuccessCheck(label: 'AUTHENTICATED'))
                          : _isOtpSent
                              ? _buildOtpView()
                              : _buildInitialView(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'GET STARTED',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 8),
        Text(
          'Sign in or create your account in seconds',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 48),

        // Social Buttons
        _buildSocialButton(
          label: 'Continue with Google',
          iconPath: 'assets/images/google.png',
          onPressed: () => _handleSocialConnect('Google'),
        ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1, end: 0),

        const SizedBox(height: 12),

        _buildSocialButton(
          label: 'Continue with GitHub',
          iconPath: 'assets/images/github.png',
          onPressed: () => _handleSocialConnect('GitHub'),
        ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.1, end: 0),

        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR EMAIL',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white30)),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
          ],
        ).animate().fadeIn(delay: 1.seconds),

        const SizedBox(height: 32),

        _buildTextField(
          controller: _emailController,
          hintText: 'Work email address',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ).animate().fadeIn(delay: 1.2.seconds),

        const SizedBox(height: 16),

        SupaButton(
          isLoading: _isLoading,
          onPressed: _handleSendOtp,
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.black,
          child: Center(
              child: Text('CONTINUE',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 13))),
        ).animate().fadeIn(delay: 1.4.seconds),

        if (_errorMessage != null) _buildErrorMessage(),

        const Spacer(),

        _buildFooter(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildOtpView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'VERIFYING',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 48),
        GlowingPinCodeInput(
          length: 6,
          controller: _otpController,
          baseColor: AppTheme.surface,
          glowingColor: AppTheme.accent,
          textColor: Colors.white,
          onChanged: (_) {},
          onCompleted: _handleVerifyOtp,
        ),
        const SizedBox(height: 16),
        SupaButton(
          isLoading: _isLoading,
          onPressed: _handleVerifyOtp,
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.black,
          child: Center(
              child: Text('VERIFY CODE',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 13))),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code? ",
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
            ),
            if (_canResend)
              TextButton(
                onPressed: _handleSendOtp,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: Text(
                  'Resend Now',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              )
            else
              Text(
                'Resend in ${_resendSeconds}s',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white30),
              ),
          ],
        ),
        if (_errorMessage != null) _buildErrorMessage(),
        const Spacer(),
        _buildFooter(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSocialButton(
      {required String label,
      required String iconPath,
      required VoidCallback onPressed}) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: _isConnecting ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            label.contains('GitHub')
                ? Container(
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: Image.asset(iconPath, width: 16, height: 16),
                  )
                : Image.asset(iconPath, width: 20, height: 20),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          counterText: '',
          hintText: hintText,
          hintStyle:
              TextStyle(color: Colors.white30, fontWeight: FontWeight.w400),
          prefixIcon: Icon(icon, color: Colors.white30),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13))),
          ],
        ),
      ),
    ).animate().shake();
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'An Astraventa Intelligent System',
          style: GoogleFonts.inter(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
