import pg from 'pg';
const { Pool } = pg;

async function main() {
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false }
    });
    
    try {
        console.log("Listing all rows in project_cache...");
        const res = await pool.query(
            "SELECT * FROM project_cache;"
        );
        console.log("Cached Projects:", JSON.stringify(res.rows, null, 2));
    } catch (e) {
        console.error("FAIL:", e.message);
    } finally {
        await pool.end();
    }
}

main();
