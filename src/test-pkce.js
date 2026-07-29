// ============================================
// Supabase Pulse — PKCE & URL Verification Tests
// ============================================
// Run: npm test   (or: node src/test-pkce.js)
//
// No dependencies required — uses Node assert.
// ============================================

import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import SupabaseManager from './SupabaseManager.js';

const manager = new SupabaseManager();
let passed = 0;
let failed = 0;

function test(name, fn) {
    try {
        fn();
        passed++;
        console.log(`  ✅ ${name}`);
    } catch (err) {
        failed++;
        console.log(`  ❌ ${name}`);
        console.log(`     → ${err.message}`);
    }
}

console.log('');
console.log('╔══════════════════════════════════════════════════╗');
console.log('║        PKCE & URL GENERATION TEST SUITE          ║');
console.log('╚══════════════════════════════════════════════════╝');
console.log('');

// ━━ PKCE Tests ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
console.log('━━ PKCE Generation ━━━━━━━━━━━━━━━━━━');

test('generatePKCE() returns codeVerifier and codeChallenge', () => {
    const pkce = manager.generatePKCE();
    assert.ok(pkce.codeVerifier, 'codeVerifier should exist');
    assert.ok(pkce.codeChallenge, 'codeChallenge should exist');
});

test('code_verifier is 43 characters (32 bytes → base64url)', () => {
    const { codeVerifier } = manager.generatePKCE();
    assert.equal(codeVerifier.length, 43, `Expected 43 chars, got ${codeVerifier.length}`);
});

test('code_verifier contains only base64url characters', () => {
    const { codeVerifier } = manager.generatePKCE();
    assert.ok(
        /^[A-Za-z0-9\-_]+$/.test(codeVerifier),
        'code_verifier must only contain [A-Za-z0-9-_]'
    );
});

test('code_challenge has no padding (=), no +, no /', () => {
    const { codeChallenge } = manager.generatePKCE();
    assert.ok(!codeChallenge.includes('='), 'Should not contain =');
    assert.ok(!codeChallenge.includes('+'), 'Should not contain +');
    assert.ok(!codeChallenge.includes('/'), 'Should not contain /');
});

test('code_challenge is SHA-256 of code_verifier (verified manually)', () => {
    const { codeVerifier, codeChallenge } = manager.generatePKCE();
    // Manually compute SHA-256 → base64url of the verifier
    const manualHash = crypto
        .createHash('sha256')
        .update(codeVerifier)
        .digest('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/, '');
    assert.equal(codeChallenge, manualHash, 'Challenge must match SHA-256(verifier)');
});

test('Successive PKCE calls generate unique pairs', () => {
    const a = manager.generatePKCE();
    const b = manager.generatePKCE();
    assert.notEqual(a.codeVerifier, b.codeVerifier, 'Verifiers should be unique');
    assert.notEqual(a.codeChallenge, b.codeChallenge, 'Challenges should be unique');
});

// ━━ Authorization URL Tests ━━━━━━━━━━━━━━━━━━━━
console.log('');
console.log('━━ Authorization URL ━━━━━━━━━━━━━━━━');

test('getAuthorizationUrl() returns url, codeVerifier, codeChallenge, state', () => {
    const result = manager.getAuthorizationUrl();
    assert.ok(result.url, 'url should exist');
    assert.ok(result.codeVerifier, 'codeVerifier should exist');
    assert.ok(result.codeChallenge, 'codeChallenge should exist');
    assert.ok(result.state, 'state should exist');
});

test('URL starts with https://api.supabase.com/v1/oauth/authorize', () => {
    const { url } = manager.getAuthorizationUrl();
    assert.ok(
        url.startsWith('https://api.supabase.com/v1/oauth/authorize'),
        `URL starts incorrectly: ${url.substring(0, 60)}`
    );
});

test('URL contains required params: client_id, redirect_uri, response_type, code_challenge, code_challenge_method', () => {
    const { url } = manager.getAuthorizationUrl();
    const params = new URL(url).searchParams;

    assert.ok(params.has('client_id'), 'Missing client_id');
    assert.ok(params.has('redirect_uri'), 'Missing redirect_uri');
    assert.equal(params.get('response_type'), 'code', 'response_type must be code');
    assert.ok(params.has('code_challenge'), 'Missing code_challenge');
    assert.equal(params.get('code_challenge_method'), 'S256', 'code_challenge_method must be S256');
    assert.ok(params.has('state'), 'Missing state');
});

test('redirect_uri matches the mobile deep link', () => {
    const { url } = manager.getAuthorizationUrl();
    const params = new URL(url).searchParams;
    assert.equal(
        params.get('redirect_uri'),
        'com.supabasepulse://login-callback',
        'redirect_uri must be the mobile deep link'
    );
});

test('Custom state is preserved when passed', () => {
    const customState = 'my-custom-state-12345';
    const { state } = manager.getAuthorizationUrl({ state: customState });
    assert.equal(state, customState);
});

test('organization_slug param is set when provided', () => {
    const { url } = manager.getAuthorizationUrl({ organizationSlug: 'my-org' });
    const params = new URL(url).searchParams;
    assert.equal(params.get('organization_slug'), 'my-org');
});

// ━━ Token Store Tests ━━━━━━━━━━━━━━━━━━━━━━━━━━
console.log('');
console.log('━━ Token Store ━━━━━━━━━━━━━━━━━━━━━');

// Dynamic import to avoid issues with the default export
const { default: tokenStore } = await import('./tokenStore.js');

test('saveTokens() stores and getTokens() retrieves', () => {
    tokenStore.saveTokens('user-1', {
        access_token: 'at_test',
        refresh_token: 'rt_test',
        expires_in: 3600,
        token_type: 'Bearer',
    });
    const result = tokenStore.getTokens('user-1');
    assert.equal(result.access_token, 'at_test');
    assert.equal(result.refresh_token, 'rt_test');
});

test('isTokenValid() returns true for non-expired tokens', () => {
    assert.ok(tokenStore.isTokenValid('user-1'));
});

test('isTokenValid() returns false for unknown users', () => {
    assert.ok(!tokenStore.isTokenValid('unknown-user'));
});

test('clearTokens() removes stored tokens', () => {
    tokenStore.clearTokens('user-1');
    assert.equal(tokenStore.getTokens('user-1'), null);
});

// ━━ Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
console.log('');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log(`  Results: ${passed} passed, ${failed} failed, ${passed + failed} total`);
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('');

if (failed > 0) {
    process.exit(1);
}
