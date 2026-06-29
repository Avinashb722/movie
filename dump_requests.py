import asyncio
import httpx
import json
from moviebox_api.v2 import Session, Search, DownloadableSingleFilesDetail

# We monkey patch httpx.AsyncClient.request to intercept all network calls
original_request = httpx.AsyncClient.request

async def mocked_request(self, method, url, **kwargs):
    print("\n" + "="*80)
    print(f"REQUEST: {method} {url}")
    if "headers" in kwargs and kwargs["headers"]:
        print("HEADERS:")
        for k, v in kwargs["headers"].items():
            print(f"  {k}: {v}")
    if "json" in kwargs and kwargs["json"]:
        print("JSON BODY:")
        print(json.dumps(kwargs["json"], indent=2))
    elif "params" in kwargs and kwargs["params"]:
        print("QUERY PARAMETERS:")
        print(json.dumps(kwargs["params"], indent=2))
        
    response = await original_request(self, method, url, **kwargs)
    
    print(f"\nRESPONSE STATUS: {response.status_code}")
    print("RESPONSE HEADERS:")
    for k, v in response.headers.items():
        print(f"  {k}: {v}")
    try:
        data = response.json()
        print("RESPONSE JSON:")
        print(json.dumps(data, indent=2)[:2000]) # Limit output to 2000 chars
    except Exception:
        print("RESPONSE TEXT:")
        print(response.text[:500])
    print("="*80 + "\n")
    
    return response

httpx.AsyncClient.request = mocked_request

async def main():
    session = Session()
    # 1. Authenticate / Initialize session cookies
    await session.ensure_cookies_are_assigned()
    
    # 2. Search for a movie
    search_service = Search(session, query="Inception")
    results = await search_service.get_content_model()
    
    if results.items:
        # 3. Get stream detail for first item
        target_item = results.items[0]
        files_detail_service = DownloadableSingleFilesDetail(session, target_item)
        await files_detail_service.get_content_model()

if __name__ == "__main__":
    asyncio.run(main())
