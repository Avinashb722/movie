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
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Referer': 'https://www.2embed.cc/'
    };
    
    console.log('Fetching xps server...');
    const r1 = await httpGet('https://streamsrcs.2embed.cc/xps?imdb=tt33988385', headers);
    console.log('xps status:', r1.status);
    console.log('xps body length:', r1.body.length);
    console.log('xps body matches:');
    
    // Find any packed scripts or links in xps body
    const links = r1.body.match(/(https?:\/\/[^\s"'<>]+)/g) || [];
    console.log(links.slice(0, 5));
    
    console.log('\nFetching vesy server...');
    const r2 = await httpGet('https://streamsrcs.2embed.cc/vesy?tmdb=1367220', headers);
    console.log('vesy status:', r2.status);
    console.log('vesy body matches:');
    const links2 = r2.body.match(/(https?:\/\/[^\s"'<>]+)/g) || [];
    console.log(links2.slice(0, 5));
    
  } catch (e) {
    console.error('Error:', e);
  }
}

run();
