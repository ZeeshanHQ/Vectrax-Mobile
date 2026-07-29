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
    constructor(apiClient) {
        this.client = apiClient;

        // Initialize feature-specific managers
        this.projects = new ProjectManager(this.client);
        this.orgs = new OrganizationManager(this.client);
        this.functions = new FunctionManager(this.client);
        this.logs = new LogManager(this.client);
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
