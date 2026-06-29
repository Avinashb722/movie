/**
 * Verify what TwoEmbedService returns for KGF 2 and KD
 */
const https = require('https');

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

async function test(tmdbId, name) {
  console.log(`\n=================== ${name} (TMDB: ${tmdbId}) ===================`);
  const providers = [
    '/moviesapi/movie',
    '/allmovies/movie',
    '/moviebox/movie',
    '/movies5f/movie'
  ];

  const allStreams = [];

  for (const p of providers) {
    const url = 'https://new.vidnest.fun' + p + '/' + tmdbId;
    const res = await fetchUrl(url);
    if (res.status === 200) {
      try {
        const json = JSON.parse(res.body);
        let data = json;
        if (json.encrypted === true && typeof json.data === 'string') {
          const decrypted = decryptVidnest(json.data);
          data = JSON.parse(decrypted);
        }
        
        // Format 1: streams
        if (data.streams && Array.isArray(data.streams)) {
          for (const s of data.streams) {
            allStreams.push({
              provider: p,
              lang: s.language || s.lang || 'Unknown',
              url: s.url
            });
          }
        }
        
        // Format 2: url list
        if (data.url && Array.isArray(data.url)) {
          for (const s of data.url) {
            allStreams.push({
              provider: p,
              lang: s.lang || s.language || 'Unknown',
              url: s.link || s.url,
              res: s.resolution || ''
            });
          }
        }
      } catch (e) {
        // Skip
      }
    }
  }

  console.log(`Resolved Streams count: ${allStreams.length}`);
  allStreams.forEach((s, idx) => {
    console.log(`[${idx + 1}] Provider: ${s.provider}, Lang: ${s.lang}${s.res ? ' ('+s.res+')' : ''}, URL: ${s.url.substring(0, 80)}...`);
  });
}

async function main() {
  await test('1103473', 'KD - The Devil');
  await test('507086', 'KGF - Chapter 2');
}

main();
