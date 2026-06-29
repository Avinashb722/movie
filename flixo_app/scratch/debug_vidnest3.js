/**
 * Find the API endpoint inside vidnest.fun Next.js chunks
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
        ...extraHeaders,
      },
      rejectUnauthorized: false,
      family: 4,
    };
    const req = https.request(opts, (res) => {
      const chunks = [];
      res.on('data', d => chunks.push(d));
      res.on('end', () => resolve({ 
        status: res.statusCode, 
        body: Buffer.concat(chunks).toString('utf8') 
      }));
    });
    req.on('error', reject);
    req.setTimeout(20000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

const TMDB_ID = process.argv[2] || '564147';

// The known chunk list from the page
const chunks = [
  '/_next/static/chunks/00cb8966bcf22375.js',
  '/_next/static/chunks/d4cf4caae891f664.js',
  '/_next/static/chunks/69be39811437728d.js',
  '/_next/static/chunks/744355e03808d4c7.js',
  '/_next/static/chunks/ff1a16fafef87110.js',
  '/_next/static/chunks/b5dc6c688de67194.js',
  '/_next/static/chunks/4fa3ead9609cf2d6.js',
  '/_next/static/chunks/66b231c2403f619d.js',
  '/_next/static/chunks/6c30b25e2bb0f61b.js',
  '/_next/static/chunks/31dd2cd50f2a288b.js',
  '/_next/static/chunks/d0e408015bc235ae.js',
  '/_next/static/chunks/a6dad97d9634a72d.js',
  '/_next/static/chunks/a3f6c22d97a69088.js',
];

async function main() {
  console.log('=== Scanning vidnest.fun JS chunks for API endpoints ===\n');

  for (const chunk of chunks) {
    const url = `https://vidnest.fun${chunk}`;
    process.stdout.write(`Checking ${chunk}... `);
    const r = await fetchUrl(url);
    
    // Look for API-relevant patterns
    const apiPaths = r.body.match(/["'`]\/api\/[^"'`\s]+/g);
    const fetchCalls = r.body.match(/fetch\(["'`][^"'`]+/g);
    const m3u8 = r.body.match(/m3u8/g);
    const tmdb = r.body.match(/tmdb/gi);
    const hls = r.body.match(/hls/gi);
    
    const isInteresting = apiPaths || m3u8 || tmdb || hls;
    
    if (isInteresting) {
      console.log(`✅ INTERESTING (${r.body.length} chars)`);
      if (apiPaths) console.log('  API paths:', [...new Set(apiPaths)]);
      if (fetchCalls) console.log('  fetch calls:', [...new Set(fetchCalls)].slice(0, 5));
      
      // Look for URLs containing known patterns
      const embedApi = [...r.body.matchAll(/["'`](https?:\/\/[^"'`\s]*(?:api|stream|embed|m3u8)[^"'`\s]*)/gi)].map(m => m[1]);
      if (embedApi.length) console.log('  stream/api URLs:', [...new Set(embedApi)].slice(0, 10));
      
      // Look for any endpoint with movie/tmdb pattern
      const movieApi = r.body.match(/["'`][^"'`]*(?:movie|tmdb|imdb)[^"'`]*/gi);
      if (movieApi) console.log('  movie/tmdb refs:', [...new Set(movieApi)].slice(0, 5));
    } else {
      console.log(`(${r.body.length} chars, no stream hints)`);
    }
  }

  // Also try direct API call with tmdb ID
  console.log('\n=== Trying direct API calls ===');
  const apiCandidates = [
    `https://vidnest.fun/api/movie/${TMDB_ID}`,
    `https://vidnest.fun/api/stream/movie/${TMDB_ID}`,
    `https://vidnest.fun/api/embed/movie/${TMDB_ID}`,
    `https://vidnest.fun/api/sources?tmdb=${TMDB_ID}`,
    `https://vidnest.fun/api/sources/movie/${TMDB_ID}`,
  ];
  
  for (const api of apiCandidates) {
    process.stdout.write(`\nTrying: ${api}\n`);
    try {
      const r = await fetchUrl(api, { 'Accept': 'application/json' });
      console.log(`  Status: ${r.status}`);
      if (r.status < 400) {
        console.log(`  Response: ${r.body.substring(0, 500)}`);
      }
    } catch (e) {
      console.log(`  Error: ${e.message}`);
    }
  }
}

main().catch(e => console.error('Fatal:', e.message));
