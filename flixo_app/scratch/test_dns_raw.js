/**
 * Query DoH for raw JSON response to check NXDOMAIN vs other errors
 */
const https = require('https');

function resolveDnsRaw(hostname) {
  return new Promise((resolve, reject) => {
    const url = `https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(hostname)}&type=ANY`;
    https.get(url, { headers: { 'Accept': 'application/dns-json' } }, (res) => {
      let b = '';
      res.on('data', d => b += d);
      res.on('end', () => resolve(b));
    }).on('error', reject);
  });
}

async function main() {
  const host = 'absole-catenaliggette-i-282.site';
  const r = await resolveDnsRaw(host);
  console.log('Raw DNS JSON:', r);
}

main().catch(console.error);
