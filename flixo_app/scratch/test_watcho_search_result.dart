import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('=== WATCHO SEARCH RESULTS DETAIL ===');
  
  final headers = {
    'Accept': 'application/json, text/plain, */*',
    'Session-Id': 'e7c89c52-0740-4b11-a742-2899fa5d9bce',
    'Box-Id': '2b6eb866-8593-3e7b-f4fb-f71ed1cb6bdd',
    'Tenant-Code': 'dishtv',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Origin': 'https://www.watcho.com',
    'Referer': 'https://www.watcho.com/',
  };

  final url = 'https://dishtv-searchapi.revlet.net/search/api/v3/get/search/query?query=Maidaan&pageSize=36&last_search_order=typesense&bucket=all';

  try {
    final response = await http.get(Uri.parse(url), headers: headers);
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(JsonEncoder.withIndent('  ').convert(data));
    }
  } catch (e) {
    print('Exception: $e');
  }
}
