const https = require('https');

const targetUrl = 'https://archive.org/download/x-2015145075513163968/2014788123478163456.mp4';
const proxyUrl = `https://corsproxy.io/?${encodeURIComponent(targetUrl)}`;

console.log('Testing corsproxy.io with Archive.org URL:', proxyUrl);

const reqOptions = {
  headers: {
    'Range': 'bytes=0-100'
  }
};

https.get(proxyUrl, reqOptions, (res) => {
  console.log('Status Code:', res.statusCode);
  console.log('Headers:', res.headers);
  
  let chunkCount = 0;
  res.on('data', (chunk) => {
    chunkCount++;
    if (chunkCount === 1) {
      console.log('Received first chunk of size:', chunk.length);
    }
  });
  
  res.on('end', () => {
    console.log('Stream ended successfully.');
  });
}).on('error', (e) => {
  console.error('Error:', e.message);
});
