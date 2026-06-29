"""
Test ALL movie streaming embed sources - find which ones work
Testing with: Interstellar (tt0816692) and The Dark Knight (tt0468569)
"""
import urllib.request
import urllib.error
import json
import time
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

TEST_IMDB  = 'tt0816692'   # Interstellar
TEST_TMDB  = '157336'      # Interstellar TMDB ID
TEST_TITLE = 'Interstellar'

# ---- All known embed sources ----
SOURCES = [
    # Name, URL template, notes
    ("vidsrc.to",       f"https://vidsrc.to/embed/movie/{TEST_IMDB}",             "Popular, usually works"),
    ("vidsrc.me",       f"https://vidsrc.me/embed/movie?imdb={TEST_IMDB}",         "Old reliable"),
    ("vidsrc.xyz",      f"https://vidsrc.xyz/embed/movie?imdb={TEST_IMDB}",        "Mirror"),
    ("vidsrc.net",      f"https://vidsrc.net/embed/movie/{TEST_IMDB}",             "Mirror"),
    ("vidsrc.cc",       f"https://vidsrc.cc/v2/embed/movie/{TEST_IMDB}",           "Mirror v2"),
    ("vidsrc.icu",      f"https://vidsrc.icu/embed/movie/{TEST_IMDB}",             "Mirror"),
    ("2embed.cc",       f"https://www.2embed.cc/embed/{TEST_IMDB}",                "Current bot"),
    ("2embed.skin",     f"https://www.2embed.skin/embed/{TEST_IMDB}",              "Alt 2embed"),
    ("multiembed.mov",  f"https://multiembed.mov/?video_id={TEST_IMDB}&tmdb=1",    "Multi source"),
    ("embed.su",        f"https://embed.su/embed/movie/{TEST_IMDB}",               "embed.su"),
    ("autoembed.cc",    f"https://autoembed.cc/movie/imdb/{TEST_IMDB}",            "autoembed"),
    ("smashystream",    f"https://embed.smashystream.com/playere.php?imdb={TEST_IMDB}", "smashystream"),
    ("moviesapi.club",  f"https://moviesapi.club/movie/{TEST_IMDB}",               "moviesapi"),
    ("superembed",      f"https://multiembed.mov/directstream.php?video_id={TEST_IMDB}&tmdb=1", "superembed"),
    ("warezcdn",        f"https://embed.warezcdn.link/filme/{TEST_IMDB}",           "warezcdn"),
    ("nontonton",       f"https://www.nontonton.cc/embed/movie/{TEST_IMDB}",        "nontonton"),
    ("flix2watch",      f"https://flix2watch.com/?url={TEST_IMDB}",                "flix2watch"),
    ("videasy",         f"https://player.videasy.net/movie/{TEST_IMDB}",           "videasy"),
    ("embedrise",       f"https://embedrise.com/e/{TEST_IMDB}",                    "embedrise"),
    ("frembed",         f"https://frembed.fun/api/film.php?id={TEST_IMDB}",        "frembed - direct API"),
    ("111movies",       f"https://111movies.com/embed/{TEST_IMDB}",                "111movies"),
    ("player.autoembed",f"https://player.autoembed.cc/embed/movie/{TEST_IMDB}",   "player autoembed"),
    ("flixhq",          f"https://flixhq.to/embed/movie/{TEST_IMDB}",             "flixhq"),
    ("embedder.cc",     f"https://embedder.cc/e/imdb={TEST_IMDB}",               "embedder.cc"),
    ("broflix",         f"https://www.broflix.cc/movie/{TEST_IMDB}",               "broflix"),
]

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Referer': 'https://google.com/',
}

print("=" * 70)
print(f"TESTING ALL STREAMING SOURCES FOR: {TEST_TITLE} ({TEST_IMDB})")
print("=" * 70)
print()

working  = []
blocked  = []
dead     = []

for name, url, note in SOURCES:
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=8) as resp:
            status = resp.status
            content = resp.read(5000).decode('utf-8', errors='ignore').lower()
            
            # Check for signs of a working player
            has_video    = any(x in content for x in ['video', 'player', 'iframe', 'source', 'stream', 'jwplayer', 'plyr', 'hls', 'mp4', 'm3u8'])
            has_embed    = any(x in content for x in ['embed', 'watch', 'play'])
            is_blocked   = any(x in content for x in ['403', 'access denied', 'cloudflare', 'not available', 'geo', 'vpn required', 'blocked'])
            is_error     = any(x in content for x in ['404', 'not found', 'error', 'sorry'])
            is_captcha   = any(x in content for x in ['captcha', 'robot', 'verify'])
            
            if status == 200 and has_video and not is_error:
                status_label = "✅ WORKS"
                working.append((name, url, note))
            elif is_blocked or is_captcha:
                status_label = "⚠️  BLOCKED/CAPTCHA"
                blocked.append((name, url))
            elif is_error:
                status_label = "❌ ERROR PAGE"
                dead.append((name, url))
            else:
                status_label = "⚠️  UNCLEAR"
                blocked.append((name, url))
                
    except urllib.error.HTTPError as e:
        if e.code == 403:
            status_label = "🚫 403 FORBIDDEN"
            blocked.append((name, url))
        elif e.code == 404:
            status_label = "💀 404 NOT FOUND"
            dead.append((name, url))
        else:
            status_label = f"❌ HTTP {e.code}"
            dead.append((name, url))
    except urllib.error.URLError as e:
        status_label = "💀 UNREACHABLE"
        dead.append((name, url))
    except Exception as e:
        status_label = f"⚠️  ERROR: {str(e)[:40]}"
        dead.append((name, url))
    
    print(f"  {status_label:25s} | {name:20s} | {note}")
    time.sleep(0.3)

print()
print("=" * 70)
print("SUMMARY")
print("=" * 70)
print(f"\n✅ WORKING SOURCES ({len(working)}):")
for name, url, note in working:
    print(f"   {name:20s} -> {url}")

print(f"\n⚠️  BLOCKED/UNCLEAR ({len(blocked)}):")
for name, url in blocked:
    print(f"   {name:20s} -> {url}")

print(f"\n💀 DEAD ({len(dead)}):")
for name, url in dead:
    print(f"   {name}")

print()
print("=" * 70)
print("RECOMMENDED EMBED URLs TO ADD TO BOT:")
print("=" * 70)
for name, url, note in working:
    print(f'  ("{name}", "{url.replace(TEST_IMDB, "{imdb_id}")}"),')
