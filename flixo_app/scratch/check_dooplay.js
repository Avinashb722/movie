/**
 * Deep dive into Vidlink.pro API - it returned actual vidsrc.xyz URLs!
 * vidsrc.xyz supports multi-language streams for Indian movies
 */
const https = require('https');

function fetch(url, options = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, {
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'application/json, */*',
        'Referer': options.referer || 'https://vidlink.pro/',
        ...options.headers
      },
      timeout: 12000
    }, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    req.end();
  });
}

async function main() {
  // KGF2: TMDB=507086, IMDB=tt8080598
  // KD: TMDB=1103473, IMDB=tt15295368

  console.log('=== Vidlink.pro API Deep Dive ===\n');
  
  // Get the full Vidlink page (Next.js)
  const r = await fetch('https://vidlink.pro/movie/507086', { referer: 'https://vidlink.pro/' });
  console.log('Status:', r.status);
  
  // Check __NEXT_DATA__
  const nextData = r.body.match(/__NEXT_DATA__"[^>]*>([\s\S]+?)<\/script>/);
  if (nextData) {
    const data = JSON.parse(nextData[1]);
    console.log('pageProps:', JSON.stringify(data.props?.pageProps, null, 2));
  }
  
  // Check Vidlink API endpoints
  const vidlinkApis = [
    `https://vidlink.pro/api/b/movie/507086`,
    `https://vidlink.pro/api/movie/507086`,
    `https://vidlink.pro/api/stream/movie/507086`,
    `https://vidlink.pro/api/v1/movie/507086`,
    `https://vidlink.pro/api/movie/tt8080598`,
  ];
  
  for (const url of vidlinkApis) {
    try {
      const resp = await fetch(url, { referer: 'https://vidlink.pro/' });
      console.log(`\n${url.split('/pro/')[1]}: HTTP ${resp.status}`);
      if (resp.status === 200) {
        try {
          const json = JSON.parse(resp.body);
          console.log('✅ JSON:', JSON.stringify(json, null, 2).substring(0, 800));
        } catch {
          const streams = resp.body.match(/https?:[^\s"'\\]+\.(m3u8|mp4)[^\s"'\\]*/gi) || [];
          console.log('Streams:', streams.slice(0, 5));
          console.log('Preview:', resp.body.substring(0, 400));
        }
      }
    } catch(e) { console.log(`Error: ${e.message}`); }
  }
  
  // Now check vidsrc.xyz (what vidlink returned)
  console.log('\n\n=== VidSrc.xyz (from Vidlink response) ===\n');
  const xyzApis = [
    `https://vidsrc.xyz/embed/movie/507086`,
    `https://vidsrc.xyz/embed/movie?imdb=tt8080598`,
    `https://vidsrc.xyz/api/v1/movie/507086`,
    `https://vidsrc.xyz/api/movie/507086`,
  ];
  for (const url of xyzApis) {
    try {
      const resp = await fetch(url, { referer: 'https://vidsrc.xyz/' });
      console.log(`${url.split('/xyz/')[1]}: HTTP ${resp.status}`);
      if (resp.status === 200) {
        const streams = resp.body.match(/https?:[^\s"'\\]+\.(m3u8|mp4)[^\s"'\\]*/gi) || [];
        if (streams.length > 0) {
          console.log('✅ STREAMS FOUND:', streams.slice(0, 5));
        } else {
          // Save for inspection
          require('fs').writeFileSync('scratch/vidsrc_xyz_page.html', resp.body);
          console.log('Saved to vidsrc_xyz_page.html - checking for API calls...');
          const fetch_calls = resp.body.match(/fetch\(['"](https?[^'"]+)['"]/gi) || [];
          console.log('fetch() calls:', fetch_calls.slice(0, 10));
          const apiHints = resp.body.match(/["'](https?:\/\/[^"']+(?:api|source|stream)[^"']*)["']/gi) || [];
          console.log('API hints:', apiHints.slice(0, 10).map(a => a.replace(/["']/g, '')));
        }
      }
    } catch(e) { console.log(`Error: ${e.message}`); }
  }
  
  // Check 2embed.cc stream hints
  console.log('\n\n=== 2Embed.cc Deep Dive ===\n');
  const embed2 = await fetch('https://www.2embed.cc/embed/tt8080598', { referer: 'https://www.2embed.cc/' });
  console.log('Status:', embed2.status);
  require('fs').writeFileSync('scratch/2embed_page.html', embed2.body);
  // Look for script files
  const scripts = [...embed2.body.matchAll(/src=["']([^"']+\.js[^"']*)["']/gi)].map(m => m[1]);
  console.log('Script files:', scripts.filter(s => !s.includes('jquery') && !s.includes('google')));
  // Look for data attributes with IDs
  const dataAttrs = [...embed2.body.matchAll(/data-(?:id|vid|src|tmdb|imdb|key|token)[=]["']([^"']+)["']/gi)].map(m => m[0]);
  console.log('Data attrs:', dataAttrs.slice(0, 15));
  // Look for inline config
  const configs = [...embed2.body.matchAll(/(?:file|source|src|player|stream|embed)\s*[:=]\s*["']([^"']{10,200})["']/gi)].map(m => m[0]);
  console.log('Config values:', configs.slice(0, 10));
}

main().catch(console.error);
