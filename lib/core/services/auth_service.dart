import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supa_app/core/config/app_config.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ─── Social OAuth (Google / GitHub) ────────────────────────────────────────

  /// Sign in with Google using native Android/iOS Google Sign-In bottom sheet modal.
  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[Auth] Google Sign-In cancelled by user');
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken != null) {
        final AuthResponse res = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        return res.session != null;
      } else {
        debugPrint('[Auth] Google ID Token missing, falling back to web OAuth');
        return _signInWithProvider(OAuthProvider.google);
      }
    } catch (e) {
      debugPrint('[Auth] Native Google Sign-In error: $e. Falling back to web OAuth');
      return _signInWithProvider(OAuthProvider.google);
    }
  }

  /// Sign in with GitHub via Supabase OAuth.
  Future<bool> signInWithGitHub() async {
    return _signInWithProvider(OAuthProvider.github);
  }

  /// Generic Supabase social OAuth flow.
  Future<bool> _signInWithProvider(OAuthProvider provider) async {
    try {
      // Supabase opens the browser. After the user approves,
      // the provider redirects to the Supabase callback, which then
      // issues our deep link: com.supabasepulse://login-callback
      await _supabase.auth.signInWithOAuth(
        provider,
        redirectTo: 'com.supabasepulse://login-callback',
        authScreenLaunchMode: LaunchMode.inAppWebView,
      );

      // Wait for the auth state to update (up to 3 minutes)
      final completer = Completer<bool>();
      late final StreamSubscription<AuthState> sub;
      sub = _supabase.auth.onAuthStateChange.listen((event) {
        if (event.event == AuthChangeEvent.signedIn || event.session != null) {
          sub.cancel();
          if (!completer.isCompleted) completer.complete(true);
        }
      });

      // Timeout safety: if user closes browser without signing in
      Future.delayed(const Duration(minutes: 3), () {
        sub.cancel();
        if (!completer.isCompleted) completer.complete(false);
      });

      return completer.future;
    } catch (e) {
      debugPrint('OAuth signIn error: $e');
      return false;
    }
  }

  /// Ensures a profile row exists for the current user. Safe to call multiple times.
  Future<void> ensureProfileExists() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            'Vectrax User',
        'avatar_url': user.userMetadata?['avatar_url'] ??
            user.userMetadata?['picture'],
        'is_premium': false,
        'architect_daily_limit': 3,
        'architect_credits_used': 0,
        'last_credit_reset': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      debugPrint('[Auth] ✅ Profile ensured for ${user.email}');
    } catch (e) {
      debugPrint('[Auth] ⚠️ Profile upsert error (non-fatal): $e');
    }
  }

  // ─── Custom OTP Flow (Resend API & Database Store) ─────────────────────────

  /// Sends a 6-digit verification code via our custom Resend API backend.
  Future<bool> sendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/auth/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      debugPrint('[Auth] Custom OTP Send failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[Auth] Custom OTP Send exception: $e');
      return false;
    }
  }

  /// Verifies the code on our backend and establishes a native Supabase session.
  Future<bool> verifyOtp(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/auth/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final accessToken = body['token'] as String?;
          final refreshToken = body['refreshToken'] as String?;

          if (refreshToken != null) {
            // Manually set the session in Supabase SDK using the refresh token
            final AuthResponse authResp = await _supabase.auth.setSession(
              refreshToken,
            );

            if (authResp.session != null) {
              await _storage.write(key: 'user_email', value: email);
              if (accessToken != null) {
                await _storage.write(key: 'vectrax_access_token', value: accessToken);
              }
              await _storage.write(key: 'vectrax_refresh_token', value: refreshToken);
              await ensureProfileExists(); // Ensure database profile row exists
              return true;
            }
          }
        }
      }
      debugPrint('[Auth] Custom OTP Verification failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[Auth] Custom OTP Verification exception: $e');
      return false;
    }
  }

  Future<bool> restoreProject(String ref) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/restore'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) return true;

      // Log error for debugging
      debugPrint('Restore failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Restore exception: $e');
      return false;
    }
  }

  Future<bool> pauseProject(String ref) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/pause'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Pause exception: $e');
      return false;
    }
  }

  Future<bool> restartDatabase(String ref) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/restart'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Restart exception: $e');
      return false;
    }
  }

  // ─── Token helpers ───────────────────────────────────────────────────────────

  Future<String?> getAccessToken() => _storage.read(key: 'vectrax_access_token');

  Future<String?> getRefreshToken() => _storage.read(key: 'vectrax_refresh_token');

  Future<bool> isSupabaseConnected() async {
    final token = await _storage.read(key: 'supabase_access_token');
    return token != null;
  }

  // ─── Legacy/PAT helpers ──────────────────────────────────────────────────────

  Future<void> savePAT(String token) =>
      _storage.write(key: 'supabase_pat', value: token);

  Future<String?> getPAT() => _storage.read(key: 'supabase_pat');

  Future<Map<String, dynamic>> getUserProfile() async {
    final user = currentUser;
    if (user == null) {
      return {
        'email': null,
        'name': null,
        'avatarUrl': null,
        'isPremium': false,
        'dailyLimit': 3,
        'creditsUsed': 0
      };
    }

    String? email = user.email;
    String? name;
    String? avatarUrl;
    bool isPremium = false;
    int dailyLimit = 3;
    int creditsUsed = 0;
    DateTime? lastReset;

    try {
      // 1. Try fetching from the new Cloud DB profiles table
      final response = await _supabase
          .from('profiles')
          .select(
              'full_name, avatar_url, is_premium, architect_daily_limit, architect_credits_used, last_credit_reset')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        name = response['full_name'] as String?;
        avatarUrl = response['avatar_url'] as String?;
        isPremium = response['is_premium'] as bool? ?? false;
        dailyLimit = response['architect_daily_limit'] as int? ?? 3;
        creditsUsed = response['architect_credits_used'] as int? ?? 0;
        final resetStr = response['last_credit_reset'] as String?;
        if (resetStr != null) lastReset = DateTime.parse(resetStr);

        // Check for calendar date reset (refills immediately on new day)
        if (lastReset != null) {
          final now = DateTime.now();
          final resetLocal = lastReset.toLocal();
          final nowLocal = now.toLocal();
          
          if (nowLocal.year != resetLocal.year || 
              nowLocal.month != resetLocal.month || 
              nowLocal.day != resetLocal.day) {
            // Reset credits in DB
            await _supabase.from('profiles').update({
              'architect_credits_used': 0,
              'last_credit_reset': now.toIso8601String(),
            }).eq('id', user.id);
            creditsUsed = 0;
          }
        }
      } else {
        // AUTO-CREATE PROFILE if missing
        debugPrint('[Auth] Profile missing for ${user.id}, creating baseline...');
        final baseline = {
          'id': user.id,
          'email': email,
          'full_name': 'Vectrax User',
          'is_premium': false,
          'architect_daily_limit': 3,
          'architect_credits_used': 0,
          'last_credit_reset': DateTime.now().toIso8601String(),
        };
        await _supabase.from('profiles').upsert(baseline);
        name = 'Vectrax User';
      }
    } catch (e) {
      debugPrint('[Auth] Profile fetch/create error: $e');
    }

    // 2. Fallback to local storage or metadata if DB fetch failed or name is null
    if (name == null || name.isEmpty || name == 'Vectrax User') {
      name = await _storage.read(key: 'user_name');
      avatarUrl ??= await _storage.read(key: 'user_avatar_url');

      if (user.userMetadata != null) {
        final meta = user.userMetadata!;
        name ??= meta['full_name']?.toString() ??
            meta['name']?.toString() ??
            meta['user_name']?.toString();
        avatarUrl ??=
            meta['avatar_url']?.toString() ?? meta['picture']?.toString();
      }
    }

    return {
      'email': email,
      'name': name ?? 'Vectrax User',
      'avatarUrl': avatarUrl,
      'isPremium': isPremium,
      'dailyLimit': dailyLimit,
      'creditsUsed': creditsUsed,
    };
  }

  Future<bool> deductArchitectCredit() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final profile = await _supabase
          .from('profiles')
          .select('architect_credits_used, is_premium')
          .eq('id', user.id)
          .single();

      bool isPremium = profile['is_premium'] as bool? ?? false;
      if (isPremium) return true; // Unlimited for Pro

      int currentUsed = profile['architect_credits_used'] as int? ?? 0;

      await _supabase.from('profiles').update({
        'architect_credits_used': currentUsed + 1,
      }).eq('id', user.id);

      return true;
    } catch (e) {
      debugPrint('[Auth] Credit deduction error: $e');
      return false;
    }
  }

  Future<bool> upgradeToPremium() async {
    final user = currentUser;
    if (user == null) return false;
    try {
      await _supabase.from('profiles').update({
        'is_premium': true,
        'architect_daily_limit': 100,
      }).eq('id', user.id);
      return true;
    } catch (e) {
      debugPrint('[Auth] Upgrade error: $e');
      return false;
    }
  }

  Future<void> updateUserProfile({String? name, String? avatarUrl}) async {
    final user = currentUser;
    if (user == null) return;

    try {
      // Update Cloud DB
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (name != null) updates['full_name'] = name;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _supabase.from('profiles').update(updates).eq('id', user.id);

      // Mirror to local storage for offline/fast access
      if (name != null) await _storage.write(key: 'user_name', value: name);
      if (avatarUrl != null) {
        await _storage.write(key: 'user_avatar_url', value: avatarUrl);
      }
    } catch (e) {
      debugPrint('[Auth] Profile update error: $e');
    }
  }

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? get currentUser => _supabase.auth.currentUser;

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _storage.deleteAll();
  }
}
