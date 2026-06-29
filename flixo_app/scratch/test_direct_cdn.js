/**
 * Test direct CDN request
 */
const https = require('https');

const targetUrl = 'https://i-arch-400.korso420dim.com/stream2/i-arch-400/5adf060065d9f0bc0939f6ba7ab1013f/MJTMsp1RshGTygnMNRUR2N2MSlnWXZEdMNDZzQWe5MDZzMmdZJTO1R2RWVHZDljekhkSsl1VwYnWtx2cihVT25ERnd3THpFaapWSwkleVVzTU10dN1WT04ERBRjTX1UMZJTV00kejBTTUlUP:1782712359:64.118.148.102:903b92a3c60005f46301971c9bd7500f73407a78bafb72fcf851b3eb776054cb:=4kaRVXTUVENMpWRw80Q0gXTElUP/index.m3u8';
const referer = 'https://gemma416okl.com';

function testDirect() {
  console.log('GET', targetUrl);
  const parsed = new URL(targetUrl);
  
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
    let body = '';
    res.on('data', d => body += d);
    res.on('end', () => {
      console.log('Body length:', body.length);
      console.log('Body preview:', body.substring(0, 500));
    });
  }).on('error', e => console.error('Error:', e.message));
  
  req.end();
}

testDirect();
