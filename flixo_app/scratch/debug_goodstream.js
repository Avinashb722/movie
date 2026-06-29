/**
 * Query goodstream.cc and flashstream.cc APIs for KGF stream
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
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/html, */*',
        'Origin': 'https://vidnest.fun',
        'Referer': 'https://vidnest.fun/',
        ...extraHeaders,
      },
      rejectUnauthorized: false,
      family: 4,
    };
    const req = https.request(opts, (res) => {
      if ([301, 302, 307, 308].includes(res.statusCode) && res.headers.location) {
        console.log(`  Redirect -> ${res.headers.location}`);
        const loc = res.headers.location.startsWith('http') 
          ? res.headers.location 
          : `https://${parsed.hostname}${res.headers.location}`;
        return fetchUrl(loc, extraHeaders).then(resolve).catch(reject);
      }
      const chunks = [];
      res.on('data', d => chunks.push(d));
      res.on('end', () => resolve({ 
        status: res.statusCode, 
        headers: res.headers,
        body: Buffer.concat(chunks).toString('utf8') 
      }));
    });
    req.on('error', reject);
    req.setTimeout(20000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

const TMDB_ID = process.argv[2] || '564147'; // KGF Chapter 1

async function tryApi(url) {
  console.log(`\nGET ${url}`);
  try {
    const r = await fetchUrl(url);
    console.log(`  Status: ${r.status}`);
    if (r.status < 400) {
      console.log(`  Body (${r.body.length} chars): ${r.body.substring(0, 800)}`);
      const m3u8 = r.body.match(/https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*/gi);
      if (m3u8) console.log('  m3u8 URLs:', m3u8.slice(0, 5));
    }
  } catch (e) {
    console.log(`  Error: ${e.message}`);
  }
}

async function main() {
  console.log(`=== Testing stream APIs for TMDB: ${TMDB_ID} ===`);

  // goodstream.cc API candidates
  const candidates = [
    `https://goodstream.cc/movie/${TMDB_ID}`,
    `https://goodstream.cc/api/movie/${TMDB_ID}`,
    `https://goodstream.cc/api/stream?tmdb=${TMDB_ID}`,
    `https://goodstream.cc/stream/movie/${TMDB_ID}`,
    `https://goodstream.cc/sources/movie/${TMDB_ID}`,
    `https://goodstream.cc/movie?tmdb=${TMDB_ID}`,
    // flashstream.cc
    `https://flashstream.cc/movie/${TMDB_ID}`,
    `https://flashstream.cc/api/movie/${TMDB_ID}`,
    `https://flashstream.cc/stream/movie/${TMDB_ID}`,
    `https://flashstream.cc/sources/movie/${TMDB_ID}`,
  ];

  for (const url of candidates) {
    await tryApi(url);
  }
}

main().catch(e => console.error('Fatal:', e.message));
