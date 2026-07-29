// ============================================
// Supabase Pulse — AiManager
// ============================================
// Logic for generating SQL from natural language
// using Gemini (Primary) and OpenRouter (Fallback).
// ============================================

export default class AiManager {
    constructor() {
        this.geminiKey = process.env.GEMINI_API_KEY;
        this.openRouterKey = process.env.OPENROUTER_API_KEY;
        this.githubToken = process.env.GITHUB_TOKEN;
    }

    /**
     * Generate SQL from natural language prompt and schema context.
     * @param {string} prompt - User intent
     * @param {object} schema - Database schema for context
     * @returns {Promise<string>} Clean SQL query
     */
    async generateSql(prompt, schema) {
        console.log(`[AiManager] 🧠 Generating SQL for: "${prompt}"`);

        // Priority 1: Gemini
        try {
            if (this.geminiKey) {
                console.log('[AiManager] 🚀 Using Primary Engine: Gemini');
                const sql = await this.#callGemini(prompt, schema);
                console.log('[AiManager] ✅ Gemini returned result');
                if (sql) return sql;
            }
        } catch (error) {
            console.warn(`[AiManager] ⚠️ Gemini failed: ${error.message}`);
        }

        // Priority 2: GitHub Models (GPT-4o)
        try {
            if (this.githubToken) {
                console.log('[AiManager] 🐙 Using Tier 2 Engine: GitHub Models (GPT-4o)');
                const sql = await this.#callGitHub(prompt, schema);
                console.log('[AiManager] ✅ GitHub Models returned result');
                if (sql) return sql;
            }
        } catch (error) {
            console.warn(`[AiManager] ⚠️ GitHub Models failed: ${error.message}`);
        }

        // Priority 3: OpenRouter Fallback
        try {
            if (this.openRouterKey) {
                console.log('[AiManager] 🚁 Using Tier 3 Engine: OpenRouter');
                const sql = await this.#callOpenRouter(prompt, schema);
                console.log('[AiManager] ✅ OpenRouter returned result');
                if (sql) return sql;
            }
        } catch (error) {
            console.error(`[AiManager] ❌ OpenRouter failed: ${error.message}`);
            // Priority 4: Grok fallback via OpenRouter
            try {
                if (this.openRouterKey) {
                    console.log('[AiManager] 🦾 Using Grok fallback via OpenRouter');
                    const sql = await this.#callGrok(prompt, schema);
                    console.log('[AiManager] ✅ Grok returned result');
                    if (sql) return sql;
                }
            } catch (error) {
                console.error(`[AiManager] ❌ Grok failed: ${error.message}`);
            }
        }

        throw new Error('AI Generation failed on all available models.');
    }

    async #callGemini(prompt, schema) {
        const url = `https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash-8b:generateContent?key=${this.geminiKey}`;

        const systemPrompt = this.#buildSystemPrompt(schema);

