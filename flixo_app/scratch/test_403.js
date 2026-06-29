/**
 * Test different User-Agents and HTTP vs HTTPS on the resolved stream URL
 */
const https = require('https');
const http = require('http');

const streamUrl = 'https://185.237.107.141/v4/n8JFKuv7fdLkmhWlCXtGDg/1782730228/9ow/8ajfnf/master.m3u8?v=1774677029';

function requestUrl(urlStr, headers) {
  return new Promise((resolve) => {
    const mod = urlStr.startsWith('https') ? https : http;
    const req = mod.get(urlStr, {
      headers: {
        'Referer': 'https://vidnest.fun/',
        'Origin': 'https://vidnest.fun',
        ...headers
      },
      rejectUnauthorized: false,
      timeout: 8000
    }, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: body.substring(0, 300) }));
    });
    req.on('error', (e) => resolve({ status: 500, body: e.message }));
  });
}

async function main() {
  const tests = [
    { name: 'HTTPS with standard Windows Chrome UA', url: streamUrl, headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' } },
    { name: 'HTTPS with Android ExoPlayer UA', url: streamUrl, headers: { 'User-Agent': 'ExoPlayerLib/2.18.2' } },
    { name: 'HTTPS with Mobile Safari UA', url: streamUrl, headers: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1' } },
    { name: 'HTTPS with stagefright/MXPlayer UA', url: streamUrl, headers: { 'User-Agent': 'stagefright/1.2 (Linux;Android 11)' } },
    { name: 'HTTP with standard Windows Chrome UA', url: streamUrl.replace('https:', 'http:'), headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' } },
    { name: 'HTTP with Android ExoPlayer UA', url: streamUrl.replace('https:', 'http:'), headers: { 'User-Agent': 'ExoPlayerLib/2.18.2' } },
  ];

  for (const t of tests) {
    console.log(`\nTesting: ${t.name}...`);
    const res = await requestUrl(t.url, t.headers);
    console.log(`Status: ${res.status}`);
    if (res.status === 200) {
      console.log('✅ SUCCESS!');
      console.log('Body preview:', res.body.substring(0, 200));
      break;
    } else {
      console.log('Body:', res.body.substring(0, 150));
    }
  }
}

main();
