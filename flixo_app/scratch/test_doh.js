/**
 * Test DNS resolution using Cloudflare DoH
 */
const https = require('https');

function resolveDns(hostname) {
  return new Promise((resolve, reject) => {
    const url = `https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(hostname)}&type=A`;
    https.get(url, { headers: { 'Accept': 'application/dns-json' } }, (res) => {
      let b = '';
      res.on('data', d => b += d);
      res.on('end', () => {
        try {
          const json = JSON.parse(b);
          console.log('DNS Answer:', json.Answer);
          if (json.Answer && json.Answer.length > 0) {
            resolve(json.Answer.find(a => a.type === 1).data);
          } else {
            resolve(null);
          }
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

async function main() {
  const host = 'i-arch-400.absole-catenaliggette-i-282.site';
  console.log('Resolving host:', host);
  try {
    const ip = await resolveDns(host);
    console.log('Resolved IP:', ip);
  } catch (e) {
    console.error('Failed to resolve:', e.message);
  }
}

main();
