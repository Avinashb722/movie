const http = require('http');
const https = require('https');

function httpGet(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const lib = parsed.protocol === 'https:' ? https : http;
    const req = lib.get(url, { headers }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body: data, headers: res.headers }));
    });
    req.on('error', reject);
  });
}

async function run() {
  try {
    console.log('Fetching 2embed page...');
    const res = await httpGet('https://www.2embed.cc/embed/tt33988385', {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    });
    
    console.log('Status:', res.status);
    
    // Find all links/iframes
    const matches = res.body.match(/(https?:\/\/[^\s"'<>]+)/g) || [];
    const unique = [...new Set(matches)];
    console.log('Found URLs on page:');
    unique.forEach(url => {
      if (url.includes('embed') || url.includes('player') || url.includes('stream') || url.includes('2embed') || url.includes('lookmovie') || url.includes('swish')) {
        console.log(' -', url);
      }
    });
    
  } catch (e) {
    console.error('Error:', e);
  }
}

run();
