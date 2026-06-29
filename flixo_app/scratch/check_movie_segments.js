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
        'Accept': '*/*',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        ...(options.headers || {}),
      },
      rejectUnauthorized: false,
    };

    const req = client.request(reqOptions, (res) => {
      let chunks = [];
      res.on('data', d => chunks.push(d));
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
    });
    
    req.on('error', reject);
    req.end();
  });
}

async function run() {
  try {
    const streamId = '9krr00lvldgd';
    const lookmoviePage = await directFetch(`https://lookmovie2.skin/e/${streamId}`, {
      headers: {
        'Referer': 'https://streamsrcs.2embed.cc/'
      }
    });
    
    const evalMatch = lookmoviePage.body.toString().match(/eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)/);
    const code = evalMatch[0].trim().substring(5, evalMatch[0].trim().length - 1);
    const runUnpacker = new Function('return (' + code + ');');
    const unpacked = runUnpacker();
    const hls4Match = unpacked.match(/"hls4"\s*:\s*"([^"]+)"/);
    const streamUrl = `https://lookmovie2.skin${hls4Match[1]}`;
    
    const parsed = new URL(streamUrl);
    const basePath = parsed.pathname.substring(0, parsed.pathname.lastIndexOf('/') + 1);
    const indexUrl = `https://lookmovie2.skin${basePath}index-v1-a1.m3u8`;
    
    console.log('Fetching index.m3u8...');
    const indexRes = await directFetch(indexUrl, {
      headers: { 'Referer': streamUrl }
    });
    
    const playlistText = indexRes.body.toString();
    const lines = playlistText.split('\n');
    const segmentUrls = lines.filter(l => l.trim().startsWith('https://'));
    
    console.log('Total segments:', segmentUrls.length);
    
    // Check first segment (usually an ad)
    console.log('\nDownloading Segment 0 (first):', segmentUrls[0]);
    const seg0Res = await directFetch(`https://ver-orcin-alpha.vercel.app/api?url=${encodeURIComponent(segmentUrls[0])}`, {
      headers: { 'Range': 'bytes=0-20' }
    });
    console.log('Segment 0 First 20 Bytes:', seg0Res.body.slice(0, 20).toString('hex'));
    
    // Check segment 50 (deep inside the movie)
    console.log('\nDownloading Segment 50 (movie):', segmentUrls[50]);
    const seg50Res = await directFetch(`https://ver-orcin-alpha.vercel.app/api?url=${encodeURIComponent(segmentUrls[50])}`, {
      headers: { 'Range': 'bytes=0-20' }
    });
    console.log('Segment 50 First 20 Bytes:', seg50Res.body.slice(0, 20).toString('hex'));
    
  } catch (e) {
    console.error('Error:', e);
  }
}

run();
