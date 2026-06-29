import asyncio
from moviebox_api.v2 import Session, Search, DownloadableSingleFilesDetail

async def main():
    print("Initializing MovieBox session...")
    session = Session()
    # Authenticate by making user info request internally
    await session.ensure_cookies_are_assigned()
    print("Session authenticated successfully!")
    
    search_query = "Inception"
    print(f"\nSearching for movie: '{search_query}'...")
    search_service = Search(session, query=search_query)
    results_model = await search_service.get_content_model()
    
    results = results_model.items
    print(f"Found {len(results)} search results.")
    if not results:
        return
        
    for idx, item in enumerate(results[:3], 1):
        print(f"[{idx}] Title: {item.title} | SubjectType: {item.subjectType} | SubjectID: {item.subjectId} | DetailPath: {item.detailPath}")
    
    # Pick the first movie
    target_item = results[0]
    print(f"\nFetching download/stream details for: '{target_item.title}' (ID: {target_item.subjectId})...")
    
    files_detail_service = DownloadableSingleFilesDetail(session, target_item)
    files_metadata = await files_detail_service.get_content_model()
    
    print("\n--- STREAM FILES FOUND ---")
    print(f"Languages available: {list(files_metadata.list.keys())}")
    
    for lang, list_of_files in files_metadata.list.items():
        print(f"\nLanguage: {lang}")
        for f in list_of_files:
            print(f" - Quality: {f.quality} | Size: {f.size} | URL: {f.path}")

if __name__ == "__main__":
    asyncio.run(main())
