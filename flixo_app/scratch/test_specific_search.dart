import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final queries = ['Dridam', 'LockUp', 'Dridam LockUp', 'Lockup'];
  
  final headers = {
    'Accept': 'application/json, text/plain, */*',
    'Session-Id': 'e7c89c52-0740-4b11-a742-2899fa5d9bce',
    'Box-Id': '2b6eb866-8593-3e7b-f4fb-f71ed1cb6bdd',
    'Tenant-Code': 'dishtv',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Origin': 'https://www.watcho.com',
    'Referer': 'https://www.watcho.com/',
  };

  for (final q in queries) {
    print('=== Searching: "$q" ===');
    final queryUrl = 'https://dishtv-searchapi.revlet.net/search/api/v3/get/search/query?query=${Uri.encodeComponent(q)}&pageSize=36&last_search_order=typesense&bucket=all';
    try {
      final response = await http.get(Uri.parse(queryUrl), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          final searchResults = data['response']?['searchResults'] ?? {};
          final dataList = searchResults['data'] as List? ?? [];
          print('Found ${dataList.length} results.');
          for (final item in dataList) {
            final title = item['display']?['title'] ?? '';
            final target = item['target'] ?? {};
            final path = target['path'] ?? '';
            print('  * "$title" => Path: "$path"');
          }
        } else {
          print('API status: false');
        }
      } else {
        print('Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
    print('\n');
  }
}
