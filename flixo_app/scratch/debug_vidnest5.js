/**
 * Extract the exact API call pattern from the chunk for goodstream/workers
 */
const https = require('https');

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const opts = {
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      headers: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://vidnest.fun/' },
      rejectUnauthorized: false, family: 4,
    };
    const req = https.request(opts, (res) => {
      const c = [];
      res.on('data', d => c.push(d));
      res.on('end', () => resolve(Buffer.concat(c).toString('utf8')));
    });
    req.on('error', reject);
    req.setTimeout(20000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

async function main() {
  // The big chunk with the goodstream context
  const body = await fetchUrl('https://vidnest.fun/_next/static/chunks/d0e408015bc235ae.js');
  
  // Find the function that uses the workers array
  const workerIdx = body.indexOf('vidnest-1.workers.dev');
  if (workerIdx >= 0) {
    console.log('=== Workers context (600 chars before and after) ===');
    const start = Math.max(0, workerIdx - 800);
    const end = Math.min(body.length, workerIdx + 1500);
    console.log(body.substring(start, end));
  }

  // Find goodstream context more broadly
  const goodIdx = body.indexOf('goodstream');
  if (goodIdx >= 0) {
    console.log('\n=== Goodstream function (1500 chars around it) ===');
    const start = Math.max(0, goodIdx - 1500);
    const end = Math.min(body.length, goodIdx + 1500);
    console.log(body.substring(start, end));
  }

  // Find ALL occurrences of "movie" in the JS
  const movieCalls = [...body.matchAll(/[`"'\/](?:movie|tmdb|imdb)[`"'\/\s]*/gi)];
  console.log('\n=== All "movie/tmdb/imdb" references ===');
  movieCalls.slice(0, 20).forEach(m => {
    const i = m.index;
    console.log(body.substring(Math.max(0, i-30), i+100));
    console.log('---');
  });
}

main().catch(e => console.error('Fatal:', e.message));
