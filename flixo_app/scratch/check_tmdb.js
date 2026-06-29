/**
 * Fetch TMDB details and external IDs for movie "29" (ID: 1510769)
 */
const https = require('https');

const tmdbApiKey = 'ee88434dff18c194e5b7a1bec83824b8';

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => resolve({ status: res.statusCode, body }));
    }).on('error', reject);
  });
}

async function main() {
  console.log('Querying TMDB for movie 1510769 details...');
  try {
    const details = await fetchUrl(`https://api.themoviedb.org/3/movie/1510769?api_key=${tmdbApiKey}`);
    console.log('Details Status:', details.status);
    console.log('Details Body:', JSON.stringify(JSON.parse(details.body), null, 2));

    const externalIds = await fetchUrl(`https://api.themoviedb.org/3/movie/1510769/external_ids?api_key=${tmdbApiKey}`);
    console.log('\nExternal IDs Status:', externalIds.status);
    console.log('External IDs Body:', JSON.stringify(JSON.parse(externalIds.body), null, 2));
  } catch (e) {
    console.log('Error:', e.message);
  }
}
main();
