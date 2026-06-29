/**
 * Test manual redirect for segment 0 and segment 1
 */
const https = require('https');

const referer = 'https://gemma416okl.com';

function getSegment(segmentUrl) {
  return new Promise((resolve) => {
    console.log('\nGET', segmentUrl);
    const parsed = new URL(segmentUrl);
    
    const req = https.request({
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': referer,
        'Origin': 'https://gemma416okl.com'
      },
      rejectUnauthorized: false
    }, (res) => {
      console.log('Status:', res.statusCode);
      console.log('Location:', res.headers.location);
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        // Follow manually
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
            'Origin': 'https://gemma416okl.com'
          },
          rejectUnauthorized: false
        }, (redirRes) => {
          console.log('Redirect Status:', redirRes.statusCode);
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
  // Segment 0
  await getSegment('https://i-arch-400.korso420dim.com/vod/4808faf24c599302c84085c5ce837412/480/segment0.ts');
  // Segment 1
  await getSegment('https://i-arch-400.korso420dim.com/vod/4808faf24c599302c84085c5ce837412/480/segment1.ts');
}

main();
