/**
 * Resolve streams for movie "29" (TMDB: 1510769)
 */
const https = require('https');

// Custom base64 alphabet
const decryptAlphabet = 'RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=';

function decryptVidnest(data) {
  const lookup = {};
  for (let i = 0; i < decryptAlphabet.length; i++) {
    lookup[decryptAlphabet[i]] = i;
  }
  const base64 = data.replace(/[^A-Za-z0-9+/=]/g, '');
  let bytes = [];
  for (let i = 0; i < base64.length; i += 4) {
    const enc1 = lookup[base64[i] || '='] || 0;
    const enc2 = lookup[base64[i + 1] || '='] || 0;
    const enc3 = lookup[base64[i + 2] || '='] || 0;
    const enc4 = lookup[base64[i + 3] || '='] || 0;
    const chr1 = (enc1 << 2) | (enc2 >> 4);
    const chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
    const chr3 = ((enc3 & 3) << 6) | enc4;
    bytes.push(chr1);
    if (enc3 !== 64 && base64[i + 2] !== '=') bytes.push(chr2);
    if (enc4 !== 64 && base64[i + 3] !== '=') bytes.push(chr3);
  }
  return Buffer.from(bytes).toString('utf-8');
}

function fetchUrl(url) {
  return new Promise((resolve) => {
    https.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json, */*',
        'Origin': 'https://vidnest.fun',
        'Referer': 'https://vidnest.fun/'
      }
    }, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve({ status: res.statusCode, body }));
    }).on('error', (e) => resolve({ status: 500, body: e.message }));
  });
}

async function test() {
  const tmdbId = '1510769';
  console.log(`Resolving streams for 29 (TMDB: ${tmdbId})...`);
  
  const providers = [
    '/moviesapi/movie',
    '/allmovies/movie',
    '/moviebox/movie',
    '/movies5f/movie'
  ];

  for (const p of providers) {
    const url = 'https://new.vidnest.fun' + p + '/' + tmdbId;
    console.log(`Querying ${url}...`);
    const res = await fetchUrl(url);
    console.log(`Status: ${res.status}`);
    if (res.status === 200) {
      try {
        const json = JSON.parse(res.body);
        let data = json;
        if (json.encrypted === true && typeof json.data === 'string') {
          const decrypted = decryptVidnest(json.data);
          data = JSON.parse(decrypted);
        }
        console.log(`Decrypted data for ${p}:`, JSON.stringify(data, null, 2).substring(0, 1000));
      } catch (e) {
        console.log(`Error parsing: ${e.message}`);
      }
    }
  }
}

test();
