// ============================================
// Supabase Pulse — API Server Entry Point
// ============================================
import express from 'express';
import cors from 'cors';
import { handleAuthExchange } from './server.js';
import { handleOtpSend, handleOtpVerify } from './otp.js';
import { validateConfig, SupabaseManager, DashboardAPI, tokenStore, AiManager } from './index.js';

// Global instances
const manager = new SupabaseManager();
const ai = new AiManager();

// Auth verification middleware to keep session tokens fresh
const ensureAuthenticated = async (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Missing or malformed Authorization header' });
    }
    const token = authHeader.split(' ')[1];

    let userId;
    try {
        const parts = token.split('.');
        const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
        userId = payload.sub;
        if (!userId) throw new Error('sub claim missing');
    } catch (err) {
        console.error('[Server] ❌ JWT decode failed:', err.message);
        return res.status(401).json({ error: 'Invalid authorization token' });
    }

    req.userId = userId;

    // Sync specific user's tokens from database
    await tokenStore.syncFromDatabase(userId);

    const saved = tokenStore.getTokens(userId);
    if (!saved) {
        return res.status(401).json({ error: 'Not authenticated with Supabase. Please reconnect.' });
    }

    if (!tokenStore.isTokenValid(userId)) {
        console.log(`[Server] 🔄 Token expired or near expiry for user ${userId}. Refreshing...`);
        try {
            const newTokens = await manager.refreshAccessToken(saved.refresh_token);
            await tokenStore.saveTokens(userId, newTokens);
            console.log('[Server] ✅ Token refreshed successfully.');
        } catch (error) {
            console.error('[Server] ❌ Token refresh failed:', error.message);
            return res.status(401).json({ error: 'Session expired. Please reconnect.' });
        }
    }

    const activeTokens = tokenStore.getTokens(userId);
    const client = manager.getManagementClient(activeTokens.access_token);
    req.dashboard = new DashboardAPI(client, userId);
    next();
};

// 1. Initialise & Validate
try {
    validateConfig();
} catch (error) {
    console.error('❌ Config Validation Failed:', error.message);
    process.exit(1);
}

const app = express();
const PORT = process.env.PORT || 3000;

// 2. Middlewares
app.use(cors()); // Allow Flutter Web (CORS)
app.use(express.json()); // Parse JSON bodies
app.use('/assets', express.static('assets'));
app.use('/api/projects', ensureAuthenticated);
app.use('/api/organizations', ensureAuthenticated);

// 3. Routes
// Flutter calls this after receiving the code from Supabase
app.post('/api/auth/exchange', async (req, res) => {
    await handleAuthExchange(req, res);
});

// ── Custom OTP (Resend) ───────────────────────────────────────────────────
app.post('/api/auth/otp/send', handleOtpSend);
app.post('/api/auth/otp/verify', handleOtpVerify);


// ── Management API Endpoints ──────────────────

// List Projects
app.get('/api/projects', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    try {
        const projects = await dashboard.projects.listProjects();
        res.json(projects);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Restore Project
app.post('/api/projects/:ref/restore', async (req, res) => {
    const saved = tokenStore.getTokens(req.userId);
    const projectRef = req.params.ref;
    console.log(`[Server] 🏗️ Attempting to restore project: ${projectRef}`);

    if (!saved) {
        console.error('[Server] Restore failed: No saved tokens found');
        return res.status(401).json({ error: 'Not authenticated with Supabase' });
    }

    try {
        const response = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/restore`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${saved.access_token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[Server] Supabase API restore error (${response.status}): ${errorText}`);
            throw new Error(errorText);
        }

        console.log(`[Server] ✅ Restore initiated for ${projectRef}`);
        res.json({ success: true, message: 'Database restore initiated' });
    } catch (error) {
        console.error(`[Server] Internal restore error: ${error.message}`);
        res.status(500).json({ error: error.message });
    }
});

