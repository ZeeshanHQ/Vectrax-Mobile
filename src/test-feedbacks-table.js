import pg from 'pg';
const { Client } = pg;

async function main() {
    const client = new Client({
        connectionString: "postgresql://postgres.crlrgszzibpkqfixlmbw:SupaPulseDbSecurePass2026!@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres",
        ssl: {
            rejectUnauthorized: false
        }
    });
    
    try {
        await client.connect();
        
        console.log("1. Table columns and details:");
        const columnsRes = await client.query(`
            SELECT column_name, data_type, is_nullable, column_default 
            FROM information_schema.columns 
            WHERE table_name = 'feedbacks' AND table_schema = 'public';
        `);
        console.log(columnsRes.rows);
        
        console.log("\n2. Table triggers:");
        const triggersRes = await client.query(`
            SELECT trigger_name, event_manipulation, action_statement 
            FROM information_schema.triggers 
            WHERE event_object_table = 'feedbacks' AND event_object_schema = 'public';
        `);
        console.log(triggersRes.rows);
        
        console.log("\n3. Check constraints:");
        const checkRes = await client.query(`
            SELECT tc.constraint_name, cc.check_clause
            FROM information_schema.table_constraints tc
            JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
            WHERE tc.table_name = 'feedbacks' AND tc.table_schema = 'public';
        `);
        console.log(checkRes.rows);
        
    } catch (e) {
        console.error("Query failed:", e);
    } finally {
        await client.end();
    }
}

main();
