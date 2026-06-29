const http = require('http');

http.get('http://localhost:3009/resolve-2embed?imdbId=tt33988385', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('Status:', res.statusCode);
    console.log('Body:', data);
  });
}).on('error', (e) => {
  console.error('Error connecting to local proxy:', e.message);
});
