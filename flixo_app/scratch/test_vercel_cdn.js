/**
 * Test fetching the redirected cdn30091 segment through Singapore Vercel Proxy
 */
const https = require('https');

const referer = 'https://gemma416okl.com';
const segUrl = 'https://cdn30091.korso420dim.com/vod/55caabe75ba4b02b91fcb37134cba7f6/1080/segment401.ts?md5=NSS7ABiXxix3xT26BVbiag&expires=1782722110';
const proxyUrl = `https://ver-orcin-alpha.vercel.app/api?url=${encodeURIComponent(segUrl)}&referer=${encodeURIComponent(referer)}`;

function testProxy() {
  console.log('Requesting through Vercel Proxy...');
  console.log('GET', proxyUrl);
  
  const parsed = new URL(proxyUrl);
  const req = https.request({
    hostname: parsed.hostname,
    port: 443,
    path: parsed.pathname + parsed.search,
    method: 'GET',
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    }
  }, (res) => {
    console.log('Proxy Response Status:', res.statusCode);
    console.log('Headers:', res.headers);
    res.on('data', () => {}); // Consume body
  }).on('error', e => console.error('Error:', e.message));
  
  req.end();
}

testProxy();
