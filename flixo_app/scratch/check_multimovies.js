/**
 * Fetch actual KGF 2 movie page from multimovies.watch and 
 * check what streaming embed APIs they use
 */
const https = require('https');
const http = require('http');

function fetchUrl(url, options = {}) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith('https') ? https : http;
    const req = mod.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,*/*',
        'Referer': 'https://multimovies.watch/',
        ...options.headers
      },
      timeout: 15000
    }, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
  });
}

async function main() {
  // Fetch the actual KGF 2 page
  const url = 'https://multimovies.watch/movies/k-g-f-chapter-2/';
  console.log('Fetching:', url);
  const page = await fetchUrl(url);
  console.log('Status:', page.status);
  
  // Extract all iframe/embed src
  const iframeSrcs = [...page.body.matchAll(/(?:iframe|embed)[^>]+(?:src|data-src)=["']([^"']+)["']/gi)].map(m => m[1]);
  console.log('\n=== IFrame/Embed Sources ===');
  iframeSrcs.forEach(s => console.log(' -', s));
  
  // Extract JavaScript variables with URLs (common pattern in WP movie plugins)
  const jsUrls = [...page.body.matchAll(/(?:src|url|source|link|embed|player)\s*[:=]\s*["']([^"']+(?:embed|stream|player|api)[^"']*)["']/gi)].map(m => m[1]);
  console.log('\n=== JS Variables with stream URLs ===');
  jsUrls.slice(0, 20).forEach(s => console.log(' -', s));
  
  // Look for WordPress shortcodes or custom API calls
  const wpAjax = [...page.body.matchAll(/(?:wp\.ajax|admin-ajax|wp-admin\/admin-ajax\.php)[^"']*/gi)].map(m => m[0]);
  console.log('\n=== WP AJAX calls ===');
  wpAjax.slice(0, 10).forEach(s => console.log(' -', s));
  
  // Look for the video source list (the one shown in screenshot)
  const sourceNames = [...page.body.matchAll(/(?:GDMIRROR|Cineverse|Peachify|screenscape|Nxsha|nhdapi|GDrive|G-Mirror)[^<"']{0,100}/gi)].map(m => m[0].trim());
  console.log('\n=== Source Names in Page ===');
  sourceNames.slice(0, 20).forEach(s => console.log(' -', s));
  
  // Find POST API endpoints
  const postUrls = [...page.body.matchAll(/(?:post|fetch|xhr|ajax)[^}]{0,200}url\s*[:=]\s*["']([^"']+)["']/gi)].map(m => m[1]);
  console.log('\n=== POST/Fetch API URLs ===');
  postUrls.slice(0, 10).forEach(s => console.log(' -', s));

  // Save the full source for manual inspection
  require('fs').writeFileSync('scratch/kgf2_page_source.html', page.body);
  console.log('\nFull page saved to scratch/kgf2_page_source.html');

  // Also check these providers that are known to work and have public APIs
  console.log('\n\n=== Testing Free Public Movie Stream APIs (No Login Required) ===');
  const freeApis = [
    // VidSrc - very popular, no restrictions
    { name: 'VidSrc.net API', url: 'https://vidsrc.net/embed/movie/tt8080598' },  // KGF2 imdb
    // 2embed - another popular one
    { name: '2Embed API', url: 'https://www.2embed.cc/embed/tt8080598' },
    // MoviesApi - popular free Indian movie API
    { name: 'MoviesApi.club', url: 'https://moviesapi.club/movie/tt8080598' },
    // AnyEmbed/Gomovies
    { name: 'FlixHQ', url: 'https://flixhq.to/ajax/movie/episodes/tt8080598' },
    // Hindi specific 
    { name: 'Bollyflix', url: 'https://bollyflix.video/api/v1/movie/tt8080598' },
    // FilmyStar (big Indian site)
    { name: 'FilmyStar embed', url: 'https://filmystar.life/embed/507086' },
    // NowTv (Indian CDN)
    { name: 'NowTV API', url: 'https://api.nowtv.in/v1/movie/507086' },
  ];
  
  for (const api of freeApis) {
    try {
      const r = await fetchUrl(api.url);
      console.log(`\n${api.name}: HTTP ${r.status}`);
      if (r.status === 200) {
        const streams = (r.body.match(/https?:[^\s"'\\]+\.(m3u8|mp4)[^\s"'\\]*/gi) || []);
        if (streams.length > 0) {
          console.log('✅ STREAMS FOUND:', streams.slice(0, 3));
        } else {
          console.log('Body preview:', r.body.substring(0, 300));
        }
      }
    } catch(e) {
      console.log(`${api.name}: ERROR - ${e.message}`);
    }
  }
}

main().catch(console.error);
