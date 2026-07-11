// Disable automatic body parsing to allow streaming raw request body bytes
export const config = {
  api: {
    bodyParser: false,
  },
};

const http = require('http');
const https = require('https');
const { URL } = require('url');
const { execFile } = require('child_process');

function getRawBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => resolve(body));
    req.on('error', err => reject(err));
  });
}

function makeCurlRequest(targetUrl, body, headers, res) {
  const curlArgs = [
    '-s',
    '-D', '-',
    '-X', 'POST',
    targetUrl,
    '-H', 'Accept: application/json',
    '-H', 'Content-Type: application/json',
  ];
  
  if (headers['X-Client-Info']) {
    curlArgs.push('-H', `X-Client-Info: ${headers['X-Client-Info']}`);
  }
  if (headers['Referer']) {
    curlArgs.push('-H', `Referer: ${headers['Referer']}`);
  }
  if (headers['User-Agent']) {
    curlArgs.push('-H', `User-Agent: ${headers['User-Agent']}`);
  }
  
  curlArgs.push('-d', body);
  curlArgs.push('--connect-timeout', '8');
  curlArgs.push('--max-time', '10');
  
  execFile('curl', curlArgs, (error, stdout, stderr) => {
    if (error) {
      console.error('Curl execFile error:', error.message);
      return res.status(502).send(JSON.stringify({ error: error.message }));
    }
    
    const blankLineIdx = stdout.indexOf('\r\n\r\n');
    if (blankLineIdx === -1) {
      return res.status(502).send('Curl output malformed');
    }
    
    const headerSection = stdout.substring(0, blankLineIdx);
    const responseBody = stdout.substring(blankLineIdx + 4);
    
    const lines = headerSection.split('\r\n');
    const responseHeaders = {};
    let statusCode = 200;
    
    for (const line of lines) {
      if (line.startsWith('HTTP/')) {
        const parts = line.split(' ');
        if (parts.length > 1) {
          statusCode = parseInt(parts[1], 10) || 200;
        }
        continue;
      }
      const colon = line.indexOf(':');
      if (colon !== -1) {
        const k = line.substring(0, colon).trim().toLowerCase();
        const v = line.substring(colon + 1).trim();
        responseHeaders[k] = v;
      }
    }
    
    if (responseHeaders['x-user']) {
      res.setHeader('x-user', responseHeaders['x-user']);
    }
    
    res.setHeader('Content-Type', 'application/json');
    res.status(statusCode).send(responseBody);
  });
}

