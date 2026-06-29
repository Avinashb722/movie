const http = require('http');
const https = require('https');
const { URL } = require('url');

// Fetch a fresh direct stream URL using the localhost proxy
function getStreamUrl() {
  return new Promise((resolve, reject) => {
    http.get('http://localhost:3009/resolve-2embed?imdbId=tt33988385', (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body).url);
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

function testCdnRequest(url) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const reqOptions = {
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'referer': 'https://lookmovie2.skin/',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'accept': '*/*',
        'accept-language': 'en-US,en;q=0.9',
      },
      rejectUnauthorized: false,
      family: 4, // Force IPv4
    };

    console.log('Sending request to CDN:', parsed.hostname);
    const req = https.request(reqOptions, (res) => {
      console.log('Status:', res.statusCode);
      console.log('Headers:', JSON.stringify(res.headers, null, 2));
      resolve(res.statusCode);
    });
    
    req.on('error', reject);
    req.end();
  });
}

async function run() {
  try {
    const url = await getStreamUrl();
    console.log('Resolved URL:', url);
    await testCdnRequest(url);
  } catch (e) {
    console.error('Error:', e);
  }
}

run();
