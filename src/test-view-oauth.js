import pg from 'pg';
const { Pool } = pg;

async function main() {
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false }
    });
    
    try {
        console.log("Listing all rows in oauth_tokens...");
        const res = await pool.query(
            "SELECT user_id, expires_at, updated_at FROM oauth_tokens;"
        );
        console.log("OAuth Tokens:", JSON.stringify(res.rows, null, 2));
    } catch (e) {
        console.error("FAIL:", e.message);
    } finally {
        await pool.end();
    }
}

main();
