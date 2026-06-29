const http = require('http');
const https = require('https');
const { URL } = require('url');

function directFetch(targetUrl) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(targetUrl);
    const client = parsed.protocol === 'https:' ? https : http;
    const reqOptions = {
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'Accept': '*/*',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      },
      rejectUnauthorized: false,
    };

    const req = client.request(reqOptions, (res) => {
      let chunks = [];
      res.on('data', d => chunks.push(d));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    });
    
    req.on('error', reject);
    req.end();
  });
}

async function run() {
  try {
    const segmentUrl = 'https://p16-ad-site-sign-sg.tiktokcdn.com/ad-site-i18n-sg/202606125d0d3dd8367a19b34ef085d3~tplv-d5opwmad15-ttam-origin.image?lk3s=6d71dd51&x-expires=1812803364&x-signature=0B4U6EhCUGeFlXUR%2FNs8bXnnFp0%3D';
    console.log('Downloading full segment...');
    const bytes = await directFetch(`https://ver-orcin-alpha.vercel.app/api?url=${encodeURIComponent(segmentUrl)}`);
    console.log('Total bytes:', bytes.length);
    
    // Search for "ftyp" (MP4)
    const ftypIndex = bytes.indexOf(Buffer.from([0x66, 0x74, 0x79, 0x70]));
    console.log('ftyp box index:', ftypIndex);
    
    // Search for "moof" (Fragmented MP4)
    const moofIndex = bytes.indexOf(Buffer.from([0x6d, 0x6f, 0x6f, 0x66]));
    console.log('moof box index:', moofIndex);
    
    // Search for "mdat"
    const mdatIndex = bytes.indexOf(Buffer.from([0x6d, 0x64, 0x61, 0x74]));
    console.log('mdat box index:', mdatIndex);
    
    // Search for PNG end or something
    const iendIndex = bytes.indexOf(Buffer.from([0x49, 0x45, 0x4e, 0x44]));
    console.log('IEND chunk index:', iendIndex);
    if (iendIndex !== -1) {
      console.log('Bytes immediately after IEND:', bytes.slice(iendIndex + 8, iendIndex + 40).toString('hex'));
      console.log('Bytes immediately after IEND (ASCII):', bytes.slice(iendIndex + 8, iendIndex + 40).toString());
    }
  } catch (e) {
    console.error('Error:', e);
  }
}

run();
