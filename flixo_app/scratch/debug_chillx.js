/**
 * Investigate chillx.top embed/stream page
 */
const https = require('https');

function fetch(url) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const req = https.request({
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://vidnest.fun/'
      },
      rejectUnauthorized: false
    }, (res) => {
      let b = '';
      res.on('data', d => b += d);
      res.on('end', () => resolve({ status: res.statusCode, body: b }));
    });
    req.on('error', reject);
    req.end();
  });
}

async function main() {
  const r = await fetch('https://chillx.top/v/bEjqah3nxeL5/');
  console.log('Status:', r.status);
  console.log('Body length:', r.body.length);
  
  // Look for any packed JS or m3u8 stream links
  const m3u8 = r.body.match(/https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*/gi);
  console.log('m3u8 URLs found:', m3u8);
  
  // Look for sources array or file config
  const file = r.body.match(/file\s*:\s*["']([^"']+)["']/gi);
  console.log('Files:', file);
  
  const sources = r.body.match(/sources\s*:\s*\[[\s\S]+?\]/g);
  console.log('Sources block:', sources ? sources[0].substring(0, 500) : 'NONE');

  // Let's print the head/scripts of the page
  console.log('\nPage head/scripts:');
  const scripts = r.body.match(/<script[\s\S]*?<\/script>/gi);
  if (scripts) {
    scripts.forEach((s, i) => console.log(`Script ${i}:`, s.substring(0, 300)));
  }
}

main().catch(console.error);
