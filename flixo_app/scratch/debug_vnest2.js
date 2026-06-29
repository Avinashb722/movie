/**
 * Fetch and analyze vnest.js + the API it calls to get streams
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
        'Accept': '*/*',
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
        headers: res.headers, 
        body: Buffer.concat(chunks).toString('utf8') 
      }));
    });
    req.on('error', reject);
    req.setTimeout(15000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

async function main() {
  const TMDB_ID = '564147'; // KGF Chapter 1
  const IMDB_ID = 'tt7838252';

  console.log('=== Analyzing vnest.js ===\n');
  
  // Fetch vnest.js
  const vnestJs = await fetchUrl('https://streamsrcs.2embed.cc/vnest.js', {
    'Referer': 'https://streamsrcs.2embed.cc/',
  });
  console.log(`vnest.js HTTP: ${vnestJs.status}, length: ${vnestJs.body.length}`);
  console.log('\n--- vnest.js content ---');
  console.log(vnestJs.body.substring(0, 5000));

  // Extract any API URL patterns from the JS
  const apiUrls = vnestJs.body.match(/https?:\/\/[^\s"'`<>]+/g);
  console.log('\nAPI URLs found in vnest.js:', apiUrls ? [...new Set(apiUrls)] : 'NONE');

  // Try fetching the stream API directly if we see a pattern
  const apiPattern = vnestJs.body.match(/fetch\s*\(\s*["'`]([^"'`]+)["'`]/g);
  console.log('fetch() calls:', apiPattern || 'NONE');

  // Also try the 2embed API endpoint approach
  console.log('\n=== Trying direct API approaches ===\n');
  
  // Try approach 1: vidmoly/vidsrc-style API
  const apiAttempts = [
    `https://2embed.skin/embed/${IMDB_ID}`,
    `https://www.2embed.skin/embed/${IMDB_ID}`,
    `https://2embed.cc/embed/${IMDB_ID}`,
  ];

  for (const apiUrl of apiAttempts) {
    console.log(`\nTrying: ${apiUrl}`);
    try {
      const r = await fetchUrl(apiUrl, { 'Referer': 'https://www.2embed.cc/' });
      console.log(`  Status: ${r.status}`);
      const swish = r.body.match(/(?:data-src|src)=["']([^"']*streamsrcs[^"']*)['"]/gi);
      const m3u8 = r.body.match(/["']https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*/gi);
      console.log(`  swish: ${swish || 'NONE'}`);
      console.log(`  m3u8: ${m3u8 ? m3u8.slice(0, 3) : 'NONE'}`);
    } catch (e) {
      console.log(`  Error: ${e.message}`);
    }
  }
}

main().catch(e => console.error('Fatal:', e.message));
