/**
 * Find and execute the decryptCipherResponse function to decrypt KGF stream data
 */
const https = require('https');
const { createDecipheriv } = require('crypto');

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

const TMDB_ID = process.argv[2] || '564147'; // KGF

async function main() {
  console.log(`=== Finding decryption key for TMDB: ${TMDB_ID} ===\n`);

  // Find decryptCipherResponse in the chunk files
  const chunksThatMatter = [
    '/_next/static/chunks/d0e408015bc235ae.js',
    '/_next/static/chunks/31dd2cd50f2a288b.js',
    '/_next/static/chunks/6c30b25e2bb0f61b.js',
  ];

  let decryptSource = '';
  let decryptKey = '';
  let decryptIv = '';
  
  for (const chunkPath of chunksThatMatter) {
    const url = `https://vidnest.fun${chunkPath}`;
    process.stdout.write(`Scanning ${chunkPath}... `);
    const r = await fetchUrl(url);
    console.log(`${r.body.length} chars`);

    if (r.body.includes('decryptCipherResponse') || r.body.includes('AES') || r.body.includes('createDecipher')) {
      console.log('  ✅ Contains decryption code!');
      decryptSource = r.body;
      
      // Look for AES key/IV patterns
      const keyMatch = r.body.match(/key\s*[=:]\s*["'`]([a-zA-Z0-9+/=]{16,64})["'`]/g);
      const ivMatch = r.body.match(/(?:iv|IV)\s*[=:]\s*["'`]([a-zA-Z0-9+/=]{16,64})["'`]/g);
      const secretMatch = r.body.match(/(?:secret|cipher|decrypt)[^"'`]*["'`]([a-zA-Z0-9+/=]{16,64})["'`]/gi);
      
      if (keyMatch) console.log('  Keys:', keyMatch.slice(0, 5));
      if (ivMatch) console.log('  IVs:', ivMatch.slice(0, 5));
      if (secretMatch) console.log('  Secrets:', secretMatch.slice(0, 5));
      
      // Find the exact decryptCipherResponse function
      const funcIdx = r.body.indexOf('decryptCipherResponse');
      if (funcIdx >= 0) {
        console.log('\n  decryptCipherResponse context:');
        console.log(r.body.substring(Math.max(0, funcIdx - 100), funcIdx + 1000));
      }
    }
  }

  // Try to parse the encrypted response manually
  console.log('\n=== Fetching encrypted responses ===');
  const endpoints = [
    `https://new.vidnest.fun/moviebox/movie/${TMDB_ID}`,
    `https://new.vidnest.fun/moviesapi/movie/${TMDB_ID}`,
    `https://new.vidnest.fun/hollymoviehd/movie/${TMDB_ID}`,
  ];

  for (const url of endpoints) {
    const r = await fetchUrl(url);
    if (r.status === 200) {
      console.log(`\n${url.split('/').pop()}/${TMDB_ID}:`);
      try {
        const parsed = JSON.parse(r.body);
        console.log('  Keys:', Object.keys(parsed));
        const dataStr = parsed.data || parsed.encrypted || parsed.content || '';
        if (dataStr) {
          console.log('  data preview:', dataStr.substring(0, 50));
          console.log('  data length:', dataStr.length);
          // Try base64 decode
          try {
            const decoded = Buffer.from(dataStr, 'base64').toString('utf8');
            console.log('  base64 decoded:', decoded.substring(0, 200));
          } catch (e) {}
        }
      } catch (e) {
        console.log('  Raw (not JSON):', r.body.substring(0, 200));
      }
    }
  }
}

main().catch(e => console.error('Fatal:', e.message));
