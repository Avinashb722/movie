import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('=== WATCHO DHURANDHAR STREAM RESOLVER TEST ===');
  
  final String streamApiUrl = 'https://dishtv-api.revlet.net/service/api/v1/page/stream?path=movie%2Fplay%2Fdhurandhar&appVersion=1.0&versionCode=1.0';
  
  final headers = {
    'Accept': 'application/json, text/plain, */*',
    'Session-Id': 'e7c89c52-0740-4b11-a742-2899fa5d9bce',
    'Box-Id': '2b6eb866-8593-3e7b-f4fb-f71ed1cb6bdd',
    'Tenant-Code': 'dishtv',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Origin': 'https://www.watcho.com',
    'Referer': 'https://www.watcho.com/',
  };

  try {
    print('Sending GET request for Dhurandhar...');
    final response = await http.get(Uri.parse(streamApiUrl), headers: headers);
    print('Status Code: ${response.statusCode}');
    
    final data = json.decode(response.body);
    print('\nDecoded JSON Response:');
    print(JsonEncoder.withIndent('  ').convert(data));
  } catch (e) {
    print('Exception: $e');
  }
}
