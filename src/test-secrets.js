import tokenStore from './tokenStore.js';

async function main() {
    // Use ddbe2890-0505-4044-a7bc-80c5de21f3d6 (owner of Astraventa)
    const userId = "ddbe2890-0505-4044-a7bc-80c5de21f3d6";
    await tokenStore.syncFromDatabase(userId);
    const tokens = tokenStore.getTokens(userId);
    if (!tokens) {
        console.error("No tokens found for user!");
        return;
    }
    
    const projectRef = "hqywadiibynypygskyif"; // Astraventa shorthand ref
    console.log("Fetching secrets for project:", projectRef);
    
    try {
        const response = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/secrets`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${tokens.access_token}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log("Status:", response.status);
        const data = await response.json();
        console.log("Secrets response:", data);
    } catch (e) {
        console.error("Fetch failed:", e);
    }
}

main();
