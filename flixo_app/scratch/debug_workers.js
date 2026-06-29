/**
 * Query vidnest Cloudflare Workers API for movie streams
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
        'Accept': 'application/json, */*',
        'Origin': 'https://vidnest.fun',
        'Referer': 'https://vidnest.fun/',
        ...extraHeaders,
      },
      rejectUnauthorized: false,
      family: 4,
    };
    const req = https.request(opts, (res) => {
      if ([301, 302, 307, 308].includes(res.statusCode) && res.headers.location) {
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

// Vidnest Cloudflare Workers (stream resolvers)
const workers = [
  'https://nameless-mountain-a9f1.vidnest-1.workers.dev',
  'https://twilight-flower-97d4.vidnest-2.workers.dev',
  'https://billowing-sun-2fe0.vidnest-3.workers.dev',
  'https://empty-leaf-1700.vudnest-4.workers.dev',
];

async function tryWorker(base) {
  const paths = [
    `/movie/${TMDB_ID}`,
    `/api/movie/${TMDB_ID}`,
    `/stream/movie/${TMDB_ID}`,
    `/movie?tmdb=${TMDB_ID}`,
    `/${TMDB_ID}`,
  ];
  for (const path of paths) {
    const url = base + path;
    process.stdout.write(`  GET ${url} ... `);
    try {
      const r = await fetchUrl(url);
      console.log(`${r.status} (${r.body.length} chars)`);
      if (r.status < 400 && r.body.length > 10) {
        console.log(`  Body preview: ${r.body.substring(0, 500)}`);
        const m3u8 = r.body.match(/https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*/gi);
        if (m3u8) console.log('  m3u8:', m3u8);
        return true;
      }
    } catch (e) {
      console.log(`ERROR: ${e.message}`);
    }
  }
  return false;
}

async function main() {
  console.log(`=== Testing Vidnest CF Workers for TMDB: ${TMDB_ID} ===\n`);

  for (const worker of workers) {
    console.log(`\nWorker: ${worker}`);
    const found = await tryWorker(worker);
    if (found) break;
  }
}

main().catch(e => console.error('Fatal:', e.message));
