// ============================================
// Supabase Pulse — Entry Point / Public API
// ============================================
// Exports the SupabaseManager class and TokenStore
// for consumption by Edge Functions or any Node.js backend.
//
// Usage:
//   import { SupabaseManager, tokenStore } from './index.js';
//   const manager = new SupabaseManager();
// ============================================

import SupabaseManager from './SupabaseManager.js';
import tokenStore from './tokenStore.js';
import config, { validateConfig } from './config.js';

// Phase 2: Management API Modules
import DashboardAPI from './api/DashboardAPI.js';
import ProjectManager from './api/ProjectManager.js';
import OrganizationManager from './api/OrganizationManager.js';
import FunctionManager from './api/FunctionManager.js';
import LogManager from './api/LogManager.js';
import AiManager from './api/AiManager.js';

export {
    SupabaseManager,
    tokenStore,
    config,
    validateConfig,
    DashboardAPI,
    ProjectManager,
    OrganizationManager,
    FunctionManager,
    LogManager,
    AiManager
};

// ── Quick Demo (runs when executed directly) ────────────────────
// Run: node src/index.js

const isDirectExecution = process.argv[1]?.endsWith('index.js');

if (isDirectExecution) {
    console.log('');
    console.log('╔══════════════════════════════════════════════════╗');
    console.log('║       SUPABASE PULSE — OAuth 2.1 PKCE Flow      ║');
    console.log('╚══════════════════════════════════════════════════╝');
    console.log('');

    const manager = new SupabaseManager();

    // ── Step 1: Generate PKCE ─────────────────────
    console.log('━━━ Step 1: Generate PKCE Pair ━━━');
    const { codeVerifier, codeChallenge } = manager.generatePKCE();
    console.log(`  code_verifier  : ${codeVerifier}`);
    console.log(`  code_challenge : ${codeChallenge}`);
    console.log('');

    // ── Step 2: Build Authorization URL ───────────
    console.log('━━━ Step 2: Build Authorization URL ━━━');
    const auth = manager.getAuthorizationUrl();
    console.log(`  🔗 URL for Frontend:\n`);
    console.log(`  ${auth.url}`);
    console.log('');
    console.log(`  state          : ${auth.state}`);
    console.log(`  code_verifier  : ${auth.codeVerifier}  ← SAVE THIS for Step 3`);
    console.log('');

    // ── Step 3: (Await code from Frontend) ────────
    console.log('━━━ Step 3: Token Exchange ━━━');
    console.log('  ⏳ Waiting for auth code from Frontend...');
    console.log('  After your partner opens the URL and consents,');
    console.log('  the mobile app receives the deep link callback:');
    console.log('');
    console.log('    com.supabasepulse://login-callback?code=AUTH_CODE&state=STATE');
    console.log('');
    console.log('  Pass that code to:');
    console.log('    manager.exchangeCodeForTokens(code, codeVerifier)');
    console.log('');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}