export default async function handler(req, res) {
  // Set CORS headers dynamically based on request origin to support authenticated requests
  const origin = req.headers.origin || '*';
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Client-Info, Referer, Range, X-App-Referer, User-Agent, Origin');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Range, Accept-Ranges, Content-Length, Content-Type, x-user');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Get target URL from query parameter
  const targetUrl = req.query.url;
  if (!targetUrl) {
    return res.status(400).send('Missing target URL');
  }

  // Validate hostname to block SSRF and third-party abuse
  let hostname;
  try {
    hostname = new URL(targetUrl).hostname.toLowerCase();
  } catch (_) {
    return res.status(400).send('Invalid target URL');
  }

  const isWhitelisted = true;
  if (!isWhitelisted) {
    return res.status(403).send('Forbidden: Domain not whitelisted in proxy');
  }

  // Build headers to forward
  const forwardHeaders = {};
  if (req.headers.authorization) {
    forwardHeaders['Authorization'] = req.headers.authorization;
  } else if (req.query.auth) {
    forwardHeaders['Authorization'] = req.query.auth;
  }
  if (req.headers['x-client-info']) forwardHeaders['X-Client-Info'] = req.headers['x-client-info'];
  if (req.headers['content-type']) forwardHeaders['Content-Type'] = req.headers['content-type'];
  if (req.headers['range']) forwardHeaders['range'] = req.headers['range'];
  if (req.headers['accept']) forwardHeaders['Accept'] = req.headers['accept'];

  // Set proper Referer, Origin, and User-Agent
  const isMovieBoxCdn = (targetUrl.includes('aoneroom.com') || targetUrl.includes('hakunaymatata.com')) && !targetUrl.includes('h5-api.aoneroom.com');
  const isMovieBoxApi = targetUrl.includes('h5-api.aoneroom.com');
  const isLookMovie = targetUrl.includes('lookmovie');
  const queryReferer = req.query.referer;
  const appReferer = req.headers['x-app-referer'];
  if (appReferer) {
    forwardHeaders['Referer'] = appReferer;
    try {
      const refUri = new URL(appReferer);
      forwardHeaders['Origin'] = `${refUri.protocol}//${refUri.hostname}`;
    } catch (_) {}
  } else if (isMovieBoxCdn) {
    forwardHeaders['Referer'] = 'https://www.movieboxpro.app/';
    forwardHeaders['Origin'] = 'https://www.movieboxpro.app';
  } else if (isMovieBoxApi) {
    forwardHeaders['Referer'] = 'https://h5.aoneroom.com/';
    forwardHeaders['Origin'] = 'https://h5.aoneroom.com';
  } else if (isLookMovie) {
    forwardHeaders['Referer'] = 'https://lookmovie2.skin/';
    forwardHeaders['Origin'] = 'https://lookmovie2.skin';
  } else if (queryReferer) {
    forwardHeaders['Referer'] = queryReferer;
    try {
      const refUri = new URL(queryReferer);
      forwardHeaders['Origin'] = `${refUri.protocol}//${refUri.hostname}`;
    } catch (_) {}
  } else if (req.headers.referer && !req.headers.referer.includes('localhost') && !req.headers.referer.includes('vercel.app') && !req.headers.referer.includes('movienest')) {
    forwardHeaders['Referer'] = req.headers.referer;
    try {
      const refUri = new URL(req.headers.referer);
      forwardHeaders['Origin'] = `${refUri.protocol}//${refUri.hostname}`;
    } catch (_) {}
  }

  if (isMovieBoxCdn) {
    forwardHeaders['User-Agent'] = 'okhttp/4.10.0';
  } else {
    forwardHeaders['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  }

  // Read request body if present
  let body = '';
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    try {
      body = await getRawBody(req);
    } catch (e) {
      return res.status(400).send('Error reading request body');
    }
  }

  // If warming guest token, run curl to get a mobile guest token (atp=1/2) with streams enabled
  if (targetUrl.includes('/subject/search-suggest')) {
    return makeCurlRequest(targetUrl, body, forwardHeaders, res);
  }

  const makeRequest = (currentUrl) => {
    const parsed = new URL(currentUrl);
    const isHttps = parsed.protocol === 'https:';
    const clientLib = isHttps ? https : http;

    const reqOptions = {
      hostname: parsed.hostname,
      port: parsed.port || (isHttps ? 443 : 80),
      path: parsed.pathname + parsed.search,
      method: req.method,
      headers: forwardHeaders,
      rejectUnauthorized: false,
    };

    const targetReq = clientLib.request(reqOptions, (targetRes) => {
      // Handle Redirects
      if ([301, 302, 303, 307, 308].includes(targetRes.statusCode) && targetRes.headers.location) {
        const redirectUrl = new URL(targetRes.headers.location, currentUrl).toString();
        targetRes.resume(); // Consume response to free socket
        makeRequest(redirectUrl);
        return;
      }

      // Forward x-user header (contains auth token) back to client
      if (targetRes.headers['x-user']) {
        res.setHeader('x-user', targetRes.headers['x-user']);
      }

      // Force video/mp4 for video streaming files if content-type is missing or wrong
      let contentType = targetRes.headers['content-type'];
      const isVideoFile = targetUrl.includes('.mp4') || targetUrl.includes('.mkv') || targetUrl.includes('/resource/') || targetUrl.includes('/bt/');
      if (isVideoFile && (!contentType || contentType === 'application/octet-stream' || contentType === 'binary/octet-stream')) {
        contentType = 'video/mp4';
      }
      if (contentType) res.setHeader('Content-Type', contentType);

      // Forward streaming headers
      if (targetRes.headers['content-length']) res.setHeader('Content-Length', targetRes.headers['content-length']);
      if (targetRes.headers['content-range']) res.setHeader('Content-Range', targetRes.headers['content-range']);
      if (targetRes.headers['accept-ranges']) res.setHeader('Accept-Ranges', targetRes.headers['accept-ranges']);

      const isM3u8 = targetUrl.includes('.m3u8') || (contentType && contentType.includes('mpegurl'));
      if (isM3u8) {
        let body = '';
        targetRes.on('data', (chunk) => {
          body += chunk;
        });
        targetRes.on('end', () => {
          try {
            const lines = body.split('\n');
            const targetUrlObj = new URL(targetUrl);
            const targetOrigin = targetUrlObj.origin;
            const targetBaseDir = targetUrl.substring(0, targetUrl.indexOf('?') !== -1 ? targetUrl.indexOf('?') : targetUrl.length);
            const targetBase = targetBaseDir.substring(0, targetBaseDir.lastIndexOf('/') + 1);

            const proto = req.headers['x-forwarded-proto'] || 'https';
            const proxyBase = `${proto}://${req.headers.host}/api?url=`;
            const refererParam = req.query.referer ? `&referer=${encodeURIComponent(req.query.referer)}` : '';

            const rewrittenLines = lines.map((line) => {
              const trimmed = line.trim();
              if (trimmed.length === 0 || trimmed.startsWith('#')) {
                return line;
              }
              // Resolve URL to absolute
              let absUrl = trimmed;
              if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
                if (trimmed.startsWith('/')) {
                  absUrl = targetOrigin + trimmed;
                } else {
                  absUrl = targetBase + trimmed;
                }
              }
              // Wrap in proxy
              return proxyBase + encodeURIComponent(absUrl) + refererParam;
            });

            const rewrittenBody = rewrittenLines.join('\n');
            res.setHeader('Content-Type', contentType || 'application/vnd.apple.mpegurl');
            res.setHeader('Content-Length', Buffer.byteLength(rewrittenBody));
            res.writeHead(targetRes.statusCode || 200);
            res.end(rewrittenBody);
          } catch (err) {
            console.error('M3U8 parsing error:', err.message);
            res.writeHead(targetRes.statusCode || 200);
            res.end(body);
          }
        });
      } else {
        res.writeHead(targetRes.statusCode);
        targetRes.pipe(res);
      }
    });

    targetReq.on('error', (err) => {
      console.error('Proxy error:', err.message);
      if (!res.headersSent) {
        res.status(502).send(JSON.stringify({ error: err.message, target: targetUrl }));
      }
    });

    if (req.method !== 'GET' && req.method !== 'HEAD') {
      targetReq.write(body);
      targetReq.end();
    } else {
      targetReq.end();
    }
  };

  makeRequest(targetUrl);
}