        console.log(`[AiManager] 📡 Connecting to Gemini API...`);
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 15000); // 15s timeout

        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            signal: controller.signal,
            body: JSON.stringify({
                contents: [{
                    parts: [{ text: `${systemPrompt}\n\nUser Query: ${prompt}` }]
                }],
                generationConfig: {
                    temperature: 0.1,
                    topP: 0.95,
                    maxOutputTokens: 1024,
                }
            })
        });
        clearTimeout(timeoutId);

        console.log(`[AiManager] 📡 Response status: ${response.status}`);
        if (!response.ok) {
            const err = await response.text();
            console.error(`[AiManager] ❌ Gemini error details: ${err}`);
            throw new Error(`Gemini API Error: ${err}`);
        }

        const data = await response.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
        console.log(`[AiManager] 🤖 Raw AI output: ${text?.substring(0, 50)}...`);
        return this.#cleanSql(text);
    }

    async #callOpenRouter(prompt, schema) {
        const url = 'https://openrouter.ai/api/v1/chat/completions';
        const systemPrompt = this.#buildSystemPrompt(schema);

        console.log(`[AiManager] 📡 Connecting to OpenRouter API...`);
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 15000); // 15s timeout

        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.openRouterKey}`,
                'HTTP-Referer': 'https://supabase-pulse.elite',
                'X-Title': 'Supabase Pulse'
            },
            signal: controller.signal,
            body: JSON.stringify({
                model: 'google/gemini-flash-1.5',
                messages: [
                    { role: 'system', content: systemPrompt },
                    { role: 'user', content: prompt }
                ],
                temperature: 0.1
            })
        });
        clearTimeout(timeoutId);

        console.log(`[AiManager] 📡 Response status: ${response.status}`);
        if (!response.ok) {
            const err = await response.text();
            console.error(`[AiManager] ❌ OpenRouter error details: ${err}`);
            throw new Error(`OpenRouter API Error: ${err}`);
        }

        const data = await response.json();
        const text = data.choices?.[0]?.message?.content;
        console.log(`[AiManager] 🤖 Raw AI output (OR): ${text?.substring(0, 50)}...`);
        return this.#cleanSql(text);
    }

    // New method to call Grok model via OpenRouter
    async #callGrok(prompt, schema) {
        const url = 'https://openrouter.ai/api/v1/chat/completions';
        const systemPrompt = this.#buildSystemPrompt(schema);
        console.log(`[AiManager] 📡 Connecting to OpenRouter Grok API...`);
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 15000);
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.openRouterKey}`,
                'HTTP-Referer': 'https://supabase-pulse.elite',
                'X-Title': 'Supabase Pulse'
            },
            signal: controller.signal,
            body: JSON.stringify({
                model: 'x-ai/grok-4',
                messages: [
                    { role: 'system', content: systemPrompt },
                    { role: 'user', content: prompt }
                ],
                temperature: 0.1
            })
        });
        clearTimeout(timeoutId);
        console.log(`[AiManager] 📡 Grok response status: ${response.status}`);
        if (!response.ok) {
            const err = await response.text();
            console.error(`[AiManager] ❌ Grok error details: ${err}`);
            throw new Error(`Grok API Error: ${err}`);
        }
        const data = await response.json();
        const text = data.choices?.[0]?.message?.content;
        console.log(`[AiManager] 🤖 Grok raw output: ${text?.substring(0, 50)}...`);
        return this.#cleanSql(text);
    }

    async #callGitHub(prompt, schema) {
        const url = 'https://models.inference.ai.azure.com/chat/completions';
        const systemPrompt = this.#buildSystemPrompt(schema);
        console.log(`[AiManager] 📡 Connecting to GitHub Models (GPT-4o) API...`);
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 15000);
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.githubToken}`
            },
            signal: controller.signal,
            body: JSON.stringify({
                model: 'gpt-4o',
                messages: [
                    { role: 'system', content: systemPrompt },
                    { role: 'user', content: prompt }
                ],
                temperature: 0.1
            })
        });
        clearTimeout(timeoutId);
        console.log(`[AiManager] 📡 GitHub response status: ${response.status}`);
        if (!response.ok) {
            const err = await response.text();
            console.error(`[AiManager] ❌ GitHub error details: ${err}`);
            throw new Error(`GitHub Models API Error: ${err}`);
        }
        const data = await response.json();
        const text = data.choices?.[0]?.message?.content;
        console.log(`[AiManager] 🤖 GitHub raw output: ${text?.substring(0, 50)}...`);
        return this.#cleanSql(text);
    }

    #buildSystemPrompt(schema) {
        return `You are an elite PostgreSQL SQL expert. Your task is to convert natural language intents into 100% accurate SQL queries.
        
CONTEXT:
The database schema for the current project is:
${JSON.stringify(schema, null, 2)}

RULES:
1. Return ONLY the raw SQL code. No markdown, no triple backticks, no explanations.
2. Use "public" schema prefix if necessary.
3. If the intent involves time (e.g., "last 24 hours"), use 'NOW() - INTERVAL '24 hours''.
4. Ensure column names exist in the provided schema.
5. If you cannot generate a safe query, return an empty string.
6. Target PostgreSQL syntax.

Output ONLY the SQL string.`;
    }

    #cleanSql(text) {
        if (!text) return '';
        // Remove markdown backticks if any
        return text.replace(/```sql|```/gi, '').trim();
    }
}
