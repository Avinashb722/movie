const http = require('http');
const https = require('https');
const { URL } = require('url');

function directFetch(targetUrl, options = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(targetUrl);
    const client = parsed.protocol === 'https:' ? https : http;
    const reqOptions = {
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path: parsed.pathname + parsed.search,
      method: options.method || 'GET',
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        ...(options.headers || {}),
      },
      rejectUnauthorized: false,
    };

    const req = client.request(reqOptions, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    });
    
    req.on('error', reject);
    req.end();
  });
}

async function run() {
  try {
    const streamId = '9krr00lvldgd';
    console.log('1. Fetching LookMovie embed page...');
    const lookmoviePage = await directFetch(`https://lookmovie2.skin/e/${streamId}`, {
      headers: {
        'Referer': 'https://streamsrcs.2embed.cc/'
      }
    });
    
    const evalMatch = lookmoviePage.body.match(/eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)/);
    if (!evalMatch) {
      console.log('Eval match not found');
      return;
    }
    
    const code = evalMatch[0].trim().substring(5, evalMatch[0].trim().length - 1);
    const runUnpacker = new Function('return (' + code + ');');
    const unpacked = runUnpacker();
    
    const hls4Match = unpacked.match(/"hls4"\s*:\s*"([^"]+)"/);
    if (!hls4Match) {
      console.log('hls4 match not found');
      return;
    }
    
    const streamUrl = `https://lookmovie2.skin${hls4Match[1]}`;
    console.log('Resolved HLS4 URL:', streamUrl);
    
    console.log('\n2. Testing HLS4 URL request with origin Referer (https://lookmovie2.skin/)...');
    const res = await directFetch(streamUrl, {
      headers: {
        'Referer': 'https://lookmovie2.skin/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
      }
    });
    
    console.log('Response Status:', res.status);
    
  } catch (e) {
    console.error('Error:', e);
  }
}

run();
