/**
 * Local MovieBox Proxy - Run with: node local_moviebox_proxy.js
 * 
 * This proxy runs on your machine (localhost:3009) and forwards
 * requests to aoneroom.com WITHOUT browser headers (Sec-Fetch etc.)
 * This allows getting real download URLs that browsers can't get directly.
 * 
 * Flutter web calls: http://localhost:3009/api?url=<encoded_url>
 *
 * FIX APPLIED: the video-streaming branch now reads the `auth` query
 * parameter and forwards it as an `authorization` header to the upstream
 * CDN. Previously this branch silently dropped it, causing every
 * hakunaymatata.com/aoneroom.com stream request to come back 403,
 * since those CDNs require the bearer token to authorize the signed URL.
 * The referer logic was also fixed to respect the `referer` query param
 * instead of always hardcoding it for hakunaymatata/aoneroom hosts.
 */

const http = require('http');
const https = require('https');
const { URL } = require('url');

const PORT = 3009;

// Make a direct HTTPS request (no browser headers - mimics native Dart)
function directFetch(targetUrl, options = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(targetUrl);
    const reqOptions = {
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      method: options.method || 'GET',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        // IMPORTANT: Must match the streaming UA exactly — CDN ties the sign= to User-Agent
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        ...(options.headers || {}),
        // NOTE: No Origin, no Sec-Fetch headers - exactly like native Dart
      },
      rejectUnauthorized: false,
      family: 4, // Force IPv4 to prevent signature mismatches with CDN
    };

    const req = https.request(reqOptions, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve({ 
        status: res.statusCode, 
        headers: res.headers, 
        body 
      }));
    });
    
    req.on('error', reject);
    req.setTimeout(10000, () => req.destroy(new Error('timeout')));
    
    if (options.body) req.write(options.body);
    req.end();
  });
}

