import fs from 'fs';
import path from 'path';

// ============================================
// Supabase Pulse — Secure Token Store
// ============================================
// Abstraction layer for token persistence.
//
// ► DEV:  In-memory Map (current implementation)
// ► PROD: Swap for encrypted storage:
//         - iOS  → Keychain via expo-secure-store
//         - Android → Encrypted SharedPreferences
//         - Server → Encrypted DB column (AES-256)
// ============================================

const TOKEN_FILE_PATH = './scratch_tokens.json';

class TokenStore {
    #store = new Map();

    constructor() {
        this._loadFromDisk();
    }

    _loadFromDisk() {
        try {
            if (fs.existsSync(TOKEN_FILE_PATH)) {
                const data = JSON.parse(fs.readFileSync(TOKEN_FILE_PATH, 'utf8'));
                for (const [key, value] of Object.entries(data)) {
                    this.#store.set(key, value);
                }
                console.log(`[TokenStore] 💿 Loaded tokens from disk.`);
            }
        } catch (e) {
            console.error('[TokenStore] Failed to load from disk:', e.message);
        }
    }

    _saveToDisk() {
        try {
            const data = {};
            for (const [key, value] of this.#store.entries()) {
                data[key] = value;
            }
            fs.writeFileSync(TOKEN_FILE_PATH, JSON.stringify(data), 'utf8');
        } catch (e) {
            console.error('[TokenStore] Failed to save to disk:', e.message);
        }
    }

    /**
     * Save tokens for a given user session.
     *
     * @param {string} userId - Unique user/session identifier
     * @param {object} tokens - The token payload from Supabase
     * @param {string} tokens.access_token
     * @param {string} tokens.refresh_token
     * @param {number} tokens.expires_in
     * @param {string} tokens.token_type
     */
    saveTokens(userId, tokens) {
        if (!userId) throw new Error('[TokenStore] userId is required.');
        if (!tokens?.access_token) throw new Error('[TokenStore] tokens.access_token is required.');

        this.#store.set(userId, {
            ...tokens,
            stored_at: Date.now(),
            expires_at: Date.now() + tokens.expires_in * 1000,
        });

        this._saveToDisk();
        console.log(`[TokenStore] 💾 Tokens saved for user: ${userId}`);
    }

    /**
     * Retrieve stored tokens for a user.
     *
     * @param {string} userId
     * @returns {object|null} The stored token object, or null if not found
     */
    getTokens(userId) {
        return this.#store.get(userId) || null;
    }

    /**
     * Check if the stored access_token is still valid (not expired).
     *
     * @param {string} userId
     * @returns {boolean}
     */
    isTokenValid(userId) {
        const entry = this.#store.get(userId);
        if (!entry) return false;

        // Consider expired 60 seconds early to avoid race conditions
        return Date.now() < entry.expires_at - 60_000;
    }

    /**
     * Clear all tokens for a user (e.g. on logout or revoke).
     *
     * @param {string} userId
     */
    clearTokens(userId) {
        this.#store.delete(userId);
        this._saveToDisk();
        console.log(`[TokenStore] 🗑️  Tokens cleared for user: ${userId}`);
    }

    /**
     * Get the number of active sessions in the store.
     * Useful for monitoring/debugging.
     *
     * @returns {number}
     */
    get size() {
        return this.#store.size;
    }
}

// Export a singleton instance for app-wide use
const tokenStore = new TokenStore();
export default tokenStore;
export { TokenStore };
