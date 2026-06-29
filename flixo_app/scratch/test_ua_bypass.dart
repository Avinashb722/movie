import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

const String authUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest';

Future<void> main() async {
  print('=== TESTING USER-AGENT GUEST TOKEN BYPASS ===');
  
  // Warm first token
  final token1 = await warmToken('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
  print('Token 1: $token1');
  
  print('\nWait 2 seconds...');
  await Future.delayed(const Duration(seconds: 2));

  // Warm second token with the exact same UA
  final token2 = await warmToken('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
  print('Token 2: $token2');
  print('Are tokens identical? ${token1 == token2}');

  print('\nWait 2 seconds...');
  await Future.delayed(const Duration(seconds: 2));

  // Warm third token with a different UA (random Chrome minor version)
  final randomVersion = Random().nextInt(1000);
  final token3 = await warmToken('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.$randomVersion.0 Safari/537.36');
  print('Token 3: $token3');
  print('Are Token 1 and Token 3 identical? ${token1 == token3}');
}

Future<String?> warmToken(String userAgent) async {
  try {
    final uri = Uri.parse(authUrl);
    final body = json.encode({'keyword': 'avatar_${DateTime.now().millisecondsSinceEpoch}', 'perPage': 0});
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': userAgent,
      'Referer': 'https://h5.aoneroom.com/',
      'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"${DateTime.now().millisecondsSinceEpoch}"}',
    };

    final response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
    final xUserHeader = response.headers['x-user'] ?? response.headers['X-User'];
    if (xUserHeader != null) {
      final userData = json.decode(xUserHeader);
      final token = userData['token'] as String?;
      if (token != null) {
        final parts = token.split('.');
        final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        final data = json.decode(payload);
        return 'uid=${data['uid']}, iat=${data['iat']}';
      }
    }
  } catch (e) {
    print('Error warming token: $e');
  }
  return null;
}
