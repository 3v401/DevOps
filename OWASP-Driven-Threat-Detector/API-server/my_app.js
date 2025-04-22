const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
	res.send('Welcome to the API test');
});

app.get('/api/data', (req, res) => {
	res.json({message: 'Answer from the API response' });
});

app.listen(port, () => {
	console.log('API runs on port ${port}');
});
