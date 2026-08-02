async function main() {
    const supabaseUrl = "https://crlrgszzibpkqfixlmbw.supabase.co";
    const serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNybHJnc3p6aWJwa3FmaXhsbWJ3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NDcwNjMxNiwiZXhwIjoyMTAwMjgyMzE2fQ.sWCkKXhTd19XKSVMD63FeU93lBFtl_2oSH1j6IFQNsY";
    
    try {
        console.log("Checking RLS policies...");
        const response = await fetch(`${supabaseUrl}/rest/v1/rpc/get_policies`, {
            method: 'POST',
            headers: {
                'apikey': serviceRoleKey,
                'Authorization': `Bearer ${serviceRoleKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ tablename: 'feedbacks' })
        });
        
        console.log("Status:", response.status);
        const text = await response.text();
        console.log("Response:", text);
    } catch (e) {
        console.error("HTTP Request failed:", e);
    }
}

main();
