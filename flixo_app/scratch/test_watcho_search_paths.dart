import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('=== WATCHO SEARCH PATHS DISCOVERY ===');
  
  final headers = {
    'Accept': 'application/json, text/plain, */*',
    'Session-Id': 'e7c89c52-0740-4b11-a742-2899fa5d9bce',
    'Box-Id': '2b6eb866-8593-3e7b-f4fb-f71ed1cb6bdd',
    'Tenant-Code': 'dishtv',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Origin': 'https://www.watcho.com',
    'Referer': 'https://www.watcho.com/',
  };

  final paths = [
    'search-result',
    'search_result',
    'search-results',
    'search_results',
    'search-list',
    'searchresult',
    'searchresults',
  ];

  for (final path in paths) {
    // Try both query and searchText parameters
    for (final param in ['query', 'searchText', 'q']) {
      final url = 'https://dishtv-api.revlet.net/service/api/v1/page/content?path=$path&$param=maidaan&count=20';
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        if (response.statusCode == 200) {
          final body = response.body;
          if (body.contains('maidaan') || body.contains('Maidaan')) {
            print('SUCCESS! Path: $path with param: $param is working!');
            print('Snippet: ${body.substring(0, body.length > 500 ? 500 : body.length)}');
            return;
          }
        }
      } catch (e) {
        // ignore
      }
    }
    print('Path: $path failed.');
  }
  print('Done discovery.');
}
