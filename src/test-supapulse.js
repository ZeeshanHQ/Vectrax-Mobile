import ProjectManager from './api/ProjectManager.js';
import SupabaseManager from './SupabaseManager.js';
import tokenStore from './tokenStore.js';

async function main() {
    await tokenStore.syncFromDatabase();
    // Use the test user ID which currently has the active default-user token
    const savedTokens = tokenStore.getTokens('default-user');
    if (!savedTokens) {
        console.error("No saved tokens for default-user.");
        return;
    }
    
    const manager = new SupabaseManager();
    const client = manager.getManagementClient(savedTokens.access_token);
    const pm = new ProjectManager(client);
    
    try {
        console.log("Testing listTables for SupaPulse-db (crlrgszzibpkqfixlmbw)...");
        const tables = await pm.listTables('crlrgszzibpkqfixlmbw');
        console.log("SUCCESS! Tables found:", tables);
    } catch (e) {
        console.error("FAIL:", e.message);
    }
}

main();
