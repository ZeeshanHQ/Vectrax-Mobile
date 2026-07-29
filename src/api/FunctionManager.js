// ============================================
// Supabase Pulse — FunctionManager
// ============================================
// Logic for managing Supabase Edge Functions.
// ============================================

export default class FunctionManager {
    constructor(apiClient) {
        this.client = apiClient;
    }

    /**
     * List all Edge Functions for a project.
     * 
     * @param {string} projectRef
     * @returns {Promise<Array>} List of functions
     */
    async listFunctions(projectRef) {
        if (!projectRef) throw new Error('[FunctionManager] projectRef is required.');

        console.log(`[FunctionManager] ⚡ Fetching functions for project: ${projectRef}...`);
        try {
            const functions = await this.client.getFunctions(projectRef);
            return functions;
        } catch (error) {
            throw new Error(`[FunctionManager] Failed to list functions: ${error.message}`);
        }
    }

    /**
     * Get details of a specific function.
     * 
     * @param {string} projectRef
     * @param {string} slug
     * @returns {Promise<object>} Function details
     */
    async getFunction(projectRef, slug) {
        try {
            const func = await this.client.getFunction(projectRef, slug);
            return func;
        } catch (error) {
            throw new Error(`[FunctionManager] Failed to get function ${slug}: ${error.message}`);
        }
    }
}
