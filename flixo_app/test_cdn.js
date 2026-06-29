const http = require('http');
const https = require('https');
const { URL } = require('url');

// Helper to make HTTPS requests
function makeRequest(targetUrl, options = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(targetUrl);
    const client = parsed.protocol === 'https:' ? https : http;
    
    const reqOptions = {
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path: parsed.pathname + parsed.search,
      method: options.method || 'GET',
      headers: {
        ...options.headers
      },
      rejectUnauthorized: false,
    };

    const req = client.request(reqOptions, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve({ 
        status: res.statusCode, 
        headers: res.headers, 
        body 
      }));
    });
    
    req.on('error', reject);
    req.setTimeout(5000, () => req.destroy(new Error('timeout')));
    
    if (options.body) req.write(options.body);
    req.end();
  });
}

async function run() {
  try {
    console.log('1. Warming token...');
    const warmRes = await makeRequest('https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest', {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://h5.aoneroom.com/',
        'X-Client-Info': JSON.stringify({ timezone: 'Asia/Kolkata' }),
      },
      body: JSON.stringify({ keyword: 'avatar', perPage: 0 })
    });

    const xUserHeader = warmRes.headers['x-user'] || warmRes.headers['X-User'];
    if (!xUserHeader) {
      throw new Error('Failed to warm token, no x-user header found');
    }

    const userData = JSON.parse(xUserHeader);
    const token = userData.token;
    console.log(`   Token obtained: ${token.substring(0, 15)}...`);

    console.log('\n2. Searching for movie "Michael"...');
    const searchRes = await makeRequest('https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search', {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://h5.aoneroom.com/',
        'X-Client-Info': JSON.stringify({ timezone: 'Asia/Kolkata' }),
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        keyword: 'Michael',
        page: 1,
        perPage: 10,
        subjectType: 1
      })
    });

    const searchData = JSON.parse(searchRes.body);
    const items = searchData.data ? searchData.data.items : [];
    if (!items || items.length === 0) {
      throw new Error('No search results found');
    }

    const firstItem = items[0];
    const subjectId = firstItem.subjectId;
    const detailPath = firstItem.detailPath;
    console.log(`   Found subject: "${firstItem.title}" (ID: ${subjectId}, Path: ${detailPath})`);

    console.log('\n3. Resolving stream download URL...');
    const downloadRes = await makeRequest(`https://h5.aoneroom.com/wefeed-h5-bff/web/subject/download?subjectId=${subjectId}&se=0&ep=0&_t=${Date.now()}`, {
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': `https://h5.aoneroom.com/movies/${detailPath}`,
        'X-Client-Info': JSON.stringify({ timezone: 'Asia/Kolkata' }),
        'Authorization': `Bearer ${token}`
      }
    });

    const downloadData = JSON.parse(downloadRes.body);
    const downloads = downloadData.data ? downloadData.data.downloads : [];
    if (!downloads || downloads.length === 0) {
      throw new Error('No download streams found in response: ' + downloadRes.body);
    }

    const stream = downloads[0];
    const cdnUrl = stream.url;
    console.log(`   CDN URL: ${cdnUrl.substring(0, 100)}...`);

    console.log('\n4. Testing CDN URL with different headers:');

    // Test 1: No headers
    console.log('\n--- Test 1: No headers ---');
    try {
      const res1 = await makeRequest(cdnUrl);
      console.log(`Status: ${res1.status}, Content-Type: ${res1.headers['content-type'] || 'none'}, Length: ${res1.headers['content-length'] || 'none'}`);
    } catch (e) {
      console.log('Error:', e.message);
    }

    // Test 2: Standard Referer (https://h5.aoneroom.com/)
    console.log('\n--- Test 2: Standard Referer (https://h5.aoneroom.com/) ---');
    try {
      const res2 = await makeRequest(cdnUrl, {
        headers: {
          'Referer': 'https://h5.aoneroom.com/'
        }
      });
      console.log(`Status: ${res2.status}, Content-Type: ${res2.headers['content-type'] || 'none'}`);
    } catch (e) {
      console.log('Error:', e.message);
    }

    // Test 3: Detail Referer (https://h5.aoneroom.com/movies/[detailPath])
    console.log(`\n--- Test 3: Detail Referer (https://h5.aoneroom.com/movies/${detailPath}) ---`);
    try {
      const res3 = await makeRequest(cdnUrl, {
        headers: {
          'Referer': `https://h5.aoneroom.com/movies/${detailPath}`
        }
      });
      console.log(`Status: ${res3.status}, Content-Type: ${res3.headers['content-type'] || 'none'}`);
    } catch (e) {
      console.log('Error:', e.message);
    }

    // Test 4: User-Agent + Detail Referer
    console.log('\n--- Test 4: User-Agent + Detail Referer ---');
    try {
      const res4 = await makeRequest(cdnUrl, {
        headers: {
          'Referer': `https://h5.aoneroom.com/movies/${detailPath}`,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
        }
      });
      console.log(`Status: ${res4.status}, Content-Type: ${res4.headers['content-type'] || 'none'}`);
    } catch (e) {
      console.log('Error:', e.message);
    }

    // Test 5: Range header + User-Agent + Detail Referer
    console.log('\n--- Test 5: Range header + User-Agent + Detail Referer ---');
    try {
      const res5 = await makeRequest(cdnUrl, {
        headers: {
          'Referer': `https://h5.aoneroom.com/movies/${detailPath}`,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Range': 'bytes=0-100'
        }
      });
      console.log(`Status: ${res5.status}, Content-Range: ${res5.headers['content-range'] || 'none'}, Content-Type: ${res5.headers['content-type'] || 'none'}`);
    } catch (e) {
      console.log('Error:', e.message);
    }

  } catch (e) {
    console.error('Test run failed:', e);
  }
}

run();
