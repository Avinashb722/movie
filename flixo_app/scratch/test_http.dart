import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String authUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest';

Future<void> main() async {
  print('=== TESTING ORIGINAL HTTP POST IN DART ===');
  try {
    final uri = Uri.parse(authUrl);
    final body = json.encode({'keyword': 'avatar_${DateTime.now().millisecondsSinceEpoch}', 'perPage': 0});
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36',
      'Referer': 'https://www.movieboxpro.app/',
      'Origin': 'https://www.movieboxpro.app',
      'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"${DateTime.now().millisecondsSinceEpoch}"}',
    };

    final response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
    print('Response status: ${response.statusCode}');
    print('Response headers: ${response.headers}');
    final xUserHeader = response.headers['x-user'] ?? response.headers['X-User'];
    print('x-user: $xUserHeader');
  } catch (e) {
    print('Error: $e');
  }
}
