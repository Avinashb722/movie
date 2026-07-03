const fs = require('fs');
const path = require('path');
const https = require('https');

// Path to sitemap.xml
const sitemapPath = path.join(__dirname, '..', 'public', 'sitemap.xml');

if (!fs.existsSync(sitemapPath)) {
  console.error(`Sitemap not found at: ${sitemapPath}`);
  process.exit(1);
}

// Read sitemap.xml content
const content = fs.readFileSync(sitemapPath, 'utf8');

// Simple regex to extract <loc>...</loc> URLs
const locRegex = /<loc>(.*?)<\/loc>/g;
const urls = [];
let match;
while ((match = locRegex.exec(content)) !== null) {
  urls.push(match[1].trim());
}

if (urls.length === 0) {
  console.error('No URLs found in sitemap.xml!');
  process.exit(1);
}

console.log(`Found ${urls.length} URLs in sitemap.xml.`);

// Payload for IndexNow API
const payload = {
  host: 'www.movienest.app',
  key: '19341107b65447b4b396b7f56ea0b02b',
  keyLocation: 'https://www.movienest.app/19341107b65447b4b396b7f56ea0b02b.txt',
  urlList: urls
};

const payloadString = JSON.stringify(payload, null, 2);

console.log('Sending submission payload to IndexNow (api.indexnow.org)...');

const options = {
  hostname: 'api.indexnow.org',
  port: 443,
  path: '/indexnow',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(payloadString)
  }
};

const req = https.request(options, (res) => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => {
    console.log(`Response Status Code: ${res.statusCode}`);
    if (res.statusCode === 200 || res.statusCode === 202) {
      console.log('✅ URLs submitted successfully to IndexNow!');
    } else {
      console.error(`❌ Submission failed: ${res.statusCode} - ${body || res.statusMessage}`);
    }
  });
});

req.on('error', (e) => {
  console.error(`Request error: ${e.message}`);
});

req.write(payloadString);
req.end();
