import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('=== WATCHO SEARCH API RESPONSE DETAIL ===');
  
  final headers = {
    'Accept': 'application/json, text/plain, */*',
    'Session-Id': 'e7c89c52-0740-4b11-a742-2899fa5d9bce',
    'Box-Id': '2b6eb866-8593-3e7b-f4fb-f71ed1cb6bdd',
    'Tenant-Code': 'dishtv',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Origin': 'https://www.watcho.com',
    'Referer': 'https://www.watcho.com/',
  };

  final url = 'https://dishtv-api.revlet.net/service/api/v1/page/content?path=search&query=maidaan';

  try {
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(JsonEncoder.withIndent('  ').convert(data));
    } else {
      print('Error: ${response.statusCode}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
