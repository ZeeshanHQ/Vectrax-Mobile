// ============================================
// Supabase Pulse — Centralised Configuration
// ============================================
// All OAuth & API constants in one place.
// Values are loaded from environment variables.
// ============================================

const config = {
  // ── OAuth App Credentials ──────────────────
  // Obtained from: Supabase Dashboard → Org Settings → OAuth Apps
  clientId: process.env.SUPABASE_OAUTH_CLIENT_ID || '',
  clientSecret: process.env.SUPABASE_OAUTH_CLIENT_SECRET || '',

  // ── Mobile Deep Link Redirect URI ──────────
  // Must EXACTLY match what you set in the Supabase OAuth App settings
  redirectUri: process.env.SUPABASE_OAUTH_REDIRECT_URI || 'com.supabasepulse://login-callback',

  // ── Supabase Management API OAuth Endpoints ─
  authorizeUrl: 'https://api.supabase.com/v1/oauth/authorize',
  tokenUrl: 'https://api.supabase.com/v1/oauth/token',

  // ── Management API Base ─────────────────────
  managementApiBase: 'https://api.supabase.com/v1',
};

/**
 * Validates that all required config values are present.
 * Call this at startup to fail fast if .env is misconfigured.
 */
export function validateConfig() {
  const required = ['clientId', 'clientSecret', 'redirectUri'];
  const missing = required.filter((key) => !config[key]);

  if (missing.length > 0) {
    throw new Error(
      `[SupabasePulse] Missing required environment variables: ${missing.join(', ')}.\n` +
        'Copy .env.example to .env and fill in your Supabase OAuth credentials.'
    );
  }

  return true;
}

export default config;
