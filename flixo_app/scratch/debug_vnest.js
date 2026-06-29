/**
 * Debug vnest player for KGF / non-swish 2embed pages
 */
const https = require('https');

const TMDB_ID = process.argv[2] || '564147'; // KGF Chapter 1

function fetchText(hostname, path, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname,
      port: 443,
      path,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
        ...extraHeaders,
      },
      rejectUnauthorized: false,
      family: 4,
    };
    const req = https.request(opts, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    });
    req.on('error', reject);
    req.setTimeout(15000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

async function main() {
  console.log(`=== Debugging vnest player for TMDB: ${TMDB_ID} ===\n`);

  const r = await fetchText('streamsrcs.2embed.cc', `/vnest?tmdb=${TMDB_ID}`, {
    'Referer': 'https://www.2embed.cc/',
  });

  console.log(`HTTP Status: ${r.status}`);
  console.log(`Location:`, r.headers.location || '(no redirect)');
  console.log(`Body length: ${r.body.length} chars\n`);

  // Look for m3u8 streams
  const m3u8 = r.body.match(/https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*/gi);
  console.log('Direct m3u8:', m3u8 || 'NONE');

  // Look for eval/packed JS
  const packed = r.body.match(/eval\(function\(p,a,c,k,e/);
  console.log('Packed JS:', packed ? 'YES' : 'NONE');

  // Look for file or source attributes
  const fileSrcs = [...r.body.matchAll(/(?:file|src|source)\s*[:=]\s*["']([^"']+\.m3u8[^"']*)/gi)].map(m => m[1]);
  console.log('file/src/source m3u8:', fileSrcs.length ? fileSrcs : 'NONE');

  // Look for JSON data  
  const json = r.body.match(/\{[^{}]{20,}\}/g);
  console.log('JSON blocks (first 3):', json ? json.slice(0, 3) : 'NONE');

  // Look for hls refs
  const hls = r.body.match(/"hls[0-9]?"\s*:\s*"[^"]+"/gi);
  console.log('HLS keys:', hls || 'NONE');

  console.log('\n--- vnest body (first 3000 chars) ---');
  console.log(r.body.substring(0, 3000));
}

main().catch(e => console.error('Error:', e.message));
