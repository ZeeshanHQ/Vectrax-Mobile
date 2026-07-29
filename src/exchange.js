// ============================================
// Supabase Pulse — Token Exchange Utility
// ============================================
// Use this script once your frontend partner
// sends you the 'code' from the redirect.
//
// Usage:
//   node --env-file=.env src/exchange.js <AUTH_CODE> <CODE_VERIFIER> [REDIRECT_URI]
// ============================================

import { SupabaseManager, tokenStore, validateConfig } from './index.js';

async function main() {
    try {
        validateConfig();

        const code = process.argv[2];
        const codeVerifier = process.argv[3];
        const redirectUri = process.argv[4];

        if (!code || !codeVerifier) {
            console.error('\n❌ Missing arguments!');
            console.log('Usage: node --env-file=.env src/exchange.js <AUTH_CODE> <CODE_VERIFIER> [REDIRECT_URI]\n');
            process.exit(1);
        }

        console.log('🚀 Exchanging code for tokens...');

        const manager = new SupabaseManager();
        const tokens = await manager.exchangeCodeForTokens(code, codeVerifier, redirectUri);

        // Save to store (in-memory for now, prints success)
        tokenStore.saveTokens('default-user', tokens);

        console.log('\n✅ EXCHANGE SUCCESSFUL!');
        console.log('------------------------------------');
        console.log(`Access Token  : ${tokens.access_token.substring(0, 15)}...`);
        console.log(`Refresh Token : ${tokens.refresh_token.substring(0, 15)}...`);
        console.log(`Expires In    : ${tokens.expires_in} seconds`);
        console.log('------------------------------------\n');

        console.log('You can now start calling the Management API using these tokens.');

    } catch (error) {
        console.error(`\n❌ Error: ${error.message}\n`);
        process.exit(1);
    }
}

main();
