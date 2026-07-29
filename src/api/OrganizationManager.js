// ============================================
// Supabase Pulse — OrganizationManager
// ============================================
// Logic for managing organizations and members.
// ============================================

export default class OrganizationManager {
    constructor(apiClient) {
        this.client = apiClient;
    }

    /**
     * List all organizations the user belongs to.
     * 
     * @returns {Promise<Array>} List of organization objects
     */
    async listOrganizations() {
        console.log('[OrganizationManager] 🏢 Fetching organizations...');
        try {
            const orgs = await this.client.getOrganizations();
            return orgs;
        } catch (error) {
            throw new Error(`[OrganizationManager] Failed to list organizations: ${error.message}`);
        }
    }

    /**
     * List members of a specific organization.
     * 
     * @param {string} organizationId
     * @returns {Promise<Array>} List of members
     */
    async listMembers(organizationId) {
        if (!organizationId) throw new Error('[OrganizationManager] organizationId is required.');

        try {
            // Note: check SDK docs if getMembers is the literal name
            const members = await this.client.getMembers(organizationId);
            return members;
        } catch (error) {
            throw new Error(`[OrganizationManager] Failed to list members: ${error.message}`);
        }
    }
}
