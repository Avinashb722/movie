/**
 * Parse the playlist and test segment 0 and segment 1 with exact signatures
 */
const https = require('https');

const referer = 'https://gemma416okl.com';

function requestUrl(url) {
  return new Promise((resolve) => {
    const parsed = new URL(url);
    const req = https.request({
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': referer,
        'Origin': 'https://gemma416okl.com',
        'Range': 'bytes=0-'
      },
      rejectUnauthorized: false
    }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        const redirectUrl = res.headers.location;
        console.log('Redirecting to:', redirectUrl);
        
        const redirParsed = new URL(redirectUrl);
        const redirReq = https.request({
          hostname: redirParsed.hostname,
          port: 443,
          path: redirParsed.pathname + redirParsed.search,
          method: 'GET',
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Referer': referer,
            'Origin': 'https://gemma416okl.com',
            'Range': 'bytes=0-'
          },
          rejectUnauthorized: false
        }, (redirRes) => {
          resolve(redirRes.statusCode);
        });
        redirReq.end();
      } else {
        resolve(res.statusCode);
      }
    });
    req.end();
  });
}

async function main() {
  // Let's test segment 0 with the exact md5 signature from player log:
  const seg0 = 'https://i-arch-400.korso420dim.com/vod/4808faf24c599302c84085c5ce837412/480/segment0.ts?md5=qdxRfLbzel-DYPG1fNwXXg&expires=1782720840';
  console.log('Testing Segment 0...');
  const s0 = await requestUrl(seg0);
  console.log('Segment 0 final status:', s0);

  // Let's test segment 1 with the exact md5 signature from player log:
  const seg1 = 'https://i-arch-400.korso420dim.com/vod/4808faf24c599302c84085c5ce837412/480/segment1.ts?md5=k0L3YBAJPvjjq5yjaIOxWQ&expires=1782720840';
  console.log('\nTesting Segment 1...');
  const s1 = await requestUrl(seg1);
  console.log('Segment 1 final status:', s1);
}

main();
