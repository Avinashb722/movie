/**
 * Find eC (base API URL) and test the actual stream endpoints
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
        'Accept': 'application/json, */*',
        'Origin': 'https://vidnest.fun', 'Referer': 'https://vidnest.fun/',
        ...extraHeaders,
      },
      rejectUnauthorized: false, family: 4,
    };
    const req = https.request(opts, (res) => {
      if ([301, 302, 307, 308].includes(res.statusCode) && res.headers.location) {
        const loc = res.headers.location.startsWith('http') ? res.headers.location : `https://${parsed.hostname}${res.headers.location}`;
        return fetchUrl(loc, extraHeaders).then(resolve).catch(reject);
      }
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
  const TMDB_ID = process.argv[2] || '564147'; // KGF

  // Find eC from the chunk
  const chunk = await fetchUrl('https://vidnest.fun/_next/static/chunks/d0e408015bc235ae.js');
  
  // eC is likely assigned before the movieUrl entries
  // Look for eC = "..."
  const eCMatch = chunk.body.match(/[a-z]{1,3}C\s*=\s*["'`](https?:\/\/[^"'`]+)["'`]/g);
  console.log('eC-like vars:', eCMatch);

  // Let's find the var assigned just before "hollymoviehd"
  const hollyIdx = chunk.body.indexOf('hollymoviehd');
  if (hollyIdx >= 0) {
    const context = chunk.body.substring(Math.max(0, hollyIdx - 500), hollyIdx + 200);
    console.log('\neC context near hollymoviehd:');
    console.log(context);
  }

  // Search the chunk for the base URL pattern
  const baseUrlMatch = chunk.body.match(/(?:eC|EC|baseUrl|apiBase|apiUrl)\s*=\s*["'`](https?:\/\/[^"'`\s]+)/);
  if (baseUrlMatch) {
    const baseUrl = baseUrlMatch[1];
    console.log('\nFound base URL (eC):', baseUrl);

    // Now test the actual movie endpoints
    const endpoints = [
      `${baseUrl}/hollymoviehd/movie/${TMDB_ID}`,
      `${baseUrl}/videasy/movie/${TMDB_ID}`,
      `${baseUrl}/moviebox/movie/${TMDB_ID}`,
      `${baseUrl}/moviesapi/movie/${TMDB_ID}`,
      `${baseUrl}/allmovies/movie/${TMDB_ID}`,
    ];

    console.log('\n=== Testing movie stream endpoints ===\n');
    for (const url of endpoints) {
      console.log(`GET ${url}`);
      try {
        const r = await fetchUrl(url);
        console.log(`  Status: ${r.status}, body: ${r.body.substring(0, 300)}`);
        const m3u8 = r.body.match(/https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*/gi);
        if (m3u8) console.log('  m3u8:', m3u8);
      } catch (e) {
        console.log(`  Error: ${e.message}`);
      }
    }
  }
}

main().catch(e => console.error('Fatal:', e.message));
