// Disable automatic body parsing to allow streaming raw request body bytes
export const config = {
  api: {
    bodyParser: false,
  },
};

const http = require('http');
const https = require('https');
const { URL } = require('url');

const GENRES = {
  28: 'Action', 12: 'Adventure', 16: 'Animation', 35: 'Comedy',
  80: 'Crime', 99: 'Documentary', 18: 'Drama', 10751: 'Family',
  14: 'Fantasy', 36: 'History', 27: 'Horror', 10402: 'Music',
  9648: 'Mystery', 10749: 'Romance', 878: 'Sci-Fi', 10770: 'TV Movie',
  53: 'Thriller', 10752: 'War', 37: 'Western'
};

const BOT_TOKEN = '8352588589:AAF9eJkNtB6KdXEcVfKOnS1bwJ-ELu_UR1M';

function searchTMDB(query) {
  return new Promise((resolve) => {
    const apiKey = 'ee88434dff18c194e5b7a1bec83824b8';
    const url = `https://api.themoviedb.org/3/search/movie?api_key=${apiKey}&query=${encodeURIComponent(query)}&include_adult=false`;
    https.get(url, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body).results || []);
        } catch (_) {
          resolve([]);
        }
      });
    }).on('error', () => resolve([]));
  });
}

function getTrendingMovies() {
  return new Promise((resolve) => {
    const apiKey = 'ee88434dff18c194e5b7a1bec83824b8';
    const url = `https://api.themoviedb.org/3/trending/movie/week?api_key=${apiKey}`;
    https.get(url, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body).results || []);
        } catch (_) {
          resolve([]);
        }
      });
    }).on('error', () => resolve([]));
  });
}

function getNowPlayingMovies() {
  return new Promise((resolve) => {
    const apiKey = 'ee88434dff18c194e5b7a1bec83824b8';
    const url = `https://api.themoviedb.org/3/movie/now_playing?api_key=${apiKey}`;
    https.get(url, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body).results || []);
        } catch (_) {
          resolve([]);
        }
      });
    }).on('error', () => resolve([]));
  });
}

function getPopularMovies() {
  return new Promise((resolve) => {
    const apiKey = 'ee88434dff18c194e5b7a1bec83824b8';
    const url = `https://api.themoviedb.org/3/movie/popular?api_key=${apiKey}`;
    https.get(url, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body).results || []);
        } catch (_) {
          resolve([]);
        }
      });
    }).on('error', () => resolve([]));
  });
}

function getAnime() {
  return new Promise((resolve) => {
    const apiKey = 'ee88434dff18c194e5b7a1bec83824b8';
    const url = `https://api.themoviedb.org/3/discover/movie?api_key=${apiKey}&with_genres=16&with_original_language=ja&sort_by=popularity.desc`;
    https.get(url, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body).results || []);
        } catch (_) {
          resolve([]);
        }
      });
    }).on('error', () => resolve([]));
  });
}

function formatMovieList(movies, header) {
  if (!movies || movies.length === 0) return '❌ No movies found.';
  let lines = [`🎬 **${header}**`, ''];
  movies.slice(0, 10).forEach((m, i) => {
    const title = m.title || 'Unknown';
    const year = m.release_date ? m.release_date.substring(0, 4) : 'N/A';
    const rating = m.vote_average ? m.vote_average.toFixed(1) : 'N/A';
    lines.push(`${i + 1}. **${title}** (${year}) ⭐ ${rating}`);
  });
  return lines.join('\n');
}

