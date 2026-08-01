async function main() {
    const supabaseUrl = "https://crlrgszzibpkqfixlmbw.supabase.co";
    const serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNybHJnc3p6aWJwa3FmaXhsbWJ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NDcwNjMxNiwiZXhwIjoyMTAwMjgyMzE2fQ.sWCkKXhTd19XKSVMD63FeU93lBFtl_2oSH1j6IFQNsY";
    
    try {
        console.log("Fetching OpenAPI spec with service role key...");
        const response = await fetch(`${supabaseUrl}/rest/v1/`, {
            headers: {
                'apikey': serviceRoleKey,
                'Authorization': `Bearer ${serviceRoleKey}`
            }
        });
        
        const spec = await response.json();
        if (spec.definitions && spec.definitions.feedbacks) {
            console.log("Feedbacks properties:", spec.definitions.feedbacks.properties);
        } else {
            console.log("Feedbacks table not in spec definitions.");
        }
    } catch (e) {
        console.error("HTTP spec fetch failed:", e);
    }
}

main();
