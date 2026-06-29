const https = require('https');
const fs = require('fs');

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
    const referer = 'https://streamsrcs.2embed.cc/';
    const targetUrl = 'https://vidnest.fun/movie/507086?autostart=true';
    const res = await fetchUrl(targetUrl, referer);
    fs.writeFileSync('scratch/vidnest_page.html', res.body);
    console.log('Saved vidnest_page.html. Length:', res.body.length);
  } catch (e) {
    console.error('Error:', e);
  }
}

run();
