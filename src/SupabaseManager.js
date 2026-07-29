// ============================================
// Supabase Pulse — SupabaseManager
// ============================================
// Modular class that encapsulates all OAuth 2.1
// PKCE logic for the Supabase Management API.
//
// Endpoints (official docs):
//   Authorize → GET  https://api.supabase.com/v1/oauth/authorize
//   Token     → POST https://api.supabase.com/v1/oauth/token
// ============================================

import crypto from 'node:crypto';
import config from './config.js';
import { SupabaseManagementAPI } from 'supabase-management-js';

export default class SupabaseManager {
    // ┌──────────────────────────────────────────┐
    // │  1. PKCE GENERATION                      │
    // └──────────────────────────────────────────┘

    /**
     * Generate a PKCE code_verifier and code_challenge (S256).
     *
     * - code_verifier : 43-char cryptographically random string (base64url)
     * - code_challenge: SHA-256 hash of the verifier, base64url-encoded
     *
     * Spec: RFC 7636 §4.1 / §4.2
     *
     * @returns {{ codeVerifier: string, codeChallenge: string }}
     */
    generatePKCE() {
        // 32 random bytes → 43 base64url chars (after stripping padding)
        const codeVerifier = this.#base64url(crypto.randomBytes(32));

        // SHA-256 hash of the verifier → base64url
        const hash = crypto.createHash('sha256').update(codeVerifier).digest();
        const codeChallenge = this.#base64url(hash);

        return { codeVerifier, codeChallenge };
    }

    // ┌──────────────────────────────────────────┐
    // │  2. AUTHORIZATION URL GENERATOR          │
    // └──────────────────────────────────────────┘

    /**
     * Build the full Supabase OAuth authorization URL.
     *
     * This URL should be handed to the Frontend developer so the
     * mobile app can open it in the system browser / in-app browser.
     *
     * After the user consents, Supabase redirects to:
     *   com.supabasepulse://login-callback?code=<AUTH_CODE>&state=<STATE>
     *
     * @param {object}  options
     * @param {string}  [options.clientId]       - Override config CLIENT_ID
     * @param {string}  [options.codeChallenge]  - Pre-generated challenge (pass-through from generatePKCE)
     * @param {string}  [options.state]          - Opaque state for CSRF protection
     * @param {string}  [options.organizationSlug] - Pre-select an org (optional)
     * @param {string}  [options.redirectUri]    - Override config REDIRECT_URI
     *
     * @returns {{ url: string, codeVerifier: string, codeChallenge: string, state: string }}
     */
    getAuthorizationUrl(options = {}) {
        // Generate PKCE pair if not provided
        let codeVerifier, codeChallenge;
        if (options.codeChallenge) {
            codeChallenge = options.codeChallenge;
            codeVerifier = null; // Caller already has it
        } else {
            const pkce = this.generatePKCE();
            codeVerifier = pkce.codeVerifier;
            codeChallenge = pkce.codeChallenge;
        }

        // Generate state for CSRF protection if not provided
        const state = options.state || this.#base64url(crypto.randomBytes(16));

        // Build the URL
        const url = new URL(config.authorizeUrl);
        url.searchParams.set('client_id', options.clientId || config.clientId);
        url.searchParams.set('redirect_uri', options.redirectUri || config.redirectUri);
        url.searchParams.set('response_type', 'code');
        url.searchParams.set('code_challenge', codeChallenge);
        url.searchParams.set('code_challenge_method', 'S256');
        url.searchParams.set('state', state);

        // Optional: pre-select org
        if (options.organizationSlug) {
            url.searchParams.set('organization_slug', options.organizationSlug);
        }

        return {
            url: url.toString(),
            codeVerifier,
            codeChallenge,
            state,
        };
    }

    // ┌──────────────────────────────────────────┐
    // │  3. TOKEN EXCHANGE HANDLER               │
    // └──────────────────────────────────────────┘

