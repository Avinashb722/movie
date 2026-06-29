import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Test if sending atp:1 in the request body makes the server issue a mobile token
Future<void> main() async {
  // Try different auth endpoints and body payloads to get atp:1
  final tests = [
    {
      'name': 'search-suggest with atp:1 in body',
      'url': 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest',
      'body': {'keyword': 'avatar', 'perPage': 0, 'atp': 1},
    },
    {
      'name': 'search-suggest with platform:android in body',
      'url': 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest',
      'body': {'keyword': 'avatar', 'perPage': 0, 'platform': 'android', 'atp': 1, 'appType': 1},
    },
    {
      'name': 'guest token endpoint (different path)',
      'url': 'https://h5-api.aoneroom.com/wefeed-h5api-bff/user/guest',
      'body': {'atp': 1, 'platform': 'android'},
    },
    {
      'name': 'device register endpoint',
      'url': 'https://h5-api.aoneroom.com/wefeed-h5api-bff/user/device',
      'body': {'deviceId': 'a1b2c3d4e5f67890', 'platform': 'android', 'atp': 1},
    },
    {
      'name': 'token endpoint',
      'url': 'https://h5-api.aoneroom.com/wefeed-h5api-bff/user/token',
      'body': {'atp': 1, 'platform': 'android', 'deviceId': 'a1b2c3d4e5f67890'},
    },
  ];

  const ua = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36';

  for (final test in tests) {
    print('\n=== ${test['name']} ===');
    final url = test['url'] as String;
    final body = json.encode(test['body']);
    
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': ua,
          'Referer': 'https://www.movieboxpro.app/',
          'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"a1b2c3d4e5f67890"}',
        },
        body: body,
      ).timeout(const Duration(seconds: 8));
      
      print('Status: ${resp.statusCode}');
      
      // Check x-user header
      final xUser = resp.headers['x-user'];
      if (xUser != null) {
        final userData = json.decode(xUser);
        final token = userData['token'] as String?;
        if (token != null) {
          final parts = token.split('.');
          final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          final payloadData = json.decode(payload);
          print('✅ Got token! atp=${payloadData['atp']} appType=${userData['appType']}');
          
          if (payloadData['atp'] != 3) {
            print('🎉 NON-WEB TOKEN! Testing play endpoint...');
            final playResp = await http.get(
              Uri.parse('https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/play?subjectId=1247971396999862152&se=0&ep=0&resolution=360'),
              headers: {'Authorization': 'Bearer $token', 'User-Agent': ua},
            ).timeout(const Duration(seconds: 8));
            final playData = json.decode(playResp.body);
            final streams = playData['data']?['streams'] as List? ?? [];
            print('   Streams: ${streams.length}, hasResource: ${playData['data']?['hasResource']}');
            if (streams.isNotEmpty) print('   URL: ${streams[0]['url']}');
          }
        }
      } else {
        print('Body: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
