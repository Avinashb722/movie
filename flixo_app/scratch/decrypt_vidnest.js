/**
 * Decrypt vidnest stream data and get the actual m3u8 URL for KGF
 * 
 * The decryption is a custom base64 substitution where:
 * - The alphabet is: "RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/="
 * - Data is processed 4 chars at a time, decoded to UTF-8 bytes
 */
const https = require('https');

// Custom alphabet from vidnest source
const CUSTOM_ALPHABET = 'RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=';

function decryptVidnest(data) {
  // Build lookup table: char -> index in alphabet
  const lookup = {};
  for (let i = 0; i < CUSTOM_ALPHABET.length; i++) {
    lookup[CUSTOM_ALPHABET[i]] = i;
  }

  const result = [];
  for (let t = 0; t < data.length; t += 4) {
    let chunk = data.substring(t, t + 4);
    // Pad to 4 chars with '='
    while (chunk.length < 4) chunk += '=';

    const indices = [];
    for (let e = 0; e < 4; e++) {
      const idx = lookup[chunk[e]];
      indices.push(idx !== undefined ? idx : 64);
    }

    // Decode: 3 bytes from 4 6-bit indices
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

function fetchUrl(url, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const opts = {
      hostname: parsed.hostname, port: 443,
      path: parsed.pathname + parsed.search,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json, */*',
        'Origin': 'https://vidnest.fun', 'Referer': 'https://vidnest.fun/',
        ...extraHeaders,
      },
      rejectUnauthorized: false, family: 4,
    };
    const req = https.request(opts, (res) => {
      const c = [];
      res.on('data', d => c.push(d));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(c).toString('utf8') }));
    });
    req.on('error', reject);
    req.setTimeout(20000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

const TMDB_ID = process.argv[2] || '564147'; // KGF

const ENDPOINTS = [
  `https://new.vidnest.fun/moviebox/movie/${TMDB_ID}`,
  `https://new.vidnest.fun/moviesapi/movie/${TMDB_ID}`,
  `https://new.vidnest.fun/allmovies/movie/${TMDB_ID}`,
  `https://new.vidnest.fun/movies5f/movie/${TMDB_ID}`,
  `https://new.vidnest.fun/klikxxi/movie/${TMDB_ID}`,
];

async function main() {
  console.log(`=== Decrypting stream data for TMDB: ${TMDB_ID} ===\n`);

  for (const url of ENDPOINTS) {
    const name = url.split('/')[4];
    process.stdout.write(`${name}/${TMDB_ID}... `);
    
    try {
      const r = await fetchUrl(url);
      console.log(`HTTP ${r.status}`);

      if (r.status !== 200) continue;

      const parsed = JSON.parse(r.body);
      if (!parsed.encrypted || !parsed.data) {
        console.log(`  Not encrypted, raw:`, parsed);
        continue;
      }

      const decrypted = decryptVidnest(parsed.data);
      console.log(`  Decrypted (first 500 chars): ${decrypted.substring(0, 500)}`);

      // Try to parse as JSON
      try {
        const streamData = JSON.parse(decrypted);
        console.log('\n  ✅ Parsed stream data!');
        console.log('  Keys:', Object.keys(streamData));
        
        // Look for URL/m3u8
        const str = JSON.stringify(streamData);
        const m3u8 = str.match(/https?:\/\/[^\s"'\\]+\.m3u8[^\s"'\\]*/gi);
        const mp4 = str.match(/https?:\/\/[^\s"'\\]+\.mp4[^\s"'\\]*/gi);
        const link = str.match(/"(?:link|url|src|file)"\s*:\s*"([^"]+)"/gi);
        
        if (m3u8) console.log('  m3u8 URLs:', m3u8);
        if (mp4) console.log('  mp4 URLs:', mp4.slice(0, 3));
        if (link) console.log('  link/url fields:', link.slice(0, 5));
      } catch (e) {
        console.log('  Not valid JSON after decryption');
      }
    } catch (e) {
      console.log(`  Error: ${e.message}`);
    }
    console.log('');
  }
}

main().catch(e => console.error('Fatal:', e.message));
