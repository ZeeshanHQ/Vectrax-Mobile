import fs from 'fs';
import path from 'path';
import pg from 'pg';
const { Pool } = pg;

// ============================================
// Supabase Pulse — Secure Token Store
// ============================================
// Abstraction layer for token persistence.
// Fits dev (disk) and prod (Cloud PostgreSQL).
// ============================================

const TOKEN_FILE_PATH = './scratch_tokens.json';

let pool = null;
function getPool() {
    if (!pool && process.env.DATABASE_URL) {
        pool = new Pool({
            connectionString: process.env.DATABASE_URL,
            ssl: {
                rejectUnauthorized: false
            }
        });
    }
    return pool;
}

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
     * Pull the latest connection tokens from the cloud database into memory.
     * Crucial for Vercel/serverless environments where local files are wiped out.
     *
     * @param {string} [userId='default-user'] - The user ID to sync
     */
    async syncFromDatabase(userId = 'default-user') {
        const dbPool = getPool();
        if (!dbPool) {
            console.warn('[TokenStore] ⚠️ DATABASE_URL not set. Skipping DB sync.');
            return;
        }
        try {
            // Ensure the oauth_tokens table exists
            await dbPool.query(`
                CREATE TABLE IF NOT EXISTS oauth_tokens (
                    user_id text PRIMARY KEY,
                    access_token text NOT NULL,
                    refresh_token text NOT NULL,
                    expires_at bigint,
                    updated_at timestamp with time zone DEFAULT now()
                );
            `);

            console.log(`[TokenStore] 🔍 Syncing connection tokens from cloud database for user: ${userId}...`);
            const res = await dbPool.query(
                'SELECT * FROM oauth_tokens WHERE user_id = $1',
                [userId]
            );
            if (res.rows.length > 0) {
                const row = res.rows[0];
                const expires_at = Number(row.expires_at);

                this.#store.set(userId, {
                    access_token: row.access_token,
                    refresh_token: row.refresh_token,
                    token_type: 'bearer',
                    expires_in: Math.round((expires_at - Date.now()) / 1000),
                    stored_at: Date.now(),
                    expires_at: expires_at,
                });
                console.log(`[TokenStore] 🚀 Sync complete. Connection loaded into memory for user: ${userId}`);
            } else {
                console.log(`[TokenStore] ⚠️ No active connection found in oauth_tokens for user: ${userId}`);
            }
        } catch (err) {
            console.error('[TokenStore] ❌ Cloud DB sync error:', err.message);
        }
    }

    /**
     * Save tokens for a given user session.
     *
     * @param {string} userId - Unique user/session identifier
     * @param {object} tokens - The token payload from Supabase
     */
    async saveTokens(userId, tokens) {
        if (!userId) throw new Error('[TokenStore] userId is required.');
        if (!tokens?.access_token) throw new Error('[TokenStore] tokens.access_token is required.');

        const expires_at = Date.now() + tokens.expires_in * 1000;

        // 1. Save in-memory
        this.#store.set(userId, {
            ...tokens,
            stored_at: Date.now(),
            expires_at: expires_at,
        });

        // 2. Save to local disk fallback
        this._saveToDisk();

        // 3. Save to cloud database
        const dbPool = getPool();
        if (dbPool) {
            try {
                // Ensure the oauth_tokens table exists
                await dbPool.query(`
                    CREATE TABLE IF NOT EXISTS oauth_tokens (
                        user_id text PRIMARY KEY,
                        access_token text NOT NULL,
                        refresh_token text NOT NULL,
                        expires_at bigint,
                        updated_at timestamp with time zone DEFAULT now()
                    );
                `);

                console.log('[TokenStore] ☁️ Saving tokens to cloud database (oauth_tokens)...');
                await dbPool.query(`
                    INSERT INTO oauth_tokens (user_id, access_token, refresh_token, expires_at, updated_at)
                    VALUES ($1, $2, $3, $4, now())
                    ON CONFLICT (user_id) 
                    DO UPDATE SET access_token = EXCLUDED.access_token, 
                                  refresh_token = EXCLUDED.refresh_token, 
                                  expires_at = EXCLUDED.expires_at,
                                  updated_at = now();
                `, [userId, tokens.access_token, tokens.refresh_token, expires_at]);
                console.log(`[TokenStore] ☁️ Token table upsert complete for user_id: ${userId}`);
            } catch (err) {
                console.error('[TokenStore] ❌ Failed to write tokens to cloud database:', err.message);
            }
        }
    }

    /**
     * Retrieve stored tokens for a user.
     *
     * @param {string} userId
     * @returns {object|null}
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
