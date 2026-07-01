// Disable automatic body parsing to allow streaming raw request body bytes
export const config = {
  api: {
    bodyParser: false,
  },
};

const http = require('http');
const https = require('https');
const { URL } = require('url');


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

  const isWhitelisted = 
    hostname.endsWith('themoviedb.org') ||
    hostname.endsWith('tmdb.org') ||
    hostname.endsWith('archive.org') ||
    hostname.endsWith('aoneroom.com') ||
    hostname.endsWith('hakunaymatata.com') ||
    hostname.endsWith('moviebox.org') ||
    hostname.endsWith('showbox.xyz') ||
    hostname.endsWith('strem.fun') ||
    hostname.endsWith('stremio.com') ||
    hostname.endsWith('github.io') ||
    hostname.endsWith('githubusercontent.com') ||
    hostname.endsWith('youtube.com') ||
    hostname.endsWith('ytimg.com');

  if (!isWhitelisted) {
    return res.status(403).send('Forbidden: Domain not whitelisted in proxy');
  }

  // Build headers to forward
  const forwardHeaders = {};
  if (req.headers.authorization) forwardHeaders['Authorization'] = req.headers.authorization;
  if (req.headers['x-client-info']) forwardHeaders['X-Client-Info'] = req.headers['x-client-info'];
  if (req.headers['content-type']) forwardHeaders['Content-Type'] = req.headers['content-type'];
  if (req.headers['range']) forwardHeaders['range'] = req.headers['range'];
  if (req.headers['accept']) forwardHeaders['Accept'] = req.headers['accept'];

  // Set proper Referer, Origin, and User-Agent
  const queryReferer = req.query.referer;
  if (queryReferer) {
    forwardHeaders['Referer'] = queryReferer;
    try {
      const refUri = new URL(queryReferer);
      forwardHeaders['Origin'] = `${refUri.protocol}//${refUri.hostname}`;
    } catch (_) {}
  } else if (targetUrl.includes('aoneroom.com') || targetUrl.includes('hakunaymatata.com')) {
    forwardHeaders['Referer'] = 'https://h5.aoneroom.com/';
    forwardHeaders['Origin'] = 'https://h5.aoneroom.com';
  } else if (req.headers.referer) {
    forwardHeaders['Referer'] = req.headers.referer;
    try {
      const refUri = new URL(req.headers.referer);
      forwardHeaders['Origin'] = `${refUri.protocol}//${refUri.hostname}`;
    } catch (_) {}
  }
  forwardHeaders['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

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

      res.writeHead(targetRes.statusCode);
      targetRes.pipe(res);
    });

    targetReq.on('error', (err) => {
      console.error('Proxy error:', err.message);
      if (!res.headersSent) {
        res.status(502).send(JSON.stringify({ error: err.message, target: targetUrl }));
      }
    });

    // Pipe incoming request body if exists
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      req.pipe(targetReq);
    } else {
      targetReq.end();
    }
  };

  makeRequest(targetUrl);
}
