const https = require('https');

const tiktokUrl = 'https://p19-ad-site-sign-sg.tiktokcdn.com/ad-site-i18n-sg/202605145d0db12439e56bae46bbb5ee~tplv-d5opwmad15-ttam-origin.image?lk3s=6d71dd51&x-expires=1810324624&x-signature=GppA0bSZYAxE53qgNB73fgbhUBI%3D';

function testProxy(name, proxyUrl, headers = {}) {
  return new Promise((resolve) => {
    console.log(`\nTesting proxy: ${name}`);
    const finalUrl = proxyUrl.replace('{url}', encodeURIComponent(tiktokUrl));
    
    https.get(finalUrl, { headers }, (res) => {
      console.log(`  Status Code: ${res.statusCode}`);
      console.log(`  Content-Length: ${res.headers['content-length']}`);
      resolve(res.statusCode);
    }).on('error', (e) => {
      console.log(`  Error: ${e.message}`);
      resolve(500);
    });
  });
}

async function run() {
  await testProxy('Vercel Proxy with Range', 'https://ver-orcin-alpha.vercel.app/api?url={url}', {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Range': 'bytes=0-',
    'Accept-Encoding': 'identity'
  });
}

run();
