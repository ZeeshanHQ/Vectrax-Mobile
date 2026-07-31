import AiManager from './api/AiManager.js';

async function main() {
    const ai = new AiManager();
    const prompt = "show me data of telecom table";
    const schema = {
        "telecom": {
            "columns": [
                { "name": "id", "type": "int" },
                { "name": "phone_number", "type": "text" },
                { "name": "carrier", "type": "text" }
            ]
        }
    };
    
    try {
        console.log("Testing generateSql locally...");
        const sql = await ai.generateSql(prompt, schema);
        console.log("SUCCESS! Generated SQL:", sql);
    } catch (e) {
        console.error("FAIL:", e.message);
    }
}

main();
