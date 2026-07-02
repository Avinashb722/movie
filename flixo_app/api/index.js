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
  const numberEmojis = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];
  let lines = [
    `🔥 **${header.toUpperCase()}**`,
    `_Top 10 most popular movies right now_`,
    `━━━━━━━━━━━━━━━━━━━━`
  ];
  movies.slice(0, 10).forEach((m, i) => {
    const num = numberEmojis[i] || `${i + 1}.`;
    const title = m.title || 'Unknown';
    const year = m.release_date ? m.release_date.substring(0, 4) : 'N/A';
    const rating = m.vote_average ? m.vote_average.toFixed(1) : 'N/A';
    const movieGenres = (m.genre_ids || []).map(id => GENRES[id]).filter(Boolean).slice(0, 3).join(', ') || 'N/A';
    lines.push(`${num} **${title.toUpperCase()}** (${year})\n⭐️ \`${rating}/10\` | 🎭 _${movieGenres}_\n`);
  });
  lines.push(`━━━━━━━━━━━━━━━━━━━━`);
  return lines.join('\n');
}

function getMovieDetails(tmdbId) {
  return new Promise((resolve) => {
    const apiKey = 'ee88434dff18c194e5b7a1bec83824b8';
    const url = `https://api.themoviedb.org/3/movie/${tmdbId}?api_key=${apiKey}`;
    https.get(url, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (_) {
          resolve(null);
        }
      });
    }).on('error', () => resolve(null));
  });
}