const server = http.createServer(async (req, res) => {
  // CORS headers - allow Flutter web (localhost:*) to call this proxy
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Client-Info, Referer, X-App-Referer');
  res.setHeader('Access-Control-Expose-Headers', 'x-user');
  
  // Disable caching for proxy responses
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  const reqUrl = new URL(req.url, `http://localhost:${PORT}`);

  if (reqUrl.pathname === '/warm-token') {
    const targetUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest';
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        console.log(`[Proxy] Warming guest token locally (POST /subject/search-suggest)`);
        const forwardHeaders = {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Client-Info': req.headers['x-client-info'] || '{"timezone":"Asia/Kolkata","device_id":"8cfa827bc129486c","os":"android","version":"3.1.2"}',
          'User-Agent': 'MovieBox/3.1.2 (Android 13)',
          'Referer': 'https://www.movieboxpro.app/',
        };
        const result = await directFetch(targetUrl, {
          method: 'POST',
          headers: forwardHeaders,
          body: body || undefined,
        });
        if (result.headers['x-user']) {
          res.setHeader('x-user', result.headers['x-user']);
          console.log(`  Successfully obtained x-user token: ${result.headers['x-user'].substring(0, 30)}...`);
        } else {
          console.log(`  ⚠️ Warmed token response did not contain x-user header!`);
        }
        res.writeHead(result.status, { 'Content-Type': 'application/json' });
        res.end(result.body);
      } catch (e) {
        console.error(`  ❌ Error warming token: ${e.message}`);
        res.writeHead(500);
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  if (reqUrl.pathname === '/proxy-tiktok') {
    const urlMatch = req.url.match(/[\?&]url=([^&]+)/);
    if (!urlMatch) {
      res.writeHead(400);
      res.end('Missing ?url= parameter');
      return;
    }
    const urlParam = decodeURIComponent(urlMatch[1]);
    
    const vercelProxy = 'https://ver-orcin-alpha.vercel.app/api';
    const proxyUrl = `${vercelProxy}?url=${encodeURIComponent(urlParam)}`;
    console.log(`[Proxy] Proxying TikTok segment via Vercel: ${urlParam}`);
    
    const parsed = new URL(proxyUrl);
    const reqOptions = {
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'identity',
      }
    };
    
    const rangeHeader = req.headers['range'];
    let needStrip = false;
    if (rangeHeader) {
      const match = rangeHeader.match(/bytes=(\d+)-(\d+)?/);
      if (match) {
        const start = parseInt(match[1], 10);
        const end = match[2] ? parseInt(match[2], 10) : null;
        reqOptions.headers['Range'] = `bytes=${start + 70}-${end !== null ? (end + 70) : ''}`;
      } else {
        reqOptions.headers['Range'] = rangeHeader;
      }
    } else {
      needStrip = true;
    }
    
    const proxyReq = https.request(reqOptions, (proxyRes) => {
      console.log(`[Proxy] TikTok proxy response status: ${proxyRes.statusCode}`);
      if (proxyRes.statusCode >= 400) {
        console.log('[Proxy] Response headers:', JSON.stringify(proxyRes.headers));
        let body = '';
        proxyRes.on('data', d => body += d);
        proxyRes.on('end', () => {
          console.log('[Proxy] Response error body:', body);
          res.writeHead(proxyRes.statusCode, proxyRes.headers);
          res.end(body);
        });
      } else {
        const headers = { ...proxyRes.headers };
        if (headers['content-range']) {
          const rangeMatch = headers['content-range'].match(/bytes (\d+)-(\d+)\/(\d+)/);
          if (rangeMatch) {
            const start = Math.max(0, parseInt(rangeMatch[1], 10) - 70);
            const end = Math.max(0, parseInt(rangeMatch[2], 10) - 70);
            const total = Math.max(0, parseInt(rangeMatch[3], 10) - 70);
            headers['content-range'] = `bytes ${start}-${end}/${total}`;
          }
        }
        if (needStrip && headers['content-length']) {
          const len = parseInt(headers['content-length'], 10);
          headers['content-length'] = Math.max(0, len - 70).toString();
        }
        headers['content-type'] = 'video/mp2t';
        res.writeHead(proxyRes.statusCode, headers);
        
        if (needStrip) {
          let stripped = false;
          let bytesRead = 0;
          proxyRes.on('data', (chunk) => {
            if (!stripped) {
              if (bytesRead + chunk.length > 70) {
                const sliceOffset = 70 - bytesRead;
                res.write(chunk.slice(sliceOffset));
                stripped = true;
              }
              bytesRead += chunk.length;
            } else {
              res.write(chunk);
            }
          });
          proxyRes.on('end', () => {
            res.end();
          });
        } else {
          proxyRes.pipe(res);
        }
      }
    });
    
    proxyReq.on('error', (err) => {
      console.error('[Proxy] TikTok proxy error:', err);
      res.writeHead(500);
      res.end(err.message);
    });
    
    proxyReq.end();
    return;
  }

  if (reqUrl.pathname === '/resolve-2embed') {
    const imdbId = reqUrl.searchParams.get('imdbId');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Content-Type', 'application/json');
    if (!imdbId) {
      res.writeHead(400);
      res.end(JSON.stringify({ error: 'Missing ?imdbId= parameter' }));
      return;
    }
    
    console.log(`[Proxy] Resolving 2embed for IMDb ID: ${imdbId}`);
    try {
      const embedPage = await directFetch(`https://www.2embed.cc/embed/${imdbId}`, {
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
        }
      });
      
      const swishMatch = embedPage.body.match(/data-src=["'](https:\/\/streamsrcs\.2embed\.cc\/swish\?id=([^&"']+)[^"']*)["']/i)
                       || embedPage.body.match(/src=["'](https:\/\/streamsrcs\.2embed\.cc\/swish\?id=([^&"']+)[^"']*)["']/i);
      
      if (!swishMatch) {
        console.log('[Proxy] LookMovie stream not found on 2embed');
        res.writeHead(404);
        res.end(JSON.stringify({ error: 'LookMovie stream not found for this movie on 2embed' }));
        return;
      }
      
      const streamId = swishMatch[2];
      
      const lookmoviePage = await directFetch(`https://lookmovie2.skin/e/${streamId}`, {
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Referer': 'https://streamsrcs.2embed.cc/'
        }
      });
      
      const evalMatch = lookmoviePage.body.match(/eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)/);
      if (!evalMatch) {
        console.log('[Proxy] Dean Edwards packed script not found on lookmovie');
        res.writeHead(500);
        res.end(JSON.stringify({ error: 'Failed to find packed player code' }));
        return;
      }
      
      // Unpacker helper
      const code = evalMatch[0].trim().substring(5, evalMatch[0].trim().length - 1);
      const runUnpacker = new Function('return (' + code + ');');
      const unpacked = runUnpacker();
      
      let directStreamUrl = '';
      const hls4Match = unpacked.match(/"hls4"\s*:\s*"([^"]+)"/);
      if (hls4Match && hls4Match[1]) {
        directStreamUrl = `https://lookmovie2.skin${hls4Match[1]}`;
        console.log(`[Proxy] Found HLS4 stream (tiktok): ${directStreamUrl}`);
      } else {
        const hls2Match = unpacked.match(/"hls2"\s*:\s*"([^"]+)"/);
        if (hls2Match && hls2Match[1]) {
          directStreamUrl = hls2Match[1];
          console.log(`[Proxy] Falling back to HLS2 stream (premilkyway): ${directStreamUrl}`);
        } else {
          const m3u8Match = unpacked.match(/https?:\/\/[^\s"']+\.m3u8[^\s"']*/i);
          if (m3u8Match) {
            directStreamUrl = m3u8Match[0];
            console.log(`[Proxy] Falling back to regex stream match: ${directStreamUrl}`);
          }
        }
      }

      if (!directStreamUrl) {
        console.log('[Proxy] m3u8 link not found in unpacked JS');
        res.writeHead(404);
        res.end(JSON.stringify({ error: 'Failed to extract direct stream link' }));
        return;
      }
      
      console.log(`[Proxy] Resolved direct stream URL: ${directStreamUrl}`);
      
      res.writeHead(200);
      res.end(JSON.stringify({ url: directStreamUrl }));
      return;
    } catch (e) {
      console.error(`[Proxy] Error resolving 2embed: ${e.message}`);
      res.writeHead(500);
      res.end(JSON.stringify({ error: e.message }));
      return;
    }
  }

  const targetUrl = reqUrl.searchParams.get('url');

  if (!targetUrl) {
    res.writeHead(400);
    res.end(JSON.stringify({ error: 'Missing ?url= parameter' }));
    return;
  }

  // Support video streaming (MP4/MKV) via chunked piping and Range headers
  const isVideo = targetUrl.includes('.mp4') || targetUrl.includes('.mkv') || targetUrl.includes('/bt/') || targetUrl.includes('.m3u8') || targetUrl.includes('.ts');
  if (req.method === 'GET' && isVideo) {
    try {
      const parsed = new URL(targetUrl);
      const forwardHeaders = {};
      
      const targetHost = parsed.hostname;
      const customReferer = reqUrl.searchParams.get('referer');
      if (targetHost.includes('hakunaymatata.com') || targetHost.includes('aoneroom.com')) {
        forwardHeaders['referer'] = customReferer || 'https://h5.aoneroom.com/';
        forwardHeaders['user-agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
      } else if (targetHost.includes('premilkyway.com') || targetHost.includes('uqloads.com') || targetHost.includes('lookmovie')) {
        forwardHeaders['referer'] = 'https://lookmovie2.skin/';
        forwardHeaders['user-agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
      } else {
        if (customReferer) {
          forwardHeaders['referer'] = customReferer;
        }
        forwardHeaders['user-agent'] = req.headers['user-agent'] || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
      }
      
      const authParam = reqUrl.searchParams.get('auth');
      if (authParam && (targetHost.includes('hakunaymatata.com') || targetHost.includes('aoneroom.com'))) {
        forwardHeaders['authorization'] = authParam;
      }

      if (req.headers['range']) {
        forwardHeaders['range'] = req.headers['range'];
      }
      forwardHeaders['accept'] = '*/*';
      forwardHeaders['accept-language'] = 'en-US,en;q=0.9';
      
      // Remove connection or host headers that might cause protocol mismatches in Node
      delete forwardHeaders['connection'];
      delete forwardHeaders['host'];
      
      console.log(`  [STREAMING VIDEO] ${parsed.hostname}${parsed.pathname} | Range: ${req.headers['range'] || 'none'}`);
      
      const makeRequest = (currentUrl) => {
        const currentParsed = new URL(currentUrl);
        const isHttps = currentParsed.protocol === 'https:';
        const clientLib = isHttps ? https : http;
        
        console.log(`    ➡️ Streaming Request to: ${currentParsed.hostname}${currentParsed.pathname}`);
        console.log(`    ➡️ Forward Headers: Referer: "${forwardHeaders['referer'] || 'none'}" | UA: "${forwardHeaders['user-agent'] || 'none'}" | Auth: "${forwardHeaders['authorization'] ? forwardHeaders['authorization'].substring(0, 20) + '...' : 'none'}"`);

        const reqOptions = {
          hostname: currentParsed.hostname,
          port: currentParsed.port || (isHttps ? 443 : 80),
          path: currentParsed.pathname + currentParsed.search,
          method: 'GET',
          headers: forwardHeaders,
          rejectUnauthorized: false,
          family: 4, // Force IPv4 — must match the IP family used when the sign token
                     // was issued by directFetch(), or the CDN edge rejects it as a
                     // signature mismatch (this was the actual cause of the 403s)
        };
        
        const targetReq = clientLib.request(reqOptions, (targetRes) => {
          // Handle redirects server-side so the browser never gets redirected directly (which would bypass the proxy)
          if ([301, 302, 303, 307, 308].includes(targetRes.statusCode) && targetRes.headers.location) {
            const redirectUrl = new URL(targetRes.headers.location, currentUrl).toString();
            console.log(`    ➡️ Following redirect to: ${new URL(redirectUrl).hostname}${new URL(redirectUrl).pathname}`);
            targetRes.resume(); // Consume the redirect response body to free the socket
            makeRequest(redirectUrl);
            return;
          }
          
          console.log(`    🎥 Status: ${targetRes.statusCode} | Type: ${targetRes.headers['content-type']} | Length: ${targetRes.headers['content-length']}`);
          
          res.setHeader('Access-Control-Allow-Origin', '*');
          res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
          res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Client-Info, Referer, Range, X-App-Referer');
          res.setHeader('Access-Control-Expose-Headers', 'Content-Range, Accept-Ranges, Content-Length, Content-Type');
          
          if (targetRes.statusCode >= 400) {
            let bodyData = '';
            targetRes.on('data', chunk => bodyData += chunk.toString());
            targetRes.on('end', () => {
              console.log(`    ❌ CDN Error Response Body: "${bodyData}"`);
              res.writeHead(targetRes.statusCode, { 'Content-Type': targetRes.headers['content-type'] || 'text/html' });
              res.end(bodyData);
            });
            return;
          }

          // Force video/mp4 content-type if missing or octet-stream to ensure browser plays it instead of downloading
          let contentType = targetRes.headers['content-type'];
          if (!contentType || contentType === 'application/octet-stream' || contentType === 'binary/octet-stream') {
            contentType = 'video/mp4';
          }
          res.setHeader('Content-Type', contentType);
          
          if (targetRes.headers['content-length']) res.setHeader('Content-Length', targetRes.headers['content-length']);
          if (targetRes.headers['content-range']) res.setHeader('Content-Range', targetRes.headers['content-range']);
          if (targetRes.headers['accept-ranges']) res.setHeader('Accept-Ranges', targetRes.headers['accept-ranges']);
          
          res.writeHead(targetRes.statusCode);
          targetRes.pipe(res);
        });
        
        targetReq.on('error', (err) => {
          console.error(`    ❌ Stream Error:`, err);
          if (!res.headersSent) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: err ? (err.message || err.toString()) : 'Unknown error' }));
          }
        });
        
        targetReq.end();
      };

      makeRequest(targetUrl);
      return;
    } catch (err) {
      console.error(`  ❌ Stream Setup Error: ${err.message}`);
      res.writeHead(500);
      res.end(JSON.stringify({ error: err.message }));
      return;
    }
  }

  // Read incoming request body
  let body = '';
  req.on('data', d => body += d);
  req.on('end', async () => {
    try {
      console.log(`[${req.method}] ${new URL(targetUrl).pathname}`);

      // Forward request headers from Flutter (Authorization, X-Client-Info, etc.)
      const forwardHeaders = {};
      const headersToForward = ['authorization', 'x-client-info', 'referer', 'content-type', 'accept', 'x-app-referer'];
      for (const h of headersToForward) {
        if (req.headers[h]) {
          forwardHeaders[h] = req.headers[h];
        }
      }
      
      // Fix referer header (browsers block setting custom Referer, so we use X-App-Referer)
      if (forwardHeaders['x-app-referer']) {
        forwardHeaders['referer'] = forwardHeaders['x-app-referer'];
        delete forwardHeaders['x-app-referer'];
      } else if (forwardHeaders['referer'] && (forwardHeaders['referer'].includes('localhost') || forwardHeaders['referer'].includes('127.0.0.1'))) {
        // Fallback: replace localhost referer with default aoneroom domain
        forwardHeaders['referer'] = 'https://h5.aoneroom.com/';
      }
      
      console.log(`  Headers forwarded: ${Object.keys(forwardHeaders).join(', ')}`);
      if (forwardHeaders['referer']) {
        console.log(`  Referer: ${forwardHeaders['referer']}`);
      }
      if (forwardHeaders['authorization']) {
        console.log(`  Auth: ${forwardHeaders['authorization'].substring(0, 30)}...`);
      }

      const result = await directFetch(targetUrl, {
        method: req.method,
        headers: forwardHeaders,
        body: body || undefined,
      });

      // Forward x-user header (contains auth token)
      if (result.headers['x-user']) {
        res.setHeader('x-user', result.headers['x-user']);
      }

      res.writeHead(result.status, { 'Content-Type': 'application/json' });
      res.end(result.body);
      
      // Log response details
      const isDownload = targetUrl.includes('subject/download');
      if (isDownload) {
        console.log(`  Download Response: ${result.body}`);
      } else {
        try {
          const data = JSON.parse(result.body);
          if (targetUrl.includes('subject/search')) {
            const itemsCount = data?.data?.items?.length || 0;
            console.log(`  Search results found: ${itemsCount}`);
          }
        } catch (_) {}
      }

    } catch (e) {
      console.error(`  ❌ Error: ${e.message}`);
      res.writeHead(500);
      res.end(JSON.stringify({ error: e.message }));
    }
  });
});

server.listen(PORT, () => {
  console.log('');
  console.log('🟢 Local MovieBox Proxy running on http://localhost:' + PORT);
  console.log('   Flutter web will use this for MovieBox streams');
  console.log('   (Makes requests with your Indian IP, no browser headers)');
  console.log('');
  console.log('   Keep this running while using the web app');
  console.log('   Press Ctrl+C to stop');
  console.log('');
});
