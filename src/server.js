// ============================================
// Supabase Pulse — Auth API Listener
// ============================================
// This is the endpoint your frontend partner (Flutter)
// will call after they get the 'code' from Supabase.
// ============================================

import { SupabaseManager, tokenStore, validateConfig } from './index.js';

/**
 * Handle the Token Exchange Request (POST)
 * 
 * Expectations from Flutter:
 *   JSON Body: { "code": "...", "state": "...", "codeVerifier": "..." }
 */
export async function handleAuthExchange(req, res) {
    try {
        // 1. Validate Config
        validateConfig();

        // 2. Parse Request Body
        // If you are using Express, it's req.body
        // If you are using native http, you'll need a body parser
        const { code, state, codeVerifier, redirectUri } = req.body;

        if (!code || !codeVerifier) {
            return res.status(400).json({ error: 'Missing code or codeVerifier' });
        }

        // 3. Verify State (Optional but recommended for security)
        // In a real app, you'd check this against a session or DB
        // console.log(`[Server] Received state: ${state}`);

        // 4. Exchange Code for Tokens
        const manager = new SupabaseManager();
        const tokens = await manager.exchangeCodeForTokens(code, codeVerifier, redirectUri);

        // 5. Securely Store Tokens
        const parts = tokens.access_token.split('.');
        const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
        const userId = payload.sub;
        await tokenStore.saveTokens(userId, tokens);

        console.log(`[Server] Secure identity exchange complete for user: ${userId}`);

        // 7. Return Success to Mobile
        const email = 'user@supabase.com';
        const displayName = 'Supabase Developer';

        return res.status(200).json({
            message: 'Authentication successful',
            expires_at: Date.now() + tokens.expires_in * 1000,
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            user: {
                email: email,
                name: displayName
            }
        });

    } catch (error) {
        console.error(`[Server] Auth Error: ${error.message}`);
        return res.status(500).json({ error: error.message });
    }
}

// ── Simple Express Example (if running as a server) ───────────
/*
import express from 'express';
const app = express();
app.use(express.json());

app.post('/api/auth/exchange', handleAuthExchange);

app.listen(3000, () => console.log('Pulse API listening on port 3000'));
*/
