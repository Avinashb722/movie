/**
 * Test if the redirected CDN segment supports plain HTTP (port 80)
 */
const http = require('http');

const referer = 'https://gemma416okl.com';
const segUrlHttp = 'http://cdn30091.korso420dim.com/vod/55caabe75ba4b02b91fcb37134cba7f6/1080/segment401.ts?md5=NSS7ABiXxix3xT26BVbiag&expires=1782722110';

function testHttp() {
  console.log('Requesting via HTTP (port 80)...');
  const parsed = new URL(segUrlHttp);
  const req = http.request({
    hostname: parsed.hostname,
    port: 80,
    path: parsed.pathname + parsed.search,
    method: 'GET',
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Referer': referer,
      'Origin': 'https://gemma416okl.com',
      'Range': 'bytes=0-'
    }
  }, (res) => {
    console.log('HTTP Response Status:', res.statusCode);
    console.log('Headers:', res.headers);
  });
  
  req.on('error', (e) => {
    console.error('HTTP Error:', e.message);
  });
  
  req.end();
}

testHttp();