// Pause Project
app.post('/api/projects/:ref/pause', async (req, res) => {
    const saved = tokenStore.getTokens(req.userId);
    const projectRef = req.params.ref;
    console.log(`[Server] ⏸️ Attempting to pause project: ${projectRef}`);

    if (!saved) {
        console.error('[Server] Pause failed: No saved tokens found');
        return res.status(401).json({ error: 'Not authenticated with Supabase' });
    }

    try {
        const response = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/pause`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${saved.access_token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[Server] Supabase API pause error (${response.status}): ${errorText}`);
            throw new Error(errorText);
        }

        console.log(`[Server] ✅ Pause initiated for ${projectRef}`);
        res.json({ success: true, message: 'Database pause initiated' });
    } catch (error) {
        console.error(`[Server] Internal pause error: ${error.message}`);
        res.status(500).json({ error: error.message });
    }
});

// Restart Project
app.post('/api/projects/:ref/restart', async (req, res) => {
    const saved = tokenStore.getTokens(req.userId);
    const projectRef = req.params.ref;
    console.log(`[Server] 🔄 Attempting to restart database: ${projectRef}`);

    if (!saved) {
        console.error('[Server] Restart failed: No saved tokens found');
        return res.status(401).json({ error: 'Not authenticated with Supabase' });
    }

    try {
        const response = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/restart`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${saved.access_token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[Server] Supabase API restart error (${response.status}): ${errorText}`);
            throw new Error(errorText);
        }

        console.log(`[Server] ✅ Restart initiated for ${projectRef}`);
        res.json({ success: true, message: 'Database restart initiated' });
    } catch (error) {
        console.error(`[Server] Internal restart error: ${error.message}`);
        res.status(500).json({ error: error.message });
    }
});

