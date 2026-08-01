import pg from 'pg';
const { Client } = pg;

async function main() {
    const client = new Client({
        connectionString: "postgresql://postgres:SupaPulseDbSecurePass2026!@db.crlrgszzibpkqfixlmbw.supabase.co:5432/postgres"
    });
    
    try {
        await client.connect();
        
        const resTable = await client.query(`
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = 'feedbacks'
            );
        `);
        console.log("Feedbacks table exists:", resTable.rows[0].exists);
        
        if (!resTable.rows[0].exists) {
            console.log("Listing public tables...");
            const resTablesList = await client.query(`
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                ORDER BY table_name;
            `);
            console.log("Existing tables:", resTablesList.rows.map(r => r.table_name));
        } else {
            console.log("Describing feedbacks table...");
            const resColumns = await client.query(`
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_schema = 'public' 
                AND table_name = 'feedbacks';
            `);
            console.log("Columns:", resColumns.rows);
        }
    } catch (e) {
        console.error("Database query failed:", e);
    } finally {
        await client.end();
    }
}

main();
