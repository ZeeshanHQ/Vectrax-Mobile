async function main() {
    const supabaseUrl = "https://crlrgszzibpkqfixlmbw.supabase.co";
    const anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNybHJnc3p6aWJwa3FmaXhsbWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3MDYzMTYsImV4cCI6MjEwMDI4MjMxNn0.bvvinUdrMQ8ecQrEi6eLlaTYzNQhKDLRehS0Rn5zMhk";
    
    try {
        console.log("Checking feedbacks endpoint...");
        const response = await fetch(`${supabaseUrl}/rest/v1/feedbacks?select=*&limit=1`, {
            headers: {
                'apikey': anonKey,
                'Authorization': `Bearer ${anonKey}`
            }
        });
        
        console.log("Status:", response.status);
        const text = await response.text();
        console.log("Response:", text);
    } catch (e) {
        console.error("HTTP Request failed:", e);
    }
}

main();
