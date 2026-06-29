/**
 * Standalone Node.js test for 2embed resolver logic.
 * Run: node scratch/test_two_embed.js
 * This mirrors exactly what the Dart TwoEmbedService does.
 */
const https = require('https');
const { URL } = require('url');

const IMDB_ID = 'tt39139925'; // Dhurandhar - test movie

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

function fetchText(url, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const opts = {
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
        ...extraHeaders,
      },
      rejectUnauthorized: false,
      family: 4,
    };

    const req = https.request(opts, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => {
        console.log(`  [HTTP ${res.statusCode}] ${url.substring(0, 80)}...`);
        resolve(body);
      });
    });
    req.on('error', reject);
    req.setTimeout(15000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

async function main() {
  console.log('=== TwoEmbed Resolver Test ===');
  console.log(`Testing IMDb ID: ${IMDB_ID}\n`);

  // Step 1: Fetch 2embed page
  console.log('Step 1: Fetching 2embed embed page...');
  const embedBody = await fetchText(`https://www.2embed.cc/embed/${IMDB_ID}`);
  
  const swishMatch = embedBody.match(/(?:data-src|src)=["'](https:\/\/streamsrcs\.2embed\.cc\/swish\?id=([^&"']+)[^"']*)['"]/i);
  if (!swishMatch) {
    console.log('❌ FAILED: Could not find swish stream ID in 2embed page');
    console.log('Page preview:', embedBody.substring(0, 500));
    return;
  }
  const streamId = swishMatch[2];
  console.log(`✅ Found streamId: ${streamId}\n`);

  // Step 2: Fetch LookMovie player page
  console.log('Step 2: Fetching LookMovie player page...');
  const lookBody = await fetchText(`https://lookmovie2.skin/e/${streamId}`, {
    'Referer': 'https://streamsrcs.2embed.cc/',
  });

  const evalMatch = lookBody.match(/eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)/);
  if (!evalMatch) {
    console.log('❌ FAILED: Dean Edwards packed script not found');
    console.log('Page preview:', lookBody.substring(0, 500));
    return;
  }
  console.log('✅ Found packed JS script\n');

  // Step 3: Unpack
  console.log('Step 3: Unpacking JS...');
  const code = evalMatch[0].trim().substring(5, evalMatch[0].trim().length - 1);
  let unpacked;
  try {
    const fn = new Function('return (' + code + ');');
    unpacked = fn();
    console.log('✅ Unpacked successfully\n');
  } catch (e) {
    console.log('❌ FAILED to execute unpacker:', e.message);
    return;
  }

  // Step 4: Extract stream URL
  console.log('Step 4: Extracting stream URL...');
  const hls4 = unpacked.match(/"hls4"\s*:\s*"([^"]+)"/);
  if (hls4) {
    const url = `https://lookmovie2.skin${hls4[1]}`;
    console.log('✅ SUCCESS! HLS4 (TikTok) stream found:');
    console.log('   ', url);
    return;
  }

  const hls2 = unpacked.match(/"hls2"\s*:\s*"([^"]+)"/);
  if (hls2) {
    console.log('✅ SUCCESS! HLS2 (premilkyway) stream found:');
    console.log('   ', hls2[1]);
    return;
  }

  const m3u8 = unpacked.match(/https?:\/\/[^\s"]+\.m3u8[^\s"]*/i);
  if (m3u8) {
    console.log('✅ SUCCESS! m3u8 fallback found:');
    console.log('   ', m3u8[0]);
    return;
  }

  console.log('❌ FAILED: No stream URL found in unpacked script');
  console.log('Unpacked preview:', unpacked.substring(0, 500));
}

main().catch(err => {
  console.error('❌ Fatal error:', err.message);
  process.exit(1);
});
