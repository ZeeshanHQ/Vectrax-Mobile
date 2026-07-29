// ============================================
// Supabase Pulse — LogManager
// ============================================
// Logic for querying project logs.
// ============================================

export default class LogManager {
    constructor(apiClient) {
        this.client = apiClient;
    }

    /**
     * Fetch logs for a project with filters.
     * 
     * @param {object} params
     * @param {string} params.projectRef
     * @param {string} [params.type] - e.g., 'database', 'auth', 'functions'
     * @param {number} [params.limit]
     * @returns {Promise<Array>} Array of log entries
     */
    async fetchLogs({ projectRef, type = 'database', limit = 100 }) {
        if (!projectRef) throw new Error('[LogManager] projectRef is required.');

        console.log(`[LogManager] 🔍 Fetching ${type} logs for ${projectRef}...`);
        try {
            // Note: SDK method name might vary, usually getLogs
            const logs = await this.client.getLogs(projectRef, { type, limit });
            return logs;
        } catch (error) {
            throw new Error(`[LogManager] Failed to fetch logs: ${error.message}`);
        }
    }
}
