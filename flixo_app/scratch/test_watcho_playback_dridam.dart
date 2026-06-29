import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final headers = {
    'Accept': 'application/json, text/plain, */*',
    'Session-Id': '9b6b3a731c567eb32f0c',
    'Box-Id': 'e47683dc-31fd-d916-981a-47aad2dc9649',
    'Tenant-Code': 'dishtv',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Origin': 'https://www.watcho.com',
    'Referer': 'https://www.watcho.com/',
  };

  final paths = ['movie/play/dridam', 'movie/play/lockup'];

  for (final path in paths) {
    print('=== Testing Playback Path: "$path" ===');
    final streamApiUrl = 'https://dishtv-api.revlet.net/service/api/v1/page/stream?path=${Uri.encodeComponent(path)}&appVersion=1.0&versionCode=1.0';
    try {
      final response = await http.get(Uri.parse(streamApiUrl), headers: headers);
      print('Status Code: ${response.statusCode}');
      final data = json.decode(response.body);
      print(JsonEncoder.withIndent('  ').convert(data));
    } catch (e) {
      print('Error: $e');
    }
    print('\n');
  }
}
