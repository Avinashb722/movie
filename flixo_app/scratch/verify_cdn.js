const http = require('http');
const https = require('https');

function httpGet(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const lib = parsed.protocol === 'https:' ? https : http;
    const req = lib.get(url, { headers }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
  });
}

async function run() {
  try {
    console.log('1. Resolving URL from local proxy...');
    const resolverRes = await httpGet('http://localhost:3009/resolve-2embed?imdbId=tt33988385');
    const data = JSON.parse(resolverRes.body);
    const resolvedUrl = data.url;
    console.log('Resolved URL:', resolvedUrl);
    
    const idMatch = resolvedUrl.match(/\/([a-z0-9]+)_n\/master\.m3u8/i);
    const streamId = idMatch ? idMatch[1] : '9krr00lvldgd';
    const playerReferer = `https://lookmovie2.skin/e/${streamId}`;
    
    const fullBrowserHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Referer': playerReferer,
      'Origin': 'https://lookmovie2.skin',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'identity',
      'Sec-Ch-Ua': '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
      'Sec-Ch-Ua-Mobile': '?0',
      'Sec-Ch-Ua-Platform': '"Windows"',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'cross-site'
    };
    
    console.log('\nTesting with Full Browser Metadata Headers...');
    const res = await httpGet(resolvedUrl, fullBrowserHeaders);
    console.log('Result Status:', res.status, 'Body length:', res.body.length);
    if (res.status === 200) {
      console.log('✅ SUCCESS! The CDN returned 200 OK.');
      console.log(res.body.split('\n').slice(0, 3).join('\n'));
    } else {
      console.log('❌ FAILED. Status:', res.status);
    }
    
  } catch (e) {
    console.error('Error:', e);
  }
}

run();