    /**
     * Exchange an authorization code for access + refresh tokens.
     *
     * Called after the mobile app intercepts the deep link callback:
     *   com.supabasepulse://login-callback?code=<AUTH_CODE>&state=<STATE>
     *
     * The Frontend passes the `code` to this function via a secure bridge.
     *
     * @param {string} code         - Authorization code from the redirect
     * @param {string} codeVerifier - The PKCE code_verifier generated earlier
     * @param {string} [redirectUri] - Override config REDIRECT_URI (must match the one used in auth URL)
     *
     * @returns {Promise<{
     *   access_token: string,
     *   refresh_token: string,
     *   expires_in: number,
     *   token_type: string
     * }>}
     *
     * @throws {Error} If the token exchange fails
     */
    async exchangeCodeForTokens(code, codeVerifier, redirectUri = null) {
        if (!code) throw new Error('[SupabaseManager] Authorization code is required.');
        if (!codeVerifier) throw new Error('[SupabaseManager] code_verifier is required for PKCE flow.');

        // Build Basic auth header: base64(client_id:client_secret)
        const credentials = btoa(`${config.clientId}:${config.clientSecret}`);

        const response = await fetch(config.tokenUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                Accept: 'application/json',
                Authorization: `Basic ${credentials}`,
            },
            body: new URLSearchParams({
                grant_type: 'authorization_code',
                code,
                redirect_uri: redirectUri || config.redirectUri,
                code_verifier: codeVerifier,
            }),
        });

        if (!response.ok) {
            const errorBody = await response.text();
            throw new Error(
                `[SupabaseManager] Token exchange failed (${response.status}): ${errorBody}`
            );
        }

        const tokens = await response.json();

        // Log (non-sensitive) metadata in dev
        console.log(
            `[SupabaseManager] ✅ Token exchange successful — expires_in: ${tokens.expires_in}s, type: ${tokens.token_type}`
        );

        return tokens;
    }

    // ┌──────────────────────────────────────────┐
    // │  4. TOKEN REFRESH HANDLER                │
    // └──────────────────────────────────────────┘

    /**
     * Refresh an expired access_token using a valid refresh_token.
     *
     * Uses the same /v1/oauth/token endpoint with grant_type=refresh_token.
     *
     * @param {string} refreshToken - A valid refresh_token from a previous exchange
     *
     * @returns {Promise<{
     *   access_token: string,
     *   refresh_token: string,
     *   expires_in: number,
     *   token_type: string
     * }>}
     *
     * @throws {Error} If the user revoked access or the token is invalid
     */
    async refreshAccessToken(refreshToken) {
        if (!refreshToken) throw new Error('[SupabaseManager] refresh_token is required.');

        const credentials = btoa(`${config.clientId}:${config.clientSecret}`);

        const response = await fetch(config.tokenUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                Accept: 'application/json',
                Authorization: `Basic ${credentials}`,
            },
            body: new URLSearchParams({
                grant_type: 'refresh_token',
                refresh_token: refreshToken,
            }),
        });

        if (!response.ok) {
            const errorBody = await response.text();
            throw new Error(
                `[SupabaseManager] Token refresh failed (${response.status}): ${errorBody}`
            );
        }

        const tokens = await response.json();

        console.log(
            `[SupabaseManager] 🔄 Token refreshed — expires_in: ${tokens.expires_in}s`
        );

        return tokens;
    }

    // ┌──────────────────────────────────────────┐
    // │  5. MANAGEMENT API CLIENT                │
    // └──────────────────────────────────────────┘

    /**
     * Returns an initialised supabase-management-js client.
     *
     * Usage:
     *   const client = manager.getManagementClient(tokens.access_token);
     *   const projects = await client.getProjects();
     *
     * @param {string} accessToken - A valid access_token
     * @returns {import('supabase-management-js').SupabaseManagementAPI}
     */
    getManagementClient(accessToken) {
        return new SupabaseManagementAPI({ accessToken });
    }

    // ┌──────────────────────────────────────────┐
    // │  PRIVATE HELPERS                         │
    // └──────────────────────────────────────────┘

    /**
     * Encode a Buffer to base64url (RFC 4648 §5).
     * Strips padding, replaces +→- and /→_
     *
     * @param {Buffer} buffer
     * @returns {string}
     */
    #base64url(buffer) {
        return buffer
            .toString('base64')
            .replace(/\+/g, '-')
            .replace(/\//g, '_')
            .replace(/=+$/, '');
    }
}
