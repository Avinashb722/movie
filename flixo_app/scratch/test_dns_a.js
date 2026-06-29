/**
 * Query DoH for A record JSON response
 */
const https = require('https');

function resolveDnsA(hostname) {
  return new Promise((resolve, reject) => {
    const url = `https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(hostname)}&type=A`;
    https.get(url, { headers: { 'Accept': 'application/dns-json' } }, (res) => {
      let b = '';
      res.on('data', d => b += d);
      res.on('end', () => resolve(b));
    }).on('error', reject);
  });
}

async function main() {
  const host = 'i-arch-400.absole-catenaliggette-i-282.site';
  const r = await resolveDnsA(host);
  console.log('Raw DNS JSON:', r);
}

main().catch(console.error);
