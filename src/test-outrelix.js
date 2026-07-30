import ProjectManager from './api/ProjectManager.js';
import SupabaseManager from './SupabaseManager.js';
import tokenStore from './tokenStore.js';

async function main() {
    await tokenStore.syncFromDatabase();
    const savedTokens = tokenStore.getTokens('default-user');
    if (!savedTokens) {
        console.error("No saved tokens.");
        return;
    }
    
    const manager = new SupabaseManager();
    const client = manager.getManagementClient(savedTokens.access_token);
    const pm = new ProjectManager(client);
    
    try {
        console.log("Testing listTables for Outrelix (bfoggljxtwoloxthtocy)...");
        const tables = await pm.listTables('bfoggljxtwoloxthtocy');
        console.log("SUCCESS! Tables found:", tables);
    } catch (e) {
        console.error("FAIL:", e.message);
    }
}

main();
