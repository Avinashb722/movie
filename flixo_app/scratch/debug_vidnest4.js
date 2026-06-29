/**
 * Deep scan of d0e408015bc235ae.js which had stream API fetch calls
 */
const https = require('https');

function fetchUrl(url, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const opts = {
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*',
        'Referer': 'https://vidnest.fun/',
      },
      rejectUnauthorized: false,
      family: 4,
    };
    const req = https.request(opts, (res) => {
      const chunks = [];
      res.on('data', d => chunks.push(d));
      res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    });
    req.on('error', reject);
    req.setTimeout(20000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

async function main() {
  console.log('=== Deep scanning d0e408015bc235ae.js ===\n');

  const body = await fetchUrl('https://vidnest.fun/_next/static/chunks/d0e408015bc235ae.js');
  console.log(`Chunk size: ${body.length} chars\n`);

  // Find eI variable - the base API URL
  const eI_matches = body.match(/[a-z]{1,3}I\s*=\s*["'`]([^"'`]+)["'`]/g);
  console.log('eI-like vars (base URLs):', eI_matches ? eI_matches.slice(0, 10) : 'NONE');

  // Find all string literals that look like URLs
  const urlLiterals = [...body.matchAll(/["'`](https?:\/\/[^"'`\s]{5,})/g)].map(m => m[1]);
  console.log('\nAll URL literals:', [...new Set(urlLiterals)]);

  // Find all fetch calls
  const fetchCalls = [...body.matchAll(/fetch\s*\(\s*[`"']([^`"']+)/g)].map(m => m[1]);
  console.log('\nfetch() calls:', fetchCalls.length ? fetchCalls : 'NONE');

  // Find template literal fetch calls
  const templateFetch = [...body.matchAll(/fetch\s*\(`([^`]+)`/g)].map(m => m[1]);
  console.log('\nTemplate literal fetch():', templateFetch.length ? templateFetch : 'NONE');

  // Find the section around "goodstream" or "flashstream"
  const goodIdx = body.indexOf('goodstream');
  if (goodIdx >= 0) {
    console.log('\n--- goodstream context (±500 chars) ---');
    console.log(body.substring(Math.max(0, goodIdx - 200), goodIdx + 500));
  }

  const flashIdx = body.indexOf('flashstream');
  if (flashIdx >= 0) {
    console.log('\n--- flashstream context (±500 chars) ---');
    console.log(body.substring(Math.max(0, flashIdx - 200), flashIdx + 500));
  }
}

main().catch(e => console.error('Fatal:', e.message));
