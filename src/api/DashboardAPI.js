// ============================================
// Supabase Pulse — DashboardAPI (Facade)
// ============================================
// The main entry point for the Dashboard logic.
// Orchestrates all internal managers.
// ============================================

import ProjectManager from './ProjectManager.js';
import OrganizationManager from './OrganizationManager.js';
import FunctionManager from './FunctionManager.js';
import LogManager from './LogManager.js';

export default class DashboardAPI {
    constructor(apiClient, userId) {
        this.client = apiClient;
        this.userId = userId;

        // Initialize feature-specific managers
        this.projects = new ProjectManager(this.client, userId);
        this.orgs = new OrganizationManager(this.client, userId);
        this.functions = new FunctionManager(this.client, userId);
        this.logs = new LogManager(this.client, userId);
    }

    /**
     * Handy helper to get everything needed for the main dashboard view.
     */
    async getQuickSummary() {
        const [orgs, projects] = await Promise.all([
            this.orgs.listOrganizations(),
            this.projects.listProjects()
        ]);

        return {
            orgCount: orgs.length,
            projectCount: projects.length,
            organizations: orgs,
            projects: projects
        };
    }
}