// Ping Project (Keep Alive)
app.post('/api/projects/:ref/ping', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    try {
        const result = await dashboard.projects.pingProject(req.params.ref);
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// List Organizations
app.get('/api/organizations', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    try {
        const orgs = await dashboard.orgs.listOrganizations();
        res.json(orgs);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ── Project Resource Endpoints ────────────────

// List Tables
app.get('/api/projects/:ref/tables', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    const ref = req.params.ref;
    const apiKey = req.query.apiKey;
    console.log(`[Server] 🔎 DISCOVERY REQUEST | REF: ${ref} | KEY: ${apiKey ? 'PROVIDED' : 'MISSING (AUTO-FETCH)'}`);
    try {
        const tables = await dashboard.projects.listTables(ref, apiKey);
        console.log(`[Server] ✅ DISCOVERY COMPLETE | REF: ${ref} | FOUND: ${tables.length} TABLES`);
        res.json(tables);
    } catch (error) {
        console.error(`[Server] ❌ Discovery error: ${error.message}`);
        res.status(500).json({ error: error.message });
    }
});

// Get Project Keys
app.get('/api/projects/:ref/keys', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    const ref = req.params.ref;
    try {
        const keys = await dashboard.projects.getProjectKeys(ref);
        res.json(keys);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get Database Schema
app.get('/api/projects/:ref/schema', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    const ref = req.params.ref;
    try {
        const schema = await dashboard.projects.getProjectSchema(ref);
        res.json(schema);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// List Functions
app.get('/api/projects/:ref/functions', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    try {
        const functions = await dashboard.projects.listFunctions(req.params.ref);
        res.json(functions);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// List Secrets
app.get('/api/projects/:ref/secrets', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    try {
        const secrets = await dashboard.projects.listSecrets(req.params.ref);
        res.json(secrets);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Upsert Secrets
app.post('/api/projects/:ref/secrets', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    try {
        const result = await dashboard.projects.upsertSecrets(req.params.ref, req.body);
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Delete Secrets
app.delete('/api/projects/:ref/secrets', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    try {
        const result = await dashboard.projects.deleteSecrets(req.params.ref, req.body);
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// List Buckets
app.get('/api/projects/:ref/buckets', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    try {
        const buckets = await dashboard.projects.listBuckets(req.params.ref);
        res.json(buckets);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// List Users
app.get('/api/projects/:ref/users', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    try {
        const users = await dashboard.projects.listUsers(req.params.ref);
        res.json(users);
    } catch (error) {
        console.error(`[Server] ❌ Users fetch error: ${error.message}`);
        res.status(500).json({ error: error.message });
    }
});

// Get Table Records
app.get('/api/projects/:ref/tables/:tableName/records', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    const { ref, tableName } = req.params;
    const apiKey = req.query.apiKey;
    try {
        const records = await dashboard.projects.selectRecords(ref, tableName, apiKey);
        res.json(records);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// List Bucket Files
app.get('/api/projects/:ref/buckets/:id/files', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    const { ref, id } = req.params;
    const { prefix } = req.query;
    try {
        const files = await dashboard.projects.listFiles(ref, id, prefix);
        res.json(files);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Execute SQL
app.post('/api/projects/:ref/sql', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    const { ref } = req.params;
    const { query } = req.body;
    try {
        const result = await dashboard.projects.executeSql(ref, query);
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// AI SQL Generation
app.post('/api/ai/generate-sql', async (req, res) => {
    const { prompt, schema } = req.body;

    if (!prompt) return res.status(400).json({ error: 'Prompt is required' });
    if (!schema) return res.status(400).json({ error: 'Schema context is required' });

    console.log(`[Server] 🤖 AI Request received | Prompt: "${prompt.substring(0, 30)}..." | Tables: ${Object.keys(schema).length}`);

    try {
        const sql = await ai.generateSql(prompt, schema);
        console.log(`[Server] ✅ AI Generation Success`);
        res.json({ sql });
    } catch (error) {
        console.error(`[Server] ❌ AI Generation failed: ${error.message}`);
        res.status(500).json({ error: error.message });
    }
});

// Delete Resource (Universal)
app.delete('/api/projects/:ref/resources/:type/:id', async (req, res) => {
    const dashboard = req.dashboard;
    if (!dashboard) return res.status(401).json({ error: 'Not authenticated with Supabase' });
    const { ref, type, id } = req.params;
    try {
        const result = await dashboard.projects.deleteResource(ref, type, id);
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', service: 'Supabase Pulse Backend' }));

// ── OAuth Redirect Bounce ─────────────────────────
// Supabase redirects here (HTTPS) → we bounce to the app's deep link
app.get('/login-callback', (req, res) => {
    const code = req.query.code;
    const state = req.query.state;

    if (!code) {
        return res.status(400).send('Missing authorization code.');
    }

    // Build the deep link URL for the mobile app
    const deepLink = `com.supabasepulse://login-callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state || '')}`;

    // Send an HTML page that auto-redirects to the deep link
    res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Redirecting to Supabase Pulse...</title>
      <meta http-equiv="refresh" content="0;url=${deepLink}">
      <style>
        body { font-family: -apple-system, sans-serif; background: #000; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; flex-direction: column; }
        .spinner { width: 40px; height: 40px; border: 3px solid #333; border-top: 3px solid #3ECF8E; border-radius: 50%; animation: spin 1s linear infinite; margin-bottom: 20px; }
        @keyframes spin { to { transform: rotate(360deg); } }
        a { color: #3ECF8E; margin-top: 16px; }
      </style>
    </head>
    <body>
      <div class="spinner"></div>
      <p>Returning to Supabase Pulse...</p>
      <a href="${deepLink}">Tap here if you're not redirected</a>
      <script>window.location.href = "${deepLink}";</script>
    </body>
    </html>
    `);
});

// Root welcome
app.get('/', (req, res) => {
    res.send(`
    <body style="font-family: sans-serif; background: #000; color: #00d4ff; display: flex; align-items: center; justify-content: center; height: 100vh;">
        <h1>🚀 Supabase Pulse Backend</h1>
        <p>API is active and listening at <b>/api/auth/exchange</b></p>
        <div style="background: #111; padding: 10px; border-radius: 10px; margin-top: 20px;">
          Status: <span style="color: #0f0;">ONLINE</span>
        </div>
      </div>
    </body>
  `);
});

// 4. Start Server
if (process.env.NODE_ENV !== 'production') {
    app.listen(PORT, () => {
        console.log(`\n🚀 SUPABASE PULSE BACKEND IS LIVE`);
        console.log(`------------------------------------`);
        console.log(`Local URL  : http://localhost:${PORT}`);
        console.log(`Health     : http://localhost:${PORT}/health`);
        console.log(`Endpoint   : http://localhost:${PORT}/api/auth/exchange`);
        console.log(`------------------------------------\n`);
        console.log(`Ready for Flutter integration testing!\n`);
    });
}

export default app;
