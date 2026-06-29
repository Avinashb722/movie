const https = require('https');

function fetchUrl(url, referer) {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      }
    };
    if (referer) {
      options.headers['Referer'] = referer;
    }
    https.get(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    }).on('error', reject);
  });
}

async function run() {
  try {
    const res = await fetchUrl('https://vidsrc.me/embed/tt10903332');
    console.log('Status:', res.status);
    console.log('Body length:', res.body.length);
    console.log('Sample body:', res.body.substring(0, 1000));
    
    // Look for iframe or player scripts
    const matches = res.body.match(/<iframe[^>]*src="([^"]+)"/gi);
    console.log('Iframe matches:', matches);
  } catch (e) {
    console.error('Error:', e);
  }
}

run();
