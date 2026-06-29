/**
 * Extract the full decryptCipherResponse function and test decryption
 */
const https = require('https');

function fetchUrl(url, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const opts = {
      hostname: parsed.hostname, port: 443,
      path: parsed.pathname + parsed.search,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://vidnest.fun/',
      },
      rejectUnauthorized: false, family: 4,
    };
    const req = https.request(opts, (res) => {
      const c = [];
      res.on('data', d => c.push(d));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(c).toString('utf8') }));
    });
    req.on('error', reject);
    req.setTimeout(20000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

async function main() {
  const TMDB_ID = process.argv[2] || '564147';

  console.log('=== Extracting decryptCipherResponse from chunk 4fa3ead9609cf2d6.js ===\n');
  const r = await fetchUrl('https://vidnest.fun/_next/static/chunks/4fa3ead9609cf2d6.js');
  console.log(`Chunk size: ${r.body.length} chars\n`);
  
  // Print the full chunk to understand the decryption
  const idx = r.body.indexOf('decryptCipherResponse');
  console.log(`decryptCipherResponse position: ${idx}`);
  console.log('\n--- Full chunk (it is small - just print it all) ---');
  console.log(r.body);
}

main().catch(e => console.error('Fatal:', e.message));
