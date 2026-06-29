const https = require('https');

const tiktokUrl = 'https://p19-ad-site-sign-sg.tiktokcdn.com/ad-site-i18n-sg/202605145d0dcefb51083bd341318647~tplv-d5opwmad15-ttam-origin.image?lk3s=6d71dd51&x-expires=1810324624&x-signature=72VG3SDcxLBag8B5MdcGYjGzBCQ%3D';

const proxies = [
  { name: 'AllOrigins', url: 'https://api.allorigins.win/raw?url={url}' },
  { name: 'ThingProxy', url: 'https://thingproxy.freeboard.io/fetch/{url}' },
  { name: 'Codetabs', url: 'https://api.codetabs.com/v1/proxy?quest={url}' },
];

function testProxy(proxy) {
  return new Promise((resolve) => {
    console.log(`\nTesting proxy: ${proxy.name}`);
    const finalUrl = proxy.url.replace('{url}', encodeURIComponent(tiktokUrl));
    console.log(`URL: ${finalUrl}`);
    
    https.get(finalUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Range': 'bytes=0-',
        'Accept-Encoding': 'identity'
      }
    }, (res) => {
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
  for (const proxy of proxies) {
    await testProxy(proxy);
  }
}

run();
