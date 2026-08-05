class AppConfig {
  /// The Title of the app
  static const String appName = 'Vectrax';

  /// OAuth Client ID
  static const String clientId = '706ae5db-0e85-4cf2-b35c-439639d59eca';

  /// Redirect URI - Must match Supabase Dashboard
  static const String redirectUri =
      'https://api.vectrax.astraventa.com/login-callback';

  /// PKCE State - Should ideally be random, but matching backend for now
  static const String oauthState = 'NxLw-3oYUjcX2ffteMvnFg';

  /// PKCE Code Verifier
  static const String codeVerifier =
      'vUT8kiRPZLDjtz_b1twjsoGNdyF547VKIiQNyWcz8zc';

  /// Backend API Base URL
  /// For local testing via tunnel, replace this with your localtunnel/ngrok URL
  static const String apiBaseUrl =
      'https://api.vectrax.astraventa.com';

  /// Supabase OAuth Authorize Endpoint
  static const String authorizeUrl =
      'https://api.supabase.com/v1/oauth/authorize';

  /// Google Cloud Console Web Client ID (needed for 100% native in-app login)
  /// Paste your Google Web Client ID here
  static const String googleWebClientId =
      '1013345806244-onq0k915fgacd3iqa9k4hpomk4kk7qdd.apps.googleusercontent.com';

  /// Full pre-built Login URL
  static String get loginUrl => '$authorizeUrl'
      '?client_id=$clientId'
      '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
      '&response_type=code'
      '&code_challenge=IMBeZBPJ_ffAgrHJFVmrJztf12uA6_zexz5glhEw_gY'
      '&code_challenge_method=S256'
      '&state=$oauthState';
}
