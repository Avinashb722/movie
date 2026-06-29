/**
 * Test substituting the fake domain with the real CDN domain
 */
const https = require('https');

const fakeUrl = 'https://i-arch-400.absole-catenaliggette-i-282.site/vod/4808faf24c599302c84085c5ce837412/360/segment49.ts';
const realHost = 'i-arch-400.korso420dim.com';
const referer = 'https://gemma416okl.com';

const testUrl = fakeUrl.replace('i-arch-400.absole-catenaliggette-i-282.site', realHost);

function testSubstitution() {
  console.log('GET', testUrl);
  const parsed = new URL(testUrl);
  
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
    console.log('Headers:', res.headers);
    res.on('data', () => {}); // Consume body
  }).on('error', e => console.error('Error:', e.message));
  
  req.end();
}

testSubstitution();
