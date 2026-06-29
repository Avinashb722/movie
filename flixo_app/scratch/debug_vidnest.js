/**
 * Analyze vidnest.fun player to extract m3u8 stream
 */
const https = require('https');
const http = require('http');

function fetchUrl(url, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const lib = parsed.protocol === 'https:' ? https : http;
    const opts = {
      hostname: parsed.hostname,
      port: parsed.protocol === 'https:' ? 443 : 80,
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
        ...extraHeaders,
      },
      rejectUnauthorized: false,
      family: 4,
    };
    const req = lib.request(opts, (res) => {
      if ([301, 302, 307, 308].includes(res.statusCode) && res.headers.location) {
        console.log(`  Redirecting to: ${res.headers.location}`);
        return fetchUrl(res.headers.location, extraHeaders).then(resolve).catch(reject);
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

async function tryUnpack(body) {
  const evalMatch = body.match(/eval\(function\(p,a,c,k,e,d?\)[\s\S]+?\.split\('\|'\)\)\)/);
  if (!evalMatch) return null;
  try {
    const code = evalMatch[0].trim().substring(5, evalMatch[0].trim().length - 1);
    const fn = new Function('return (' + code + ');');
    return fn();
  } catch (e) {
    return null;
  }
}

async function main() {
  const TMDB_ID = process.argv[2] || '564147'; // KGF

  console.log(`=== Analyzing vidnest.fun for TMDB: ${TMDB_ID} ===\n`);

  const vidnestUrl = `https://vidnest.fun/movie/${TMDB_ID}?autostart=true`;
  console.log(`Fetching: ${vidnestUrl}`);

  const r = await fetchUrl(vidnestUrl, {
    'Referer': `https://streamsrcs.2embed.cc/vnest?tmdb=${TMDB_ID}`,
  });

  console.log(`HTTP Status: ${r.status}, body length: ${r.body.length}\n`);

  // Check for packed JS
  const packed = await tryUnpack(r.body);
  if (packed) {
    console.log('✅ Found packed JS! Unpacked preview:');
    console.log(packed.substring(0, 1000));
    
    const hls4 = packed.match(/"hls4"\s*:\s*"([^"]+)"/);
    const hls2 = packed.match(/"hls2"\s*:\s*"([^"]+)"/);
    const m3u8 = packed.match(/["']https?:\/\/[^\s"']+\.m3u8[^\s"']*/gi);
    const file = packed.match(/"file"\s*:\s*"([^"]+)"/);
    
    if (hls4) console.log('\nhls4:', hls4[1]);
    if (hls2) console.log('hls2:', hls2[1]);
    if (file) console.log('file:', file[1]);
    if (m3u8) console.log('m3u8:', m3u8.slice(0, 5));
  } else {
    console.log('No packed JS found.');
  }

  // Look for stream URL patterns in raw body
  const m3u8Direct = r.body.match(/https?:\/\/[^\s"'`<>]+\.m3u8[^\s"'`<>]*/gi);
  console.log('\nDirect m3u8 in body:', m3u8Direct || 'NONE');

  const fileAttr = [...r.body.matchAll(/["'`]file["'`]\s*:\s*["'`]([^"'`]+)/gi)].map(m => m[1]);
  console.log('file: attrs:', fileAttr.length ? fileAttr : 'NONE');

  const sourceAttr = [...r.body.matchAll(/source\s*:\s*["'`]([^"'`]+)/gi)].map(m => m[1]);
  console.log('source: attrs:', sourceAttr.length ? sourceAttr : 'NONE');

  // Check API calls/fetch
  const fetchCalls = [...r.body.matchAll(/fetch\(["'`]([^"'`]+)/gi)].map(m => m[1]);
  console.log('fetch() calls:', fetchCalls.length ? fetchCalls : 'NONE');

  const scriptSrcs = [...r.body.matchAll(/script[^>]+src=["']([^"']+)/gi)].map(m => m[1]);
  console.log('script srcs:', scriptSrcs.length ? scriptSrcs : 'NONE');

  console.log('\n--- Body (first 3000 chars) ---');
  console.log(r.body.substring(0, 3000));
}

main().catch(e => console.error('Fatal:', e.message));
