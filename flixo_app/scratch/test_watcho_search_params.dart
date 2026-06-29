import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final headers = {
    'Accept': 'application/json, text/plain, */*',
    'Session-Id': 'e7c89c52-0740-4b11-a742-2899fa5d9bce',
    'Box-Id': '2b6eb866-8593-3e7b-f4fb-f71ed1cb6bdd',
    'Tenant-Code': 'dishtv',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Origin': 'https://www.watcho.com',
    'Referer': 'https://www.watcho.com/',
  };

  final params = [
    'searchText',
    'searchKey',
    'q',
    'keyword',
    'searchQuery',
    'search',
    'query'
  ];

  for (final param in params) {
    final url = 'https://dishtv-api.revlet.net/service/api/v1/page/content?path=search&$param=maidaan';
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final body = response.body;
        // Count how many times the word "Maidaan" or "maidaan" is in the response body.
        final matches = RegExp(r'maidaan', caseSensitive: false).allMatches(body).length;
        print('Param: $param => Status: 200, Length: ${body.length}, "maidaan" matches: $matches');
        
        if (matches > 1) {
          // It contains search results matching Maidaan!
          final data = json.decode(body);
          final dataList = data['response']?['data'] as List? ?? [];
          print('Found ${dataList.length} sections in search results.');
          for (final section in dataList) {
            final name = section['section']?['sectionInfo']?['name'] ?? '';
            final items = section['section']?['sectionData']?['data'] as List? ?? [];
            print('  * Section: $name (Count: ${items.length})');
            if (items.isNotEmpty) {
              print('    - First item title: ${items.first['display']?['title']}');
              print('    - First item path: ${items.first['target']?['path']}');
            }
          }
          break; // Stop here if we found a successful query parameter!
        }
      } else {
        print('Param: $param => Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Param: $param => Exception: $e');
    }
  }
}