function sendTelegram(method, payload) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(payload);
    const options = {
      hostname: 'api.telegram.org',
      port: 443,
      path: `/bot${BOT_TOKEN}/${method}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          resolve({});
        }
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
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

  // Intercept Telegram Bot endpoint
  const host = req.headers.host || 'localhost';
  const urlObj = new URL(req.url, `https://${host}`);
  if (urlObj.pathname.startsWith('/api/bot') || urlObj.pathname.startsWith('/api/telegram')) {
    
    // Global state in-memory variables (persists during warm runtime)
    global.autopostChannel = global.autopostChannel || null;
    global.autopostEnabled = global.autopostEnabled !== undefined ? global.autopostEnabled : false;

    // Handle GET Setup Endpoint
    if (req.method === 'GET' && urlObj.searchParams.get('setup') === 'true') {
      const webhookUrl = `https://${host}/api/bot`;
      const registerUrl = `https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=${encodeURIComponent(webhookUrl)}`;
      
      return new Promise((resolve) => {
        https.get(registerUrl, (setupRes) => {
          let body = '';
          setupRes.on('data', chunk => body += chunk);
          setupRes.on('end', () => {
            res.setHeader('Content-Type', 'application/json');
            res.status(200).send(body);
            resolve();
          });
        }).on('error', (err) => {
          res.status(500).send({ error: err.message });
          resolve();
        });
      });
    }

    // Handle Cron Auto-post Endpoint
    if (req.method === 'GET' && urlObj.searchParams.get('cron') === 'true') {
      if (global.autopostEnabled && global.autopostChannel) {
        try {
          const results = await getTrendingMovies();
          if (results && results.length > 0) {
            const movie = results[Math.floor(Math.random() * results.length)];
            const year = movie.release_date ? movie.release_date.substring(0, 4) : 'N/A';
            const rating = movie.vote_average ? movie.vote_average.toFixed(1) : 'N/A';
            const movieGenres = (movie.genre_ids || []).map(id => GENRES[id]).filter(Boolean).slice(0, 3).join(', ') || 'N/A';
            let overview = movie.overview || 'No description available.';
            if (overview.length > 300) {
              overview = overview.substring(0, 297) + '...';
            }
            
            const caption = `🎬 **${movie.title} (${year})**\n⭐ Rating: ${rating}/10\n🎭 Genres: ${movieGenres}\n\n📝 ${overview}`;
            const watch_url = `https://www.movienest.app/movie/${movie.id}`;
            const replyMarkup = {
              inline_keyboard: [
                [
                  { text: '▶️ Watch on MovieNest', url: watch_url }
                ]
              ]
            };
            
            if (movie.poster_path) {
              await sendTelegram('sendPhoto', {
                chat_id: global.autopostChannel,
                photo: `https://image.tmdb.org/t/p/w500${movie.poster_path}`,
                caption: caption,
                parse_mode: 'markdown',
                reply_markup: replyMarkup
              });
            } else {
              await sendTelegram('sendMessage', {
                chat_id: global.autopostChannel,
                text: caption,
                parse_mode: 'markdown',
                reply_markup: replyMarkup
              });
            }
          }
        } catch (e) {
          console.error('Cron autopost error:', e);
        }
      }
      return res.status(200).send('Cron Auto-post Finished');
    }

    // Handle Telegram Webhook Event (POST)
    if (req.method === 'POST') {
      try {
        const rawBody = await new Promise((resolve, reject) => {
          let data = '';
          req.on('data', chunk => data += chunk);
          req.on('end', () => resolve(data));
          req.on('error', reject);
        });
        
        const update = JSON.parse(rawBody);
        if (update && update.message && update.message.text) {
          const chatId = update.message.chat.id;
          const text = update.message.text.trim();
          
          if (text === '/start') {
            await sendTelegram('sendMessage', {
              chat_id: chatId,
              text: `🎬 **Welcome to MovieNest Bot!**\n\nSearch any movie and get a direct link to watch/stream it on MovieNest website.\n\nType /help to see all features!`,
              parse_mode: 'markdown'
            });
          } else if (text === '/help') {
            const helpText = `🎬 **MovieNest Bot Menu**\n\n` +
              `🤖 **Commands:**\n` +
              `• /start - Start the bot\n` +
              `• /help - Show help menu\n` +
              `• /search <movie> - Search movies\n` +
              `• /trending - Show trending movies\n` +
              `• /latest - Latest releases\n` +
              `• /movies - Browse movies\n` +
              `• /anime - Browse anime\n` +
              `• /genres - List genres\n\n` +
              `📢 **Channel Posting:**\n` +
              `• /post @channel Movie Name - Post card to a channel\n` +
              `• /autopost on @channel - Auto-post trending movies every 4 hours\n` +
              `• /autopost off - Disable auto-posting\n` +
              `• /schedule - Show scheduled auto-post status\n\n` +
              `🔍 *Or just type any movie name directly to search!*`;
            await sendTelegram('sendMessage', {
              chat_id: chatId,
              text: helpText,
              parse_mode: 'markdown'
            });
          } else if (text === '/trending') {
            const movies = await getTrendingMovies();
            const msg = formatMovieList(movies, 'Trending Movies This Week');
            await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown' });
          } else if (text === '/latest') {
            const movies = await getNowPlayingMovies();
            const msg = formatMovieList(movies, 'Latest Releases');
            await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown' });
          } else if (text === '/movies') {
            const movies = await getPopularMovies();
            const msg = formatMovieList(movies, 'Popular Movies');
            await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown' });
          } else if (text === '/anime') {
            const movies = await getAnime();
            const msg = formatMovieList(movies, 'Popular Anime Releases');
            await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown' });
          } else if (text === '/genres') {
            const msg = `🎭 **Movie Genres:**\n\n` + Object.entries(GENRES).map(([id, name]) => `• ${name}`).join('\n');
            await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown' });
          } else if (text === '/schedule') {
            await sendTelegram('sendMessage', {
              chat_id: chatId,
              text: `📅 **Auto-Post Schedule Info:**\n\n• **Status:** ${global.autopostEnabled ? '✅ Active' : '❌ Inactive'}\n• **Target Channel:** ${global.autopostChannel || 'None'}\n• **Interval:** Every 4 hours (Vercel Cron Trigger)`,
              parse_mode: 'markdown'
            });
          } else if (text.startsWith('/autopost')) {
            const parts = text.split(' ');
            if (parts.length >= 3 && parts[1] === 'on') {
              global.autopostChannel = parts[2];
              global.autopostEnabled = true;
              await sendTelegram('sendMessage', {
                chat_id: chatId,
                text: `✅ Autopost enabled for channel **${global.autopostChannel}**. Trending movies will be posted every 4 hours.`,
                parse_mode: 'markdown'
              });
            } else if (parts.length >= 2 && parts[1] === 'off') {
              global.autopostEnabled = false;
              await sendTelegram('sendMessage', {
                chat_id: chatId,
                text: `❌ Autopost disabled.`,
                parse_mode: 'markdown'
              });
            } else {
              await sendTelegram('sendMessage', {
                chat_id: chatId,
                text: `💡 Usage:\n• \`/autopost on @channelname\`\n• \`/autopost off\``,
                parse_mode: 'markdown'
              });
            }
          } else if (text.startsWith('/post')) {
            const parts = text.split(' ');
            if (parts.length < 3) {
              await sendTelegram('sendMessage', {
                chat_id: chatId,
                text: '❌ Usage: `/post @channelname Movie Name`',
                parse_mode: 'markdown'
              });
            } else {
              const targetChannel = parts[1];
              const query = parts.slice(2).join(' ');
              const results = await searchTMDB(query);
              if (results.length === 0) {
                await sendTelegram('sendMessage', {
                  chat_id: chatId,
                  text: `❌ No movies found for "${query}" to post to ${targetChannel}.`
                });
              } else {
                const movie = results[0];
                const year = movie.release_date ? movie.release_date.substring(0, 4) : 'N/A';
                const rating = movie.vote_average ? movie.vote_average.toFixed(1) : 'N/A';
                const movieGenres = (movie.genre_ids || []).map(id => GENRES[id]).filter(Boolean).slice(0, 3).join(', ') || 'N/A';
                let overview = movie.overview || 'No description available.';
                if (overview.length > 300) {
                  overview = overview.substring(0, 297) + '...';
                }
                
                const caption = `🎬 **${movie.title} (${year})**\n⭐ Rating: ${rating}/10\n🎭 Genres: ${movieGenres}\n\n📝 ${overview}`;
                const watch_url = `https://www.movienest.app/movie/${movie.id}`;
                const replyMarkup = {
                  inline_keyboard: [
                    [
                      { text: '▶️ Watch on MovieNest', url: watch_url }
                    ]
                  ]
                };
                
                let success = false;
                if (movie.poster_path) {
                  const res = await sendTelegram('sendPhoto', {
                    chat_id: targetChannel,
                    photo: `https://image.tmdb.org/t/p/w500${movie.poster_path}`,
                    caption: caption,
                    parse_mode: 'markdown',
                    reply_markup: replyMarkup
                  });
                  success = res.ok;
                } else {
                  const res = await sendTelegram('sendMessage', {
                    chat_id: targetChannel,
                    text: caption,
                    parse_mode: 'markdown',
                    reply_markup: replyMarkup
                  });
                  success = res.ok;
                }
                
                if (success) {
                  await sendTelegram('sendMessage', {
                    chat_id: chatId,
                    text: `✅ Posted **${movie.title}** to ${targetChannel}!`
                  });
                } else {
                  await sendTelegram('sendMessage', {
                    chat_id: chatId,
                    text: `❌ Failed to post to ${targetChannel}. Make sure the bot is an admin in that channel.`
                  });
                }
              }
            }
          } else {
            // Direct query search (non-command search)
            let query = text;
            if (text.startsWith('/search')) {
              query = text.replace('/search', '').trim();
            }
            if (query.length >= 2) {
              const results = await searchTMDB(query);
              if (results.length === 0) {
                await sendTelegram('sendMessage', {
                  chat_id: chatId,
                  text: `❌ No movies found for "${query}". Try another movie name.`
                });
              } else {
                for (const movie of results.slice(0, 3)) {
                  const year = movie.release_date ? movie.release_date.substring(0, 4) : 'N/A';
                  const rating = movie.vote_average ? movie.vote_average.toFixed(1) : 'N/A';
                  const movieGenres = (movie.genre_ids || []).map(id => GENRES[id]).filter(Boolean).slice(0, 3).join(', ') || 'N/A';
                  let overview = movie.overview || 'No description available.';
                  if (overview.length > 300) {
                    overview = overview.substring(0, 297) + '...';
                  }
                  
                  const caption = `🎬 **${movie.title} (${year})**\n⭐ Rating: ${rating}/10\n🎭 Genres: ${movieGenres}\n\n📝 ${overview}`;
                  const watch_url = `https://www.movienest.app/movie/${movie.id}`;
                  const replyMarkup = {
                    inline_keyboard: [
                      [
                        { text: '▶️ Watch on MovieNest', url: watch_url }
                      ]
                    ]
                  };
                  
                  if (movie.poster_path) {
                    await sendTelegram('sendPhoto', {
                      chat_id: chatId,
                      photo: `https://image.tmdb.org/t/p/w500${movie.poster_path}`,
                      caption: caption,
                      parse_mode: 'markdown',
                      reply_markup: replyMarkup
                    });
                  } else {
                    await sendTelegram('sendMessage', {
                      chat_id: chatId,
                      text: caption,
                      parse_mode: 'markdown',
                      reply_markup: replyMarkup
                    });
                  }
                }
              }
            }
          }
        }
      } catch (err) {
        console.error('Webhook error:', err);
      }
      return res.status(200).send('OK');
    }

    return res.status(200).send('Telegram Bot Webhook Endpoint is Active');
  }

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