function getSimilarMovies(tmdbId) {
  return new Promise((resolve) => {
    const apiKey = 'ee88434dff18c194e5b7a1bec83824b8';
    const url = `https://api.themoviedb.org/3/movie/${tmdbId}/similar?api_key=${apiKey}`;
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

function getMoviesByLanguage(langCode) {
  return new Promise((resolve) => {
    const apiKey = 'ee88434dff18c194e5b7a1bec83824b8';
    const url = `https://api.themoviedb.org/3/discover/movie?api_key=${apiKey}&with_original_language=${langCode}&sort_by=popularity.desc`;
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

function buildListButtons(movies) {
  const row1 = [];
  const row2 = [];
  const numberEmojis = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];
  movies.slice(0, 10).forEach((m, i) => {
    const btn = { text: numberEmojis[i] || String(i + 1), callback_data: `show:${m.id}` };
    if (i < 5) {
      row1.push(btn);
    } else {
      row2.push(btn);
    }
  });
  return { inline_keyboard: [row1, row2] };
}

function getStars(rating) {
  const starsCount = Math.round(rating);
  let stars = '';
  for (let i = 1; i <= 10; i++) {
    stars += i <= starsCount ? '⭐' : '▪️';
  }
  return stars;
}

function buildMovieCard(movie, details) {
  const title = details ? details.title : movie.title;
  const rating = details ? details.vote_average : movie.vote_average;
  const ratingStars = getStars(rating);
  const year = (details ? details.release_date : movie.release_date || '').substring(0, 4) || 'N/A';
  const genres = details ? details.genres.map(g => g.name).slice(0, 3).join(', ') : (movie.genre_ids || []).map(id => GENRES[id]).filter(Boolean).slice(0, 3).join(', ') || 'N/A';
  const runtime = details && details.runtime ? `${details.runtime} min` : 'N/A';
  let overview = details ? details.overview : movie.overview || 'No description available.';
  if (overview.length > 300) {
    overview = overview.substring(0, 297) + '...';
  }

  return `🎬 **${title.toUpperCase()} (${year})**\n` +
         `━━━━━━━━━━━━━━━━━━━━\n` +
         `⭐️ **Rating:**  \`${rating.toFixed(1)}/10\`  (${ratingStars})\n` +
         `🎭 **Genres:**  \`${genres}\`\n` +
         `⏱️ **Runtime:** \`${runtime}\`\n` +
         `━━━━━━━━━━━━━━━━━━━━\n` +
         `📝 *${overview}*`;
}

function slugify(title) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-');
}

function buildButtons(movie, query, index, totalResults, similarId = null) {
  const watch_url = `https://www.movienest.app/movie/${slugify(movie.title)}`;
  const inline_keyboard = [
    [
      { text: '▶️ Watch on MovieNest', url: watch_url }
    ],
    [
      { text: '❓ How to Watch', callback_data: 'info:watch' },
      { text: '❓ How to Download', callback_data: 'info:download' }
    ]
  ];

  // Add similar movies option
  if (!similarId) {
    inline_keyboard.push([
      { text: '🎬 Find Similar Movies', callback_data: `s:${movie.id}` }
    ]);
  }

  // Add pagination row
  const paginationRow = [];
  const safeQuery = query.substring(0, 30);
  if (similarId) {
    if (index > 0) {
      paginationRow.push({ text: '◀️ Prev', callback_data: `ps:${similarId}:${index - 1}` });
    }
    paginationRow.push({ text: `Page ${index + 1}/${totalResults}`, callback_data: 'noop' });
    if (index < totalResults - 1) {
      paginationRow.push({ text: 'Next ▶️', callback_data: `ps:${similarId}:${index + 1}` });
    }
  } else {
    if (index > 0) {
      paginationRow.push({ text: '◀️ Prev', callback_data: `p:${safeQuery}:${index - 1}` });
    }
    paginationRow.push({ text: `${index + 1}/${totalResults}`, callback_data: 'noop' });
    if (index < totalResults - 1) {
      paginationRow.push({ text: 'Next ▶️', callback_data: `p:${safeQuery}:${index + 1}` });
    }
  }
  
  if (paginationRow.length > 0) {
    inline_keyboard.push(paginationRow);
  }

  return { inline_keyboard };
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
      
      const commands = [
        { command: 'start', description: 'Start the bot' },
        { command: 'help', description: 'Show help menu' },
        { command: 'search', description: 'Search any movie' },
        { command: 'trending', description: 'Trending movies this week' },
        { command: 'latest', description: 'Latest releases' },
        { command: 'movies', description: 'Browse popular movies' },
        { command: 'anime', description: 'Browse anime' },
        { command: 'genres', description: 'List all genres' },
        { command: 'schedule', description: 'Show auto-post schedule' },
        { command: 'status', description: 'Check bot status' }
      ];

      return new Promise((resolve) => {
        https.get(registerUrl, (setupRes) => {
          let body = '';
          setupRes.on('data', chunk => body += chunk);
          setupRes.on('end', () => {
            sendTelegram('setMyCommands', { commands }).then(() => {
              res.setHeader('Content-Type', 'application/json');
              res.status(200).send(body);
              resolve();
            }).catch(() => {
              res.setHeader('Content-Type', 'application/json');
              res.status(200).send(body);
              resolve();
            });
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
            const watch_url = `https://www.movienest.app/movie/${slugify(movie.title)}`;
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

        // 1. Handle Inline Query Updates
        if (update && update.inline_query) {
          const inlineQueryId = update.inline_query.id;
          const query = update.inline_query.query.trim();
          if (query.length >= 2) {
            const results = await searchTMDB(query);
            const inlineResults = results.slice(0, 5).map(movie => {
              const year = movie.release_date ? movie.release_date.substring(0, 4) : 'N/A';
              const rating = movie.vote_average ? movie.vote_average.toFixed(1) : 'N/A';
              const caption = buildMovieCard(movie, null);
              const watch_url = `https://www.movienest.app/movie/${slugify(movie.title)}`;
              
              return {
                type: 'article',
                id: String(movie.id),
                title: `${movie.title} (${year})`,
                description: `Rating: ${rating} | ${movie.overview || ''}`,
                thumb_url: movie.poster_path ? `https://image.tmdb.org/t/p/w92${movie.poster_path}` : undefined,
                input_message_content: {
                  message_text: caption,
                  parse_mode: 'markdown'
                },
                reply_markup: {
                  inline_keyboard: [
                    [
                      { text: '▶️ Watch on MovieNest', url: watch_url }
                    ]
                  ]
                }
              };
            });

            await sendTelegram('answerInlineQuery', {
              inline_query_id: inlineQueryId,
              results: inlineResults,
              cache_time: 300
            });
          }
          return res.status(200).send('OK');
        }

        // 2. Handle Callback Query Updates (Pagination, Similar Movies, Languages, List Clicks)
        if (update && update.callback_query) {
          const callbackQueryId = update.callback_query.id;
          const callbackData = update.callback_query.data;
          const message = update.callback_query.message;
          const chatId = message.chat.id;
          const messageId = message.message_id;

          if (callbackData === 'noop') {
            await sendTelegram('answerCallbackQuery', { callback_query_id: callbackQueryId });
            return res.status(200).send('OK');
          }

          const parts = callbackData.split(':');
          const action = parts[0];

          // Action "show" -> Get movie details and display full premium card (can edit or send new)
          if (action === 'show') {
            const tmdbId = parts[1];
            const details = await getMovieDetails(tmdbId);
            if (details) {
              const caption = buildMovieCard(null, details);
              const replyMarkup = buildButtons(details, '', 0, 1);
              
              if (details.poster_path) {
                // If message has a photo, edit media, otherwise send new photo
                const hasPhoto = !!(message.photo || message.document);
                if (hasPhoto) {
                  await sendTelegram('editMessageMedia', {
                    chat_id: chatId,
                    message_id: messageId,
                    media: {
                      type: 'photo',
                      media: `https://image.tmdb.org/t/p/w500${details.poster_path}`,
                      caption: caption,
                      parse_mode: 'markdown'
                    },
                    reply_markup: replyMarkup
                  });
                } else {
                  await sendTelegram('sendPhoto', {
                    chat_id: chatId,
                    photo: `https://image.tmdb.org/t/p/w500${details.poster_path}`,
                    caption: caption,
                    parse_mode: 'markdown',
                    reply_markup: replyMarkup
                  });
                }
              } else {
                await sendTelegram('editMessageText', {
                  chat_id: chatId,
                  message_id: messageId,
                  text: caption,
                  parse_mode: 'markdown',
                  reply_markup: replyMarkup
                });
              }
            }
          }

          // Action "info" -> Show details popups on how to watch/download
          if (action === 'info') {
            const topic = parts[1];
            let infoText = '';
            if (topic === 'watch') {
              infoText = '📺 **How to Watch on MovieNest:**\n\n' +
                         '1️⃣ Tap the **"▶️ Watch on MovieNest"** button on the card.\n' +
                         '2️⃣ The movie link will open in your browser or automatically launch your **MovieNest Mobile App** if installed.\n' +
                         '3️⃣ Press the **Play** button on the streaming player to start watching instantly!';
            } else if (topic === 'download') {
              infoText = '📥 **How to Download MovieNest App:**\n\n' +
                         '• 📱 **Android Mobile**: Open [movienest.app](https://www.movienest.app) on your phone browser and tap the **"Download Android App"** banner at the top.\n' +
                         '• 💻 **Windows Desktop**: Open [movienest.app](https://www.movienest.app) on your computer and tap the **"Download Windows App"** installer button.';
            }
            // Stop loading spinner immediately
            await sendTelegram('answerCallbackQuery', { callback_query_id: callbackQueryId });
            // Send instructions as a message
            await sendTelegram('sendMessage', {
              chat_id: chatId,
              text: infoText,
              parse_mode: 'markdown',
              disable_web_page_preview: true
            });
            return res.status(200).send('OK');
          }

          // Action "lang" -> Browse movies by language code
          if (action === 'lang') {
            const langCode = parts[1];
            const results = await getMoviesByLanguage(langCode);
            if (results && results.length > 0) {
              const langNames = { hi: 'Hindi', en: 'English', te: 'Telugu', ta: 'Tamil', ml: 'Malayalam', ko: 'Korean', ja: 'Japanese', es: 'Spanish' };
              const caption = formatMovieList(results, `${langNames[langCode] || langCode} Releases`);
              const replyMarkup = buildListButtons(results);
              
              const hasPhoto = !!(message.photo || message.document);
              if (hasPhoto && results[0].poster_path) {
                await sendTelegram('editMessageMedia', {
                  chat_id: chatId,
                  message_id: messageId,
                  media: {
                    type: 'photo',
                    media: `https://image.tmdb.org/t/p/w500${results[0].poster_path}`,
                    caption: caption,
                    parse_mode: 'markdown'
                  },
                  reply_markup: replyMarkup
                });
              } else {
                if (results[0].poster_path) {
                  await sendTelegram('sendPhoto', {
                    chat_id: chatId,
                    photo: `https://image.tmdb.org/t/p/w500${results[0].poster_path}`,
                    caption: caption,
                    parse_mode: 'markdown',
                    reply_markup: replyMarkup
                  });
                } else {
                  await sendTelegram('editMessageText', {
                    chat_id: chatId,
                    message_id: messageId,
                    text: caption,
                    parse_mode: 'markdown',
                    reply_markup: replyMarkup
                  });
                }
              }
            }
          }

          // Action "menu" -> Quick menu routing
          if (action === 'menu') {
            const route = parts[1];
            if (route === 'trending') {
              const results = await getTrendingMovies();
              if (results && results.length > 0) {
                const caption = formatMovieList(results, 'Trending Movies This Week');
                const replyMarkup = buildListButtons(results);
                if (results[0].poster_path) {
                  await sendTelegram('sendPhoto', {
                    chat_id: chatId,
                    photo: `https://image.tmdb.org/t/p/w500${results[0].poster_path}`,
                    caption: caption,
                    parse_mode: 'markdown',
                    reply_markup: replyMarkup
                  });
                } else {
                  await sendTelegram('sendMessage', { chat_id: chatId, text: caption, parse_mode: 'markdown', reply_markup: replyMarkup });
                }
              }
            } else if (route === 'latest') {
              const results = await getNowPlayingMovies();
              if (results && results.length > 0) {
                const caption = formatMovieList(results, 'Latest Releases');
                const replyMarkup = buildListButtons(results);
                if (results[0].poster_path) {
                  await sendTelegram('sendPhoto', {
                    chat_id: chatId,
                    photo: `https://image.tmdb.org/t/p/w500${results[0].poster_path}`,
                    caption: caption,
                    parse_mode: 'markdown',
                    reply_markup: replyMarkup
                  });
                } else {
                  await sendTelegram('sendMessage', { chat_id: chatId, text: caption, parse_mode: 'markdown', reply_markup: replyMarkup });
                }
              }
            } else if (route === 'languages') {
              const languagesMenu = {
                inline_keyboard: [
                  [ { text: '🇮🇳 Hindi', callback_data: 'lang:hi' }, { text: '🇺🇸 English', callback_data: 'lang:en' } ],
                  [ { text: '🇮🇳 Telugu', callback_data: 'lang:te' }, { text: '🇮🇳 Tamil', callback_data: 'lang:ta' } ],
                  [ { text: '🇮🇳 Malayalam', callback_data: 'lang:ml' }, { text: '🇰🇷 Korean', callback_data: 'lang:ko' } ],
                  [ { text: '🇯🇵 Japanese', callback_data: 'lang:ja' }, { text: '🇪🇸 Spanish', callback_data: 'lang:es' } ]
                ]
              };
              await sendTelegram('sendMessage', {
                chat_id: chatId,
                text: '🌐 **Select Language to Browse Movies:**',
                parse_mode: 'markdown',
                reply_markup: languagesMenu
              });
            } else if (route === 'genres') {
              const msg = `🎭 **Movie Genres:**\n\n` + Object.entries(GENRES).map(([id, name]) => `• ${name}`).join('\n');
              await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown' });
            }
          }

          // Action "p" -> Standard search pagination
          if (action === 'p') {
            const query = parts[1];
            const index = parseInt(parts[2], 10);
            const results = await searchTMDB(query);
            if (results && results[index]) {
              const movie = results[index];
              const details = await getMovieDetails(movie.id);
              const caption = buildMovieCard(movie, details);
              const replyMarkup = buildButtons(movie, query, index, results.length);
              
              const hasPhoto = !!(message.photo || message.document);
              if (hasPhoto && movie.poster_path) {
                await sendTelegram('editMessageMedia', {
                  chat_id: chatId,
                  message_id: messageId,
                  media: {
                    type: 'photo',
                    media: `https://image.tmdb.org/t/p/w500${movie.poster_path}`,
                    caption: caption,
                    parse_mode: 'markdown'
                  },
                  reply_markup: replyMarkup
                });
              } else {
                await sendTelegram('editMessageText', {
                  chat_id: chatId,
                  message_id: messageId,
                  text: caption,
                  parse_mode: 'markdown',
                  reply_markup: replyMarkup
                });
              }
            }
          }

          // Action "s" -> Find Similar Movies trigger
          if (action === 's') {
            const tmdbId = parts[1];
            const results = await getSimilarMovies(tmdbId);
            if (results && results.length > 0) {
              const movie = results[0];
              const details = await getMovieDetails(movie.id);
              const caption = `🎬 **SIMILAR RECOMMENDATION**\n\n` + buildMovieCard(movie, details);
              const replyMarkup = buildButtons(movie, '', 0, results.length, tmdbId);
              
              const hasPhoto = !!(message.photo || message.document);
              if (hasPhoto && movie.poster_path) {
                await sendTelegram('editMessageMedia', {
                  chat_id: chatId,
                  message_id: messageId,
                  media: {
                    type: 'photo',
                    media: `https://image.tmdb.org/t/p/w500${movie.poster_path}`,
                    caption: caption,
                    parse_mode: 'markdown'
                  },
                  reply_markup: replyMarkup
                });
              } else {
                await sendTelegram('editMessageText', {
                  chat_id: chatId,
                  message_id: messageId,
                  text: caption,
                  parse_mode: 'markdown',
                  reply_markup: replyMarkup
                });
              }
            } else {
              await sendTelegram('answerCallbackQuery', {
                callback_query_id: callbackQueryId,
                text: '❌ No similar movies found for this title.',
                show_alert: true
              });
            }
          }

          // Action "ps" -> Similar movies pagination
          if (action === 'ps') {
            const tmdbId = parts[1];
            const index = parseInt(parts[2], 10);
            const results = await getSimilarMovies(tmdbId);
            if (results && results[index]) {
              const movie = results[index];
              const details = await getMovieDetails(movie.id);
              const caption = `🎬 **SIMILAR RECOMMENDATION**\n\n` + buildMovieCard(movie, details);
              const replyMarkup = buildButtons(movie, '', index, results.length, tmdbId);
              
              const hasPhoto = !!(message.photo || message.document);
              if (hasPhoto && movie.poster_path) {
                await sendTelegram('editMessageMedia', {
                  chat_id: chatId,
                  message_id: messageId,
                  media: {
                    type: 'photo',
                    media: `https://image.tmdb.org/t/p/w500${movie.poster_path}`,
                    caption: caption,
                    parse_mode: 'markdown'
                  },
                  reply_markup: replyMarkup
                });
              } else {
                await sendTelegram('editMessageText', {
                  chat_id: chatId,
                  message_id: messageId,
                  text: caption,
                  parse_mode: 'markdown',
                  reply_markup: replyMarkup
                });
              }
            }
          }

          await sendTelegram('answerCallbackQuery', { callback_query_id: callbackQueryId });
          return res.status(200).send('OK');
        }

        // 3. Handle Chat Message Updates (POST)
        if (update && update.message && update.message.text) {
          const chatId = update.message.chat.id;
          const text = update.message.text.trim();
          
          const startKeyboard = {
            inline_keyboard: [
              [
                { text: '🔥 Trending', callback_data: 'menu:trending' },
                { text: '🆕 Latest', callback_data: 'menu:latest' }
              ],
              [
                { text: '🌐 Languages', callback_data: 'menu:languages' },
                { text: '🎭 Genres', callback_data: 'menu:genres' }
              ],
              [
                { text: '🚀 Watch on MovieNest', url: 'https://www.movienest.app' }
              ]
            ]
          };

          if (text === '/start') {
            await sendTelegram('sendMessage', {
              chat_id: chatId,
              text: `🎬 **Welcome to MovieNest Premium!**\n\nSearch any movie instantly or explore using the quick dashboard options below:`,
              parse_mode: 'markdown',
              reply_markup: startKeyboard
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
              `• /autopost on @channel - Auto-post trending movies daily\n` +
              `• /autopost off - Disable auto-posting\n` +
              `• /schedule - Show scheduled auto-post status\n\n` +
              `🔍 *Or just type any movie name directly to search!*`;
            await sendTelegram('sendMessage', {
              chat_id: chatId,
              text: helpText,
              parse_mode: 'markdown',
              reply_markup: startKeyboard
            });
          } else if (text === '/trending') {
            const movies = await getTrendingMovies();
            if (movies && movies.length > 0) {
              const msg = formatMovieList(movies, 'Trending Movies This Week');
              const replyMarkup = buildListButtons(movies);
              if (movies[0].poster_path) {
                await sendTelegram('sendPhoto', {
                  chat_id: chatId,
                  photo: `https://image.tmdb.org/t/p/w500${movies[0].poster_path}`,
                  caption: msg,
                  parse_mode: 'markdown',
                  reply_markup: replyMarkup
                });
              } else {
                await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown', reply_markup: replyMarkup });
              }
            }
          } else if (text === '/latest') {
            const movies = await getNowPlayingMovies();
            if (movies && movies.length > 0) {
              const msg = formatMovieList(movies, 'Latest Releases');
              const replyMarkup = buildListButtons(movies);
              if (movies[0].poster_path) {
                await sendTelegram('sendPhoto', {
                  chat_id: chatId,
                  photo: `https://image.tmdb.org/t/p/w500${movies[0].poster_path}`,
                  caption: msg,
                  parse_mode: 'markdown',
                  reply_markup: replyMarkup
                });
              } else {
                await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown', reply_markup: replyMarkup });
              }
            }
          } else if (text === '/movies') {
            const movies = await getPopularMovies();
            if (movies && movies.length > 0) {
              const msg = formatMovieList(movies, 'Popular Movies');
              const replyMarkup = buildListButtons(movies);
              if (movies[0].poster_path) {
                await sendTelegram('sendPhoto', {
                  chat_id: chatId,
                  photo: `https://image.tmdb.org/t/p/w500${movies[0].poster_path}`,
                  caption: msg,
                  parse_mode: 'markdown',
                  reply_markup: replyMarkup
                });
              } else {
                await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown', reply_markup: replyMarkup });
              }
            }
          } else if (text === '/anime') {
            const movies = await getAnime();
            if (movies && movies.length > 0) {
              const msg = formatMovieList(movies, 'Popular Anime Releases');
              const replyMarkup = buildListButtons(movies);
              if (movies[0].poster_path) {
                await sendTelegram('sendPhoto', {
                  chat_id: chatId,
                  photo: `https://image.tmdb.org/t/p/w500${movies[0].poster_path}`,
                  caption: msg,
                  parse_mode: 'markdown',
                  reply_markup: replyMarkup
                });
              } else {
                await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown', reply_markup: replyMarkup });
              }
            }
          } else if (text === '/genres') {
            const msg = `🎭 **Movie Genres:**\n\n` + Object.entries(GENRES).map(([id, name]) => `• ${name}`).join('\n');
            await sendTelegram('sendMessage', { chat_id: chatId, text: msg, parse_mode: 'markdown' });
          } else if (text === '/schedule') {
            await sendTelegram('sendMessage', {
              chat_id: chatId,
              text: `📅 **Auto-Post Schedule Info:**\n\n• **Status:** ${global.autopostEnabled ? '✅ Active' : '❌ Inactive'}\n• **Target Channel:** ${global.autopostChannel || 'None'}\n• **Interval:** Daily (Vercel Cron Trigger)`,
              parse_mode: 'markdown'
            });
          } else if (text.startsWith('/autopost')) {
            const parts = text.split(' ');
            if (parts.length >= 3 && parts[1] === 'on') {
              global.autopostChannel = parts[2];
              global.autopostEnabled = true;
              await sendTelegram('sendMessage', {
                chat_id: chatId,
                text: `✅ Autopost enabled for channel **${global.autopostChannel}**. Trending movies will be posted daily.`,
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
                const details = await getMovieDetails(movie.id);
                const caption = buildMovieCard(movie, details);
                const replyMarkup = {
                  inline_keyboard: [
                    [
                      { text: '▶️ Watch on MovieNest', url: `https://www.movienest.app/movie/${slugify(movie.title)}` }
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
                // Send first search result with pagination buttons
                const movie = results[0];
                const details = await getMovieDetails(movie.id);
                const caption = buildMovieCard(movie, details);
                const replyMarkup = buildButtons(movie, query, 0, results.length);
                
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
