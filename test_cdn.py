import urllib.request
import urllib.error
import ssl
import json
from moviebox_api.v2 import Session, Search, DownloadableSingleFilesDetail

async def get_url():
    s = Session()
    await s.ensure_cookies_are_assigned()
    r = await Search(s, 'Titanic').get_content_model()
    m = await DownloadableSingleFilesDetail(s, r.items[0]).get_content_model()
    return m.downloads[0].url if m.downloads else None

import asyncio
url = asyncio.run(get_url())

if url:
    print(f"Testing URL: {url}\n")
    ctx = ssl._create_unverified_context()
    
    # Test 1: Without headers
    print("Test 1: Request WITHOUT Referer/UA headers...")
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, context=ctx, timeout=5) as resp:
            print(f"Status: {resp.status}")
    except urllib.error.HTTPError as e:
        print(f"Result: Failed with HTTP Error {e.code}: {e.reason}")
    except Exception as e:
        print(f"Result: Error {e}")
        
    print()
    
    # Test 2: With headers
    print("Test 2: Request WITH Referer/UA headers...")
    try:
        req = urllib.request.Request(url, headers={
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://fmoviesunblocked.net/',
            'Origin': 'https://h5.aoneroom.com'
        })
        with urllib.request.urlopen(req, context=ctx, timeout=5) as resp:
            print(f"Result: Success! HTTP Status {resp.status}")
    except urllib.error.HTTPError as e:
        print(f"Result: Failed with HTTP Error {e.code}: {e.reason}")
    except Exception as e:
        print(f"Result: Error {e}")
else:
    print("No movie URL resolved.")
