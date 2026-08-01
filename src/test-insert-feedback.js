async function main() {
    const supabaseUrl = "https://crlrgszzibpkqfixlmbw.supabase.co";
    const anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNybHJnc3p6aWJwa3FmaXhsbWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3MDYzMTYsImV4cCI6MjEwMDI4MjMxNn0.bvvinUdrMQ8ecQrEi6eLlaTYzNQhKDLRehS0Rn5zMhk";
    
    // Simulate user_id = ddbe2890-0505-4044-a7bc-80c5de21f3d6 (owner of Astraventa)
    const testFeedback = {
        user_id: "ddbe2890-0505-4044-a7bc-80c5de21f3d6",
        category: "idea",
        content: "Test feedback from AGY sandbox tool",
        device_info: {
            platform: "android",
            app_version: "1.0.25"
        }
    };
    
    try {
        console.log("Inserting feedback row via REST...");
        const response = await fetch(`${supabaseUrl}/rest/v1/feedbacks`, {
            method: 'POST',
            headers: {
                'apikey': anonKey,
                'Authorization': `Bearer ${anonKey}`,
                'Content-Type': 'application/json',
                'Prefer': 'return=representation'
            },
            body: JSON.stringify(testFeedback)
        });
        
        console.log("Status:", response.status);
        const text = await response.text();
        console.log("Response:", text);
    } catch (e) {
        console.error("HTTP Request failed:", e);
    }
}

main();
