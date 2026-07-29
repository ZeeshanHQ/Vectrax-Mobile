

const payload = {
    prompt: 'list all users',
    schema: {}
};

fetch('http://localhost:3000/api/ai/generate-sql', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
})
    .then(res => res.text())
    .then(text => console.log('Response:', text))
    .catch(err => console.error('Error:', err));
