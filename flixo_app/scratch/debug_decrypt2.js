/**
 * Find and extract the decryptCipherResponse implementation from chunk 50586
 */
const https = require('https');

function fetchUrl(url, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const opts = {
      hostname: parsed.hostname, port: 443,
      path: parsed.pathname + parsed.search,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://vidnest.fun/',
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

async function main() {
  // e.i(50586) contains decryptCipherResponse
  // Need to find which chunk file contains module 50586
  // Let's check the big chunks
  const chunks = [
    '/_next/static/chunks/31dd2cd50f2a288b.js',
    '/_next/static/chunks/6c30b25e2bb0f61b.js',
    '/_next/static/chunks/a6dad97d9634a72d.js',
  ];

  for (const chunkPath of chunks) {
    const url = `https://vidnest.fun${chunkPath}`;
    process.stdout.write(`Scanning ${chunkPath}... `);
    const r = await fetchUrl(url);
    console.log(`${r.body.length} chars`);

    if (r.body.includes('decryptCipherResponse') || r.body.includes('50586')) {
      console.log('  ✅ Contains decrypt code!');
      
      // Find decryptCipherResponse implementation
      const idx = r.body.indexOf('decryptCipherResponse');
      if (idx >= 0) {
        console.log('\n  Full function (2000 chars):');
        console.log(r.body.substring(Math.max(0, idx - 200), idx + 2000));
      }
      
      // Look for AES key/iv constants
      const cryptoKey = r.body.match(/(?:key|Key|KEY|secret|SECRET)\s*[:=]\s*["'`]([^"'`]{8,})["'`]/g);
      if (cryptoKey) console.log('\n  Crypto keys:', cryptoKey.slice(0, 5));
      
      // Look for CryptoJS or WebCrypto references
      if (r.body.includes('CryptoJS')) console.log('  Uses CryptoJS!');
      if (r.body.includes('crypto.subtle')) console.log('  Uses WebCrypto!');
      if (r.body.includes('atob')) console.log('  Uses atob!');
    }
  }
  
  // Also scan module 50586 specifically - it's referenced as e.i(50586)
  // Search all chunks for the module ID
  const allChunks = [
    '/_next/static/chunks/00cb8966bcf22375.js',
    '/_next/static/chunks/d4cf4caae891f664.js',
    '/_next/static/chunks/69be39811437728d.js',
    '/_next/static/chunks/4fa3ead9609cf2d6.js',
    '/_next/static/chunks/66b231c2403f619d.js',
  ];
  
  for (const chunkPath of allChunks) {
    const url = `https://vidnest.fun${chunkPath}`;
    process.stdout.write(`Scanning ${chunkPath} for decrypt... `);
    const r = await fetchUrl(url);
    if (r.body.includes('decryptCipher') || r.body.includes('50586')) {
      console.log('✅ Found!');
      const idx = r.body.indexOf('decryptCipher');
      if (idx >= 0) console.log(r.body.substring(Math.max(0, idx - 100), idx + 1500));
    } else {
      console.log(`not found (${r.body.length} chars)`);
    }
  }
}

main().catch(e => console.error('Fatal:', e.message));
