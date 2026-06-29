/**
 * Test all Vidnest providers for KD to find other languages
 */
const https = require('https');

const decryptAlphabet = 'RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=';

function decryptVidnest(data) {
  const lookup = {};
  for (let i = 0; i < decryptAlphabet.length; i++) {
    lookup[decryptAlphabet[i]] = i;
  }
  
  let result = [];
  for (let t = 0; t < data.length; t += 4) {
    let chunk = data.substring(t, t + 4);
    while (chunk.length < 4) { chunk += '='; }
    
    let indices = [];
    for (let e = 0; e < 4; e++) {
      indices.push(lookup[chunk[e]] !== undefined ? lookup[chunk[e]] : 64);
    }
    
    result.push((indices[0] << 2) | (indices[1] >> 4));
    if (indices[2] !== 64) {
      result.push(((indices[1] & 15) << 4) | (indices[2] >> 2));
    }
    if (indices[3] !== 64) {
      result.push(((indices[2] & 3) << 6) | indices[3]);
    }
  }
  
  return Buffer.from(result).toString('utf8');
}

const providers = [
  '/moviesapi/movie',
  '/movies5f/movie',
  '/moviebox/movie'
];

function testAll() {
  providers.forEach((path) => {
    https.get(`https://new.vidnest.fun${path}/1103473`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://vidnest.fun/',
        'Origin': 'https://vidnest.fun'
      }
    }, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => {
        try {
          if (res.statusCode === 200) {
            const json = JSON.parse(body);
            let decrypted = json;
            if (json.encrypted && typeof json.data === 'string') {
              decrypted = JSON.parse(decryptVidnest(json.data));
            }
            console.log(`--- ${path} Response ---`);
            console.log(JSON.stringify(decrypted, null, 2));
          } else {
            console.log(`--- ${path} Status: ${res.statusCode} ---`);
          }
        } catch (e) {
          console.log(`--- ${path} Parse Error: ${e.message} ---`);
        }
      });
    }).on('error', e => console.log(`--- ${path} Error: ${e.message} ---`));
  });
}

testAll();
