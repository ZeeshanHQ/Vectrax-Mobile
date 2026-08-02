async function main() {
    const supabaseUrl = "https://crlrgszzibpkqfixlmbw.supabase.co";
    const serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNybHJnc3p6aWJwa3FmaXhsbWJ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NDcwNjMxNiwiZXhwIjoyMTAwMjgyMzE2fQ.sWCkKXhTd19XKSVMD63FeU93lBFtl_2oSH1j6IFQNsY";
    
    const testFeedback = {
        user_id: "ddbe2890-0505-4044-a7bc-80c5de21f3d6",
        category: "bug",
        message: "Test feedback with emoji 😊🚀🔥"
    };
    
    try {
        console.log("Inserting feedback row via service role...");
        const response = await fetch(`${supabaseUrl}/rest/v1/feedbacks`, {
            method: 'POST',
            headers: {
                'apikey': serviceRoleKey,
                'Authorization': `Bearer ${serviceRoleKey}`,
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
