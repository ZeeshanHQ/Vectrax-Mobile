import tokenStore from './tokenStore.js';
import FunctionManager from './api/FunctionManager.js';
import SupabaseManager from './SupabaseManager.js';

async function main() {
    const userId = "ddbe2890-0505-4044-a7bc-80c5de21f3d6";
    await tokenStore.syncFromDatabase(userId);
    const tokens = tokenStore.getTokens(userId);
    if (!tokens) {
        console.error("No tokens found for user!");
        return;
    }
    
    const client = new SupabaseManager().getManagementClient(tokens.access_token);
    const fm = new FunctionManager(client);
    const projectRef = "hqywadiibynypygskyif";
    
    try {
        console.log("Listing functions...");
        const funcs = await fm.listFunctions(projectRef);
        console.log("Functions list:", funcs);
    } catch (e) {
        console.error("Failed:", e.message);
    }
}

main();
