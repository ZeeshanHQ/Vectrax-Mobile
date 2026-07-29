require('dotenv').config();
const https = require('https');

const API_KEY = process.env.SUPABASE_ACCESS_TOKEN || process.env.SUPABASE_PAT || process.env.SUPABASE_API_KEY;

const options = {
    hostname: 'api.supabase.com',
    port: 443,
    path: '/v1/projects',
    method: 'GET',
    headers: {
        'Authorization': `Bearer ${API_KEY}`
    }
};

const req = https.request(options, res => {
    let data = '';
    res.on('data', chunk => { data += chunk; });
    res.on('end', () => {
        try {
            const parsed = JSON.parse(data);
            console.log(JSON.stringify(parsed[0], null, 2));
        } catch (e) { console.error('Error parsing JSON:', data); }
    });
});
req.on('error', error => { console.error(error); });
req.end();
