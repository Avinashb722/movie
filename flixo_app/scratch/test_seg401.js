/**
 * Test segment 401 with exact signature
 */
const https = require('https');

const referer = 'https://gemma416okl.com';
const seg401 = 'https://i-cdn-0.korso420dim.com/vod/55caabe75ba4b02b91fcb37134cba7f6/1080/segment401.ts?md5=NSS7ABiXxix3xT26BVbiag&expires=1782722110';

function testSegment401() {
  const parsed = new URL(seg401);
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
    console.log('Status:', res.statusCode);
    if (res.headers.location) {
      console.log('Redirecting to:', res.headers.location);
      const redirParsed = new URL(res.headers.location);
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
        console.log('Redirect Status:', redirRes.statusCode);
      });
      redirReq.end();
    }
  });
  req.end();
}

testSegment401();
