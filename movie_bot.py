import os
import json
import sqlite3
import socket
import threading
import urllib.request
import urllib.parse
import re
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from telethon import TelegramClient, events

# ===================================================
# CONFIGURATION
# ===================================================
API_ID = 23376030           # Your Telegram API ID
API_HASH = '016a776a93f5e68c42c0c5622a1b098a' # Your Telegram API Hash

# Your active bot token
BOT_TOKEN = '8685589784:AAGjCgABnDcKRn9LkG9vB3TszSfVq_6KS9A' 

DB_FILE = 'movies_database.db'
WEB_SERVER_PORT = 8080

# TMDB API (The Movie Database) - Free API for all movies in all languages
# Get yours free at: https://www.themoviedb.org/settings/api
TMDB_API_KEY = 'ee88434dff18c194e5b7a1bec83824b8'
TMDB_BASE   = 'https://api.themoviedb.org/3'
TMDB_IMG    = 'https://image.tmdb.org/t/p/w500'

# ===================================================
# DYNAMIC LOCAL IP RETRIEVAL
# ===================================================
def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

LOCAL_IP = get_local_ip()

# ===================================================
# DATABASE SETUP
# ===================================================
def init_db():
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS movies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            link TEXT NOT NULL
        )
    ''')
    conn.commit()
    conn.close()

init_db()

# ===================================================
# LOCAL EMBED WEB SERVER
# ===================================================
class EmbedHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_GET(self):
        if self.path.startswith('/watch/'):
            imdb_id = self.path.split('/')[-1]
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            html = f"""<!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Direct Movie Stream</title>
                <style>
                    body, html {{ margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #000; }}
                    iframe {{ border: none; width: 100%; height: 100%; }}
                </style>
            </head>
            <body>
                <iframe src="https://www.2embed.cc/embed/{imdb_id}" allowfullscreen></iframe>
            </body>
            </html>"""
            self.wfile.write(html.encode('utf-8'))
        elif self.path == '/webtorrent.min.js':
            local_path = r"C:\Users\Hp\Desktop\earnko\webtorrent-master\dist\webtorrent.min.js"
            if os.path.exists(local_path):
                self.send_response(200)
                self.send_header('Content-type', 'application/javascript')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                with open(local_path, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"webtorrent.min.js not found locally")
        elif self.path == '/sw.min.js':
            local_path = r"C:\Users\Hp\Desktop\earnko\webtorrent-master\dist\sw.min.js"
            if os.path.exists(local_path):
                self.send_response(200)
                self.send_header('Content-type', 'application/javascript')
                self.send_header('Service-Worker-Allowed', '/')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                with open(local_path, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"sw.min.js not found locally")
        elif self.path.startswith('/play_torrent'):
            parsed_url = urllib.parse.urlparse(self.path)
            query_params = urllib.parse.parse_qs(parsed_url.query)
            magnet = query_params.get('magnet', [''])[0]
            title = query_params.get('title', ['Torrent Stream'])[0]
            
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} - Torrent Stream</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&display=swap" rel="stylesheet">
    <style>
        :root {{
            --bg-color: #090d16;
            --container-bg: rgba(20, 24, 38, 0.7);
            --primary-color: #3b82f6;
            --primary-hover: #2563eb;
            --accent-color: #8b5cf6;
            --text-color: #f3f4f6;
            --text-muted: #9ca3af;
            --border-color: rgba(255, 255, 255, 0.08);
            --progress-color: #10b981;
        }}

        * {{ box-sizing: border-box; margin: 0; padding: 0; }}

        body {{
            font-family: 'Outfit', sans-serif;
            background: radial-gradient(circle at top, #1e1b4b 0%, #030712 100%);
            color: var(--text-color);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 20px;
        }}

        .wrapper {{ width: 100%; max-width: 1100px; display: flex; flex-direction: column; gap: 24px; }}

        header {{ display: flex; flex-direction: column; gap: 8px; text-align: center; }}

        .badge-container {{ display: flex; justify-content: center; gap: 8px; margin-top: 8px; }}

        .badge {{
            background: linear-gradient(135deg, var(--primary-color) 0%, var(--accent-color) 100%);
            padding: 4px 12px;
            border-radius: 9999px;
            font-size: 0.85rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
        }}

        .badge.size {{ background: rgba(255, 255, 255, 0.1); border: 1px solid var(--border-color); box-shadow: none; }}

        h1 {{
            font-size: 2.2rem;
            font-weight: 800;
            letter-spacing: -0.02em;
            background: linear-gradient(to right, #ffffff, #d1d5db);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }}

        .tabs {{ display: flex; justify-content: center; gap: 12px; margin-bottom: 8px; }}

        .tab-btn {{
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--border-color);
            color: var(--text-muted);
            padding: 10px 20px;
            border-radius: 12px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
        }}

        .tab-btn.active {{
            background: linear-gradient(135deg, var(--primary-color) 0%, var(--accent-color) 100%);
            color: #ffffff;
            border: none;
            box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
        }}

        .player-container {{
            background: var(--container-bg);
            backdrop-filter: blur(16px);
            border: 1px solid var(--border-color);
            border-radius: 20px;
            overflow: hidden;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
            aspect-ratio: 16/9;
            width: 100%;
            position: relative;
            animation: scaleIn 0.6s cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .player-loader {{
            position: absolute;
            top: 0; left: 0; width: 100%; height: 100%;
            display: flex; flex-direction: column; align-items: center; justify-content: center;
            background: #090d16; z-index: 10; transition: opacity 0.5s ease;
        }}

        .spinner {{
            width: 50px; height: 50px;
            border: 3px solid rgba(255, 255, 255, 0.1);
            border-radius: 50%;
            border-top-color: var(--primary-color);
            animation: spin 1s ease-in-out infinite;
            margin-bottom: 16px;
        }}

        .player-view {{ display: none; width: 100%; height: 100%; }}
        .player-view.active {{ display: block; }}
        #webtor-player, #webtorrent-player-target {{ width: 100%; height: 100%; }}
        #webtorrent-player-target video {{ width: 100%; height: 100%; object-fit: contain; }}

        .progress-bar-container {{ width: 100%; height: 6px; background: rgba(255, 255, 255, 0.1); position: relative; border-radius: 3px; overflow: hidden; display: none; }}
        .progress-bar-fill {{ height: 100%; width: 0%; background: linear-gradient(to right, var(--primary-color), var(--progress-color)); transition: width 0.3s ease; }}

        .dashboard {{ display: none; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; animation: fadeInUp 0.8s ease-out; }}
        .stat-card {{ background: var(--container-bg); border: 1px solid var(--border-color); border-radius: 16px; padding: 16px; display: flex; flex-direction: column; gap: 8px; }}
        .stat-card .label {{ font-size: 0.85rem; text-transform: uppercase; color: var(--text-muted); }}
        .stat-card .value {{ font-size: 1.5rem; font-weight: 700; color: #ffffff; }}

        .controls-info {{ display: grid; grid-template-columns: 1fr; gap: 16px; animation: fadeInUp 0.8s ease-out; }}
        @media (min-width: 768px) {{ .controls-info {{ grid-template-columns: 2fr 1fr; }} }}

        .card {{ background: var(--container-bg); border: 1px solid var(--border-color); border-radius: 16px; padding: 20px; display: flex; flex-direction: column; gap: 12px; }}
        .card h2 {{ font-size: 1.25rem; font-weight: 600; color: #ffffff; border-bottom: 1px solid var(--border-color); padding-bottom: 8px; }}
        .card p {{ font-size: 0.95rem; color: var(--text-muted); line-height: 1.5; }}

        .btn {{
            display: inline-flex; align-items: center; justify-content: center; gap: 8px;
            background: linear-gradient(135deg, var(--primary-color) 0%, var(--accent-color) 100%);
            color: #ffffff; border: none; padding: 12px 24px; border-radius: 10px; font-weight: 600; cursor: pointer; text-decoration: none; transition: all 0.3s ease;
            box-shadow: 0 4px 14px rgba(59, 130, 246, 0.4); font-size: 0.95rem;
        }}
        .btn:hover {{ transform: translateY(-2px); box-shadow: 0 6px 20px rgba(59, 130, 246, 0.6); }}
        .btn-outline {{ background: transparent; border: 1px solid var(--primary-color); color: var(--text-color); box-shadow: none; }}
        
        .magnet-box {{
            background: rgba(0, 0, 0, 0.3); border: 1px solid var(--border-color); border-radius: 8px; padding: 12px;
            font-family: monospace; font-size: 0.85rem; word-break: break-all; max-height: 80px; overflow-y: auto; color: var(--text-muted);
        }}

        @keyframes spin {{ to {{ transform: rotate(360deg); }} }}
        @keyframes fadeInDown {{ from {{ opacity: 0; transform: translateY(-20px); }} to {{ opacity: 1; transform: translateY(0); }} }}
        @keyframes fadeInUp {{ from {{ opacity: 0; transform: translateY(20px); }} to {{ opacity: 1; transform: translateY(0); }} }}
        @keyframes scaleIn {{ from {{ opacity: 0; transform: scale(0.95); }} to {{ opacity: 1; transform: scale(1); }} }}
    </style>
</head>
<body>
    <div class="wrapper">
        <header>
            <h1 id="title-text">{title}</h1>
            <div class="badge-container">
                <span class="badge" id="player-badge">Cloud Stream</span>
                <span class="badge size" id="size-badge">HD Quality</span>
            </div>
        </header>

        <div class="tabs">
            <button class="tab-btn active" id="tab-webtor" onclick="switchPlayer('webtor')">☁️ Cloud Stream</button>
            <button class="tab-btn" id="tab-webtorrent" onclick="switchPlayer('webtorrent')">⚡ P2P WebTorrent</button>
        </div>

        <div class="player-container">
            <div class="player-loader" id="loader">
                <div class="spinner"></div>
                <p id="loader-status" style="color: var(--text-muted); font-weight: 500;">Loading player components...</p>
            </div>
            <div class="player-view active" id="view-webtor"><div id="webtor-player"></div></div>
            <div class="player-view" id="view-webtorrent"><div id="webtorrent-player-target"></div></div>
        </div>

        <div class="progress-bar-container" id="webtorrent-progress-bar"><div class="progress-bar-fill" id="progress-fill"></div></div>
        <div class="dashboard" id="webtorrent-dashboard">
            <div class="stat-card"><div class="label">P2P Progress</div><div class="value" id="stat-progress">0%</div></div>
            <div class="stat-card"><div class="label">Download Speed</div><div class="value" id="stat-down-speed">0 B/s</div></div>
            <div class="stat-card"><div class="label">Connected Peers</div><div class="value" id="stat-peers">0 peers</div></div>
        </div>

        <div class="card" id="file-list-card" style="display: none;">
            <h2>Files in Torrent</h2>
            <div id="torrent-file-list" style="display: flex; flex-direction: column; gap: 8px; margin-top: 12px;"></div>
        </div>

        <div class="controls-info">
            <div class="card" id="instructions-card">
                <h2>Cloud Stream (Webtor.io)</h2>
                <p>💡 <strong>Why use this?</strong> Standard movies are seeded by UDP/TCP desktop clients. Web browsers cannot connect to them directly. Webtor resolves standard peers on the server and streams the video directly to your Chrome browser in full HD.</p>
            </div>
            <div class="card" style="justify-content: space-between;">
                <div>
                    <h2>Magnet Link</h2>
                    <div class="magnet-box" id="magnet-text">{magnet}</div>
                </div>
                <button class="btn btn-outline" style="width: 100%; margin-top: 12px;" onclick="copyMagnet()">📋 Copy Magnet Link</button>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/@webtor/embed-sdk-js/dist/index.min.js" charset="utf-8" async></script>
    <script src="/webtorrent.min.js"></script>
    <script>
        const magnetURI = '{magnet}';
        let webtorrentClient = null;
        let activePlayer = 'webtor';

        const isDirect = magnetURI.startsWith('http://') || magnetURI.startsWith('https://');

        if (isDirect) {{
            document.querySelectorAll('.tabs').forEach(el => el.style.display = 'none');
            document.getElementById('player-badge').innerText = 'Direct Play';
            document.getElementById('size-badge').innerText = 'Direct Link';
            document.getElementById('instructions-card').innerHTML = '<h2>Direct Video Stream</h2><p>🚀 <strong>Direct Playback:</strong> This movie is loaded directly from a web server and streams instantly in full quality.</p>';
            document.getElementById('view-webtor').innerHTML = `<video src="${{magnetURI}}" controls autoplay style="width:100%; height:100%; object-fit:contain;"></video>`;
            setTimeout(hideLoader, 1000);
        }} else {{
            try {{
                const urlParams = new URLSearchParams(magnetURI.substring(magnetURI.indexOf('?')));
                const dn = urlParams.get('dn') || '';
                const sizeMatch = dn.match(/(\\d+\\.\\d+\\s*(?:GB|MB|gb|mb))/);
                if (sizeMatch) document.getElementById('size-badge').innerText = sizeMatch[1];
            }} catch (e) {{}}

            window.webtor = window.webtor || [];
            window.webtor.push({{
                id: 'webtor-player',
                magnet: magnetURI,
                width: '100%',
                height: '100%',
                on: function(e) {{ if (e.name == 'ready' && activePlayer === 'webtor') hideLoader(); }}
            }});
        }}

        function switchPlayer(type) {{
            if (type === activePlayer) return;
            activePlayer = type;
            showLoader('Switching player...');
            document.querySelectorAll('.tab-btn, .player-view').forEach(el => el.classList.remove('active'));
            document.getElementById('webtorrent-progress-bar').style.display = type === 'webtorrent' ? 'block' : 'none';
            document.getElementById('webtorrent-dashboard').style.display = type === 'webtorrent' ? 'grid' : 'none';

            if (webtorrentClient) {{ try {{ webtorrentClient.destroy(); }} catch(e) {{}} webtorrentClient = null; document.getElementById('webtorrent-player-target').innerHTML = ''; }}

            if (type === 'webtor') {{
                document.getElementById('tab-webtor').classList.add('active');
                document.getElementById('view-webtor').classList.add('active');
                document.getElementById('player-badge').innerText = 'Cloud Stream';
                setTimeout(hideLoader, 2000);
            }} else {{
                document.getElementById('tab-webtorrent').classList.add('active');
                document.getElementById('view-webtorrent').classList.add('active');
                document.getElementById('player-badge').innerText = 'P2P WebTorrent';
                initWebTorrent();
            }}
        }}

        function initWebTorrent() {{
            showLoader('Activating Service Worker...');
            
            navigator.serviceWorker.register('/sw.min.js', {{ scope: '/' }}).then(reg => {{
                const worker = reg.active || reg.waiting || reg.installing;
                
                function checkState(w) {{
                    if (w && w.state === 'activated') {{
                        startWebTorrentDownload(reg);
                        return true;
                    }}
                    return false;
                }}
                
                if (!checkState(worker)) {{
                    worker.addEventListener('statechange', ({{ target }}) => {{
                        checkState(target);
                    }});
                }}
            }}).catch(err => {{
                console.error('Service Worker registration failed:', err);
                startWebTorrentDownload(null);
            }});
        }}

        function startWebTorrentDownload(reg) {{
            showLoader('Connecting to WebRTC peers...');
            webtorrentClient = new WebTorrent();
            
            if (reg) {{
                try {{
                    webtorrentClient.createServer({{ controller: reg }});
                }} catch(e) {{
                    console.error('Failed to create local WebTorrent server:', e);
                }}
            }}
            
            webtorrentClient.add(magnetURI, {{ 
                announce: ['wss://tracker.openwebtorrent.com', 'wss://tracker.webtorrent.dev', 'wss://tracker.btorrent.xyz:443'] 
            }}, function (torrent) {{
                console.log('Torrent added successfully');
                
                torrent.on('wire', () => {{
                    console.log('Peer connected');
                }});

                setInterval(() => {{
                    console.log('Peers:', torrent.numPeers);
                }}, 3000);

                const fileListCard = document.getElementById('file-list-card');
                const fileListContainer = document.getElementById('torrent-file-list');
                fileListContainer.innerHTML = '';
                
                torrent.files.forEach(f => {{
                    console.log('File found:', f.name);
                    
                    const row = document.createElement('div');
                    row.style.display = 'flex';
                    row.style.justifyContent = 'space-between';
                    row.style.alignItems = 'center';
                    row.style.padding = '10px 14px';
                    row.style.background = 'rgba(255, 255, 255, 0.02)';
                    row.style.borderRadius = '10px';
                    row.style.border = '1px solid var(--border-color)';
                    
                    const nameSpan = document.createElement('span');
                    nameSpan.innerText = f.name + ' (' + (f.length / 1024 / 1024).toFixed(1) + ' MB)';
                    nameSpan.style.fontSize = '0.9rem';
                    nameSpan.style.fontWeight = '500';
                    nameSpan.style.color = 'var(--text-color)';
                    
                    const dlBtn = document.createElement('a');
                    dlBtn.className = 'btn';
                    dlBtn.style.padding = '6px 14px';
                    dlBtn.style.fontSize = '0.8rem';
                    dlBtn.style.textDecoration = 'none';
                    dlBtn.innerText = '📥 Download';
                    dlBtn.href = f.streamURL;
                    dlBtn.download = f.name;
                    
                    row.appendChild(nameSpan);
                    row.appendChild(dlBtn);
                    fileListContainer.appendChild(row);
                }});
                
                fileListCard.style.display = 'block';

                const file = torrent.files.find(f => f.name.match(/\\.(mp4|webm)$/i));
                if (file) {{
                    const target = document.getElementById('webtorrent-player-target');
                    target.innerHTML = '<video id="webtorrent-video" controls autoplay></video>';
                    const videoEl = document.getElementById('webtorrent-video');
                    
                    if (reg) {{
                        file.streamTo(videoEl);
                        hideLoader();
                    }} else {{
                        file.appendTo('#webtorrent-player-target', {{ autoplay: true }}, () => hideLoader());
                    }}
                }} else {{
                    hideLoader();
                }}
                
                setInterval(() => {{
                    if (!webtorrentClient) return;
                    document.getElementById('stat-peers').innerText = torrent.numPeers + ' peers';
                    const prog = (torrent.progress * 100).toFixed(1);
                    document.getElementById('progress-fill').style.width = prog + '%';
                    document.getElementById('stat-progress').innerText = prog + '%';
                    document.getElementById('stat-down-speed').innerText = (torrent.downloadSpeed / 1024 / 1024).toFixed(2) + ' MB/s';
                }}, 1000);
            }});
        }}

        function showLoader(txt) {{ const l = document.getElementById('loader'); l.style.display = 'flex'; l.style.opacity = '1'; document.getElementById('loader-status').innerText = txt; }}
        function hideLoader() {{ const l = document.getElementById('loader'); l.style.opacity = '0'; setTimeout(() => l.style.display = 'none', 500); }}
        function copyMagnet() {{ navigator.clipboard.writeText(magnetURI).then(() => alert('Copied!')); }}
    </script>
</body>
</html>"""
            self.wfile.write(html.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def run_web_server():
    try:
        server = ThreadingHTTPServer(('0.0.0.0', WEB_SERVER_PORT), EmbedHandler)
        server.serve_forever()
    except Exception as e:
        print(f"Failed to start local web server: {e}")

web_thread = threading.Thread(target=run_web_server, daemon=True)
web_thread.start()

# ===================================================
# HELPERS: TMDB + TORRENTIO APIs (Castle-style)
# ===================================================

# Language codes → display names (India + World)
LANGUAGE_NAMES = {
    'hi': '🇮🇳 Hindi',    'te': '🇮🇳 Telugu',    'ta': '🇮🇳 Tamil',
    'ml': '🇮🇳 Malayalam', 'kn': '🇮🇳 Kannada',  'bn': '🇮🇳 Bengali',
    'mr': '🇮🇳 Marathi',  'gu': '🇮🇳 Gujarati',  'pa': '🇮🇳 Punjabi',
    'en': '🇺🇸 English',  'ko': '🇰🇷 Korean',    'ja': '🇯🇵 Japanese',
    'zh': '🇨🇳 Chinese',  'es': '🇪🇸 Spanish',   'fr': '🇫🇷 French',
    'de': '🇩🇪 German',   'it': '🇮🇹 Italian',   'pt': '🇧🇷 Portuguese',
    'ar': '🇸🇦 Arabic',   'tr': '🇹🇷 Turkish',   'ru': '🇷🇺 Russian',
}

# ---- TMDB helpers ----

def tmdb_request(path, params=None):
    """Make a TMDB API request and return parsed JSON."""
    try:
        extra = ''
        if params:
            extra = '&' + urllib.parse.urlencode(params)
        url = f"{TMDB_BASE}{path}?api_key={TMDB_API_KEY}{extra}"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=8) as r:
            return json.loads(r.read().decode('utf-8'))
    except Exception as e:
        print(f"TMDB Error [{path}]: {e}")
    return {}

def search_movies_tmdb(query):
    """Search 100,000+ movies across ALL languages via TMDB."""
    data = tmdb_request('/search/movie', {'query': query, 'include_adult': 'false'})
    return data.get('results', [])

def get_tmdb_movie_details(tmdb_id):
    """Get full movie info including IMDb ID (needed for Torrentio)."""
    return tmdb_request(f'/movie/{tmdb_id}', {'append_to_response': 'external_ids'})

def get_trending_movies():
    """Trending movies this week — all languages, auto-updated."""
    return tmdb_request('/trending/movie/week').get('results', [])

def get_now_playing():
    """New movies currently in theaters worldwide."""
    return tmdb_request('/movie/now_playing').get('results', [])

def get_top_rated():
    """All-time top rated movies (all languages)."""
    return tmdb_request('/movie/top_rated').get('results', [])

def get_movies_by_language(lang_code):
    """Get most popular movies in a specific language."""
    data = tmdb_request('/discover/movie', {
        'with_original_language': lang_code,
        'sort_by': 'popularity.desc'
    })
    return data.get('results', [])

# ---- Torrentio helpers (ALL providers = up to 50 streams) ----

def fetch_streams(imdb_id):
    """Fetch streams from Torrentio using ALL providers (no filter)."""
    try:
        url = f"https://torrentio.strem.fun/stream/movie/{imdb_id}.json"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=8) as r:
            return json.loads(r.read().decode('utf-8')).get('streams', [])
    except Exception as e:
        print(f"Torrentio Error: {e}")
    return []

def parse_stream_info(stream):
    """Extract quality, size, seeds, provider from a Torrentio stream object."""
    name  = stream.get('name', '')   # e.g. 'Torrentio\n4k DV'
    title = stream.get('title', '')  # e.g. 'Movie.mkv\n👤 94 💾 54 GB ⚙️ 1337x'
    # Quality: second line of 'name'
    parts   = name.split('\n')
    quality = parts[1].strip() if len(parts) > 1 else 'HD'
    # Size
    sm = re.search(r'\U0001f4be\s*([\d.]+\s*[KMGT]?B)', title)
    size = sm.group(1) if sm else '?'
    # Seeds
    pm = re.search(r'\U0001f464\s*(\d+)', title)
    seeds = int(pm.group(1)) if pm else 0
    # Provider
    gm = re.search(r'\u2699\ufe0f\s*([^\n|\U0001f464\U0001f4be]+)', title)
    provider = gm.group(1).strip() if gm else 'Unknown'
    return quality, size, seeds, provider

def build_magnet(info_hash, display_name):
    """Build a magnet link with WebRTC + UDP trackers."""
    dn = urllib.parse.quote(display_name)
    trackers = [
        'wss://tracker.openwebtorrent.com',
        'wss://tracker.webtorrent.dev',
        'wss://tracker.btorrent.xyz:443',
        'udp://tracker.opentrackr.org:1337/announce',
        'udp://tracker.coppersurfer.tk:6969/announce',
        'udp://explodie.org:6969/announce',
    ]
    tr = ''.join([f'&tr={urllib.parse.quote(t)}' for t in trackers])
    return f'magnet:?xt=urn:btih:{info_hash}&dn={dn}{tr}'

def download_poster(url):
    """Download movie poster to a temp file."""
    try:
        parsed = urllib.parse.urlparse(url)
        if not parsed.scheme or not parsed.netloc:
            return None
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=8) as r:
            data = r.read()
        temp_path = 'temp_poster.jpg'
        with open(temp_path, 'wb') as f:
            f.write(data)
        return temp_path
    except Exception as e:
        print(f"Poster download failed: {e}")
    return None

def format_movie_list(movies, header):
    """Format a list of TMDB movies for display in Telegram."""
    if not movies:
        return '\u274c No movies found.'
    lines = [header, '']
    for i, m in enumerate(movies[:12], 1):
        title  = m.get('title', 'Unknown')
        year   = str(m.get('release_date', ''))[:4] or 'N/A'
        rating = m.get('vote_average', 0)
        lang   = m.get('original_language', '')
        flag   = LANGUAGE_NAMES.get(lang, f'\U0001f30d {lang.upper()}')
        stars  = f'\u2b50{rating:.1f}' if rating else ''
        lines.append(f'{i}. **{title}** ({year}) {stars} | {flag}')
    lines.append('\n\U0001f50d *Send a movie name to search and get streaming links!*')
    return '\n'.join(lines)

async def send_movie_card(event, details, imdb_id):
    """Send a full Castle-style movie card with poster and stream buttons."""
    from telethon import Button

    title       = details.get('title', 'Unknown')
    year        = str(details.get('release_date', ''))[:4] or 'N/A'
    rating      = details.get('vote_average', 'N/A')
    overview    = details.get('overview', 'No description available.')
    lang        = details.get('original_language', '')
    lang_name   = LANGUAGE_NAMES.get(lang, lang.upper())
    poster_path = details.get('poster_path', '')
    genres_list = details.get('genres', [])
    genres      = ', '.join([g['name'] for g in genres_list[:3]]) if genres_list else 'N/A'
    runtime     = details.get('runtime', 0)
    runtime_str = f'{runtime} min' if runtime else 'N/A'

    if len(overview) > 280:
        overview = overview[:277] + '...'

    caption = (
        f'\U0001f3ac **{title} ({year})**\n'
        f'\u2b50 **Rating:** {rating}/10 | \U0001f551 {runtime_str}\n'
        f'\U0001f30d **Language:** {lang_name}\n'
        f'\U0001f3ad **Genres:** {genres}\n\n'
        f'\U0001f4dd {overview}'
    )

    # Fetch torrent streams (ALL providers)
    streams = fetch_streams(imdb_id) if imdb_id else []

    # Smart stream selection: pick best quality streams
    buttons     = []
    stream_info = []

    if streams:
        # Sort by seeds descending
        def sort_key(s):
            _, _, seeds, _ = parse_stream_info(s)
            return -seeds

        streams_sorted = sorted(streams, key=sort_key)

        # Pick up to 3 unique quality streams
        seen_q   = set()
        selected = []
        pref_q   = ['4k', '2160p', '1080p', '720p', '480p']

        for pq in pref_q:
            for s in streams_sorted:
                quality, size, seeds, provider = parse_stream_info(s)
                if pq.lower() in quality.lower() and quality not in seen_q:
                    selected.append((quality, size, seeds, provider, s))
                    seen_q.add(quality)
                    break
            if len(selected) >= 3:
                break

        # Fill remaining slots from top streams
        for s in streams_sorted:
            if len(selected) >= 3:
                break
            quality, size, seeds, provider = parse_stream_info(s)
            if quality not in seen_q:
                selected.append((quality, size, seeds, provider, s))
                seen_q.add(quality)

        for idx, (quality, size, seeds, provider, stream) in enumerate(selected[:3], 1):
            info_hash = stream.get('infoHash', '')
            if not info_hash:
                continue
            display_name = f'{title} ({year}) {quality}'
            magnet = build_magnet(info_hash, display_name)
            local_url  = (f'http://{LOCAL_IP}:{WEB_SERVER_PORT}/play_torrent'
                          f'?magnet={urllib.parse.quote(magnet)}'
                          f'&title={urllib.parse.quote(display_name)}')
            webtor_url = f'https://webtor.io/show?magnet={urllib.parse.quote(magnet)}'
            q_label    = quality[:10]
            buttons.append([
                Button.url(f'\u25b6\ufe0f Stream #{idx} [{q_label}]', local_url),
                Button.url(f'\U0001f4e5 Download [{size}]', webtor_url),
            ])
            stream_info.append(
                f'\U0001f4cc **#{idx}** `{quality}` | {size} | \U0001f331{seeds} seeds | {provider}\n'
                f'🧲 **Magnet Link (Tap to Copy):**\n`{magnet}`\n'
            )

    # Always add 2embed direct stream fallback
    if imdb_id:
        buttons.append([Button.url('\U0001f680 Direct Stream (No Torrent)', f'http://{LOCAL_IP}:{WEB_SERVER_PORT}/watch/{imdb_id}')])

    # Download and send poster
    poster_url   = f'{TMDB_IMG}{poster_path}' if poster_path else None
    local_poster = download_poster(poster_url) if poster_url else None

    try:
        if local_poster and os.path.exists(local_poster):
            await event.respond(caption, file=local_poster, parse_mode='markdown')
            try:
                os.remove(local_poster)
            except:
                pass
        else:
            await event.respond(caption, parse_mode='markdown')
    except Exception as e:
        print(f'Send poster failed: {e}')
        await event.respond(caption[:4096], parse_mode='markdown')

    # Send stream buttons
    if stream_info:
        streams_msg = '\U0001f37f **Available Streams:**\n\n' + '\n'.join(stream_info)
        streams_msg += '\n\n\U0001f4a1 Tap a button to **Stream** or **Download** instantly:'
    else:
        streams_msg = '\u26a0\ufe0f No torrent streams found — use **Direct Stream** below.'

    try:
        await event.respond(streams_msg, buttons=buttons, parse_mode='markdown')
    except Exception as e:
        print(f'Send buttons failed: {e}')
        if buttons:
            await event.respond('\U0001f3ac Use the buttons below:', buttons=buttons)


# ===================================================
# BOT CLIENT INITIALIZATION
# ===================================================
bot = TelegramClient('movie_bot_session', API_ID, API_HASH).start(bot_token=BOT_TOKEN)
print('Telegram Castle-Style Movie Bot is starting...')

# ===================================================
# BOT COMMANDS
# ===================================================

@bot.on(events.NewMessage(pattern=r'^/(start|help)$'))
async def start_handler(event):
    help_text = (
        '\U0001f3ac **Castle-Style Movie Bot**\n'
        '_100,000+ movies | All languages | Free_\n\n'
        '\U0001f4cb **Browse Commands:**\n'
        '\u2022 `/trending` — \U0001f525 Trending this week\n'
        '\u2022 `/new` — \U0001f195 Now playing worldwide\n'
        '\u2022 `/top` — \U0001f3c6 Top rated all time\n\n'
        '\U0001f1ee\U0001f1f3 **Indian Languages:**\n'
        '\u2022 `/hindi` `/telugu` `/tamil`\n'
        '\u2022 `/malayalam` `/kannada` `/bengali`\n\n'
        '\U0001f310 **World Languages:**\n'
        '\u2022 `/korean` `/japanese` `/english`\n\n'
        '\U0001f50d **Or just type any movie name to search!**\n\n'
        '_Powered by TMDB + Torrentio • All languages • Free forever_'
    )
    await event.respond(help_text, parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/trending$'))
async def trending_handler(event):
    msg = await event.respond('\U0001f525 Fetching trending movies this week...')
    movies = get_trending_movies()
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f525 **Trending This Week (All Languages):**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/new$'))
async def new_handler(event):
    msg = await event.respond('\U0001f195 Fetching now playing movies...')
    movies = get_now_playing()
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f195 **Now Playing Worldwide:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/top$'))
async def top_handler(event):
    msg = await event.respond('\U0001f3c6 Fetching top rated movies...')
    movies = get_top_rated()
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f3c6 **Top Rated All Time:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/hindi$'))
async def hindi_handler(event):
    msg = await event.respond('\U0001f1ee\U0001f1f3 Fetching Hindi movies...')
    movies = get_movies_by_language('hi')
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f1ee\U0001f1f3 **Popular Hindi Movies:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/telugu$'))
async def telugu_handler(event):
    msg = await event.respond('\U0001f1ee\U0001f1f3 Fetching Telugu movies...')
    movies = get_movies_by_language('te')
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f1ee\U0001f1f3 **Popular Telugu Movies:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/tamil$'))
async def tamil_handler(event):
    msg = await event.respond('\U0001f1ee\U0001f1f3 Fetching Tamil movies...')
    movies = get_movies_by_language('ta')
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f1ee\U0001f1f3 **Popular Tamil Movies:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/malayalam$'))
async def malayalam_handler(event):
    msg = await event.respond('\U0001f1ee\U0001f1f3 Fetching Malayalam movies...')
    movies = get_movies_by_language('ml')
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f1ee\U0001f1f3 **Popular Malayalam Movies:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/kannada$'))
async def kannada_handler(event):
    msg = await event.respond('\U0001f1ee\U0001f1f3 Fetching Kannada movies...')
    movies = get_movies_by_language('kn')
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f1ee\U0001f1f3 **Popular Kannada Movies:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/bengali$'))
async def bengali_handler(event):
    msg = await event.respond('\U0001f1ee\U0001f1f3 Fetching Bengali movies...')
    movies = get_movies_by_language('bn')
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f1ee\U0001f1f3 **Popular Bengali Movies:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/korean$'))
async def korean_handler(event):
    msg = await event.respond('\U0001f1f0\U0001f1f7 Fetching Korean movies...')
    movies = get_movies_by_language('ko')
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f1f0\U0001f1f7 **Popular Korean Movies:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/japanese$'))
async def japanese_handler(event):
    msg = await event.respond('\U0001f1ef\U0001f1f5 Fetching Japanese movies...')
    movies = get_movies_by_language('ja')
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f1ef\U0001f1f5 **Popular Japanese & Anime Movies:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/english$'))
async def english_handler(event):
    msg = await event.respond('\U0001f1fa\U0001f1f8 Fetching English movies...')
    movies = get_movies_by_language('en')
    await msg.delete()
    await event.respond(format_movie_list(movies, '\U0001f1fa\U0001f1f8 **Popular English Movies:**'), parse_mode='markdown')

@bot.on(events.NewMessage(pattern=r'^/add'))
async def add_movie_handler(event):
    text = event.text.replace('/add', '').strip()
    if not text or '|' not in text:
        await event.respond('\u274c Format: `/add Movie Name | Download Link`', parse_mode='markdown')
        return
    try:
        title, link = [p.strip() for p in text.split('|', 1)]
        conn   = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        cursor.execute('INSERT INTO movies (title, link) VALUES (?, ?)', (title, link))
        conn.commit()
        conn.close()
        await event.respond(f'\u2705 Added to local DB: **{title}**', parse_mode='markdown')
    except Exception as e:
        await event.respond(f'\u274c Error: {str(e)}')

# Main search handler — catches all non-command messages
@bot.on(events.NewMessage)
async def search_movie_handler(event):
    if event.text.startswith('/'):
        return
    query = event.text.strip()
    if not query or len(query) < 2:
        return

    status = await event.respond(f'\U0001f50d Searching **{query}** across all languages...', parse_mode='markdown')

    # Step 1: Search TMDB (covers 100,000+ movies in all languages)
    results = search_movies_tmdb(query)

    if not results:
        # Step 2: Fallback to local SQLite DB
        conn = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        cursor.execute('SELECT title, link FROM movies WHERE title LIKE ?', (f'%{query}%',))
        local_results = cursor.fetchall()
        conn.close()
        await status.delete()
        if local_results:
            from telethon import Button
            for title, link in local_results[:3]:
                local_url = (f'http://{LOCAL_IP}:{WEB_SERVER_PORT}/play_torrent'
                             f'?magnet={urllib.parse.quote(link)}&title={urllib.parse.quote(title)}')
                buttons = [[Button.url('\u25b6\ufe0f Play', local_url)]]
                await event.respond(f'\U0001f4e6 **{title}**\n`{link}`', buttons=buttons, parse_mode='markdown')
        else:
            await event.respond(
                f'\u274c No results for **\u201c{query}\u201d**\n\n'
                f'Try:\n\u2022 `/trending` — see what\'s popular\n'
                f'\u2022 `/hindi` `/telugu` `/tamil` — browse by language',
                parse_mode='markdown'
            )
        return

    await status.delete()

    # Step 3: Send top 3 results as full Castle-style movie cards
    for movie in results[:3]:
        tmdb_id = movie.get('id')
        if not tmdb_id:
            continue
        # Get full details + IMDb ID (needed for Torrentio)
        details = get_tmdb_movie_details(tmdb_id)
        if not details:
            continue
        imdb_id = details.get('external_ids', {}).get('imdb_id', '')
        await send_movie_card(event, details, imdb_id)

# ===================================================
# RUN THE BOT
# ===================================================
if __name__ == '__main__':
    import sys
    # Fix Windows console emoji encoding
    if sys.platform == 'win32':
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    print('Castle-Style Movie Bot running!')
    print(f'Web server: http://{LOCAL_IP}:{WEB_SERVER_PORT}')
    print('Commands: /trending /new /top /hindi /telugu /tamil /malayalam /kannada /bengali /korean /japanese /english')
    bot.run_until_disconnected()

