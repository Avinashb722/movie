/**
 * Debug 2embed page structure for any IMDb ID
 */
const https = require('https');

const IMDB_ID = process.argv[2] || 'tt7838252'; // KGF

function fetch(url, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const opts = {
      hostname: parsed.hostname,
      port: 443,
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
    const req = https.request(opts, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', reject);
    req.setTimeout(15000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

async function main() {
  console.log(`=== Debugging 2embed for IMDb: ${IMDB_ID} ===\n`);

  const r = await fetch(`https://www.2embed.cc/embed/${IMDB_ID}`);
  console.log(`HTTP Status: ${r.status}`);
  console.log(`Body length: ${r.body.length} chars\n`);

  // Check for swish pattern
  const swish = r.body.match(/(?:data-src|src)=["']([^"']*streamsrcs[^"']*)['"]/gi);
  console.log('Swish/streamsrcs matches:', swish || 'NONE');

  // Check for lookmovie patterns
  const look = r.body.match(/lookmovie[^"'\s]*/gi);
  console.log('LookMovie refs:', look ? [...new Set(look)].slice(0, 10) : 'NONE');

  // Check all iframe srcs
  const iframes = [...r.body.matchAll(/iframe[^>]*src=["']([^"']+)['"]/gi)].map(m => m[1]);
  console.log('Iframes:', iframes.length ? iframes.slice(0, 10) : 'NONE');

  // Check embed/player script sources
  const dataSrcs = [...r.body.matchAll(/data-src=["']([^"']+)['"]/gi)].map(m => m[1]);
  console.log('data-src attrs:', dataSrcs.length ? dataSrcs.slice(0, 10) : 'NONE');

  // Check for any m3u8 or stream references
  const streams = r.body.match(/https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*/gi);
  console.log('Direct m3u8 refs:', streams || 'NONE');

  // Print first 2000 chars of page for manual inspection
  console.log('\n--- Page HTML (first 2000 chars) ---');
  console.log(r.body.substring(0, 2000));
}

main().catch(e => console.error('Error:', e.message));
