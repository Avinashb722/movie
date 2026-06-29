import 'dart:convert';
import 'package:http/http.dart' as http;

/// The play endpoint exists and confirms content is NOT VIP-locked (freeNum=999, vipLocked=false)
/// BUT returns empty streams. The JWT token has atp:3 (web).
/// The MovieBox Android app likely gets atp:1 (mobile) which IS allowed to get streams.
/// Let's try different X-Client-Info, User-Agent, and Referer combinations
/// to convince the auth endpoint to issue a mobile-type token (atp != 3).
Future<void> main() async {
  final configs = [
    {
      'name': 'Standard Android Mobile App',
      'ua': 'Mozilla/5.0 (Linux; Android 14; 23076RN4BI) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.7151.103 Mobile Safari/537.36',
      'referer': 'https://www.movieboxpro.app/',
      'clientInfo': '{"timezone":"Asia/Kolkata","device_id":"a1b2c3d4e5f6g7h8","platform":"android","version":"14.0"}',
    },
    {
      'name': 'MovieBox Android App UA',
      'ua': 'MovieBox/3.0 (Android; 14)',
      'referer': '',
      'clientInfo': '{"timezone":"Asia/Kolkata","device_id":"a1b2c3d4e5f6g7h8","platform":"android","app_version":"3.0"}',
    },
    {
      'name': 'No Referer (pure mobile)',
      'ua': 'okhttp/4.12.0',
      'referer': '',
      'clientInfo': '{"timezone":"Asia/Kolkata","device_id":"a1b2c3d4e5f6g7h8"}',
    },
    {
      'name': 'iOS Mobile',
      'ua': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
      'referer': 'https://www.movieboxpro.app/',
      'clientInfo': '{"timezone":"Asia/Kolkata","device_id":"a1b2c3d4e5f6g7h8","platform":"ios"}',
    },
    {
      'name': 'Android WebView',
      'ua': 'Mozilla/5.0 (Linux; Android 14; 23076RN4BI Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/137.0.7151.103 Mobile Safari/537.36',
      'referer': 'https://h5.aoneroom.com/',
      'clientInfo': '{"timezone":"Asia/Kolkata","device_id":"a1b2c3d4e5f6g7h8","platform":"android"}',
    },
    {
      'name': 'With X-App-Platform header',
      'ua': 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36',
      'referer': 'https://www.movieboxpro.app/',
      'clientInfo': '{"timezone":"Asia/Kolkata","device_id":"a1b2c3d4e5f6g7h8"}',
      'extraHeaders': {'X-App-Platform': 'android', 'X-App-Version': '3.0.0'},
    },
  ];
  
  for (final config in configs) {
    print('\n=== ${config['name']} ===');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': config['ua'] as String,
      'X-Client-Info': config['clientInfo'] as String,
    };
    if ((config['referer'] as String).isNotEmpty) {
      headers['Referer'] = config['referer'] as String;
    }
    if (config.containsKey('extraHeaders')) {
      headers.addAll(config['extraHeaders'] as Map<String, String>);
    }
    
    final authBody = json.encode({'keyword': 'test_${DateTime.now().millisecondsSinceEpoch}', 'perPage': 0});
    try {
      final authResp = await http.post(
        Uri.parse('https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest'),
        headers: headers, body: authBody,
      ).timeout(const Duration(seconds: 10));
      
      if (authResp.statusCode == 200) {
        final xUser = authResp.headers['x-user'];
        if (xUser != null) {
          final token = json.decode(xUser)['token'] as String;
          // Decode JWT
          final parts = token.split('.');
          final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          final payloadData = json.decode(payload);
          print('  atp: ${payloadData['atp']} (uid: ${payloadData['uid']})');
          
          // If atp is different from 3, try the play endpoint!
          if (payloadData['atp'] != 3) {
            print('  ** DIFFERENT ATP VALUE! Testing play endpoint...');
            headers['Authorization'] = 'Bearer $token';
            final playResp = await http.get(
              Uri.parse('https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/play?subjectId=1247971396999862152&se=0&ep=0&resolution=360'),
              headers: headers,
            ).timeout(const Duration(seconds: 10));
            print('  Play response: ${playResp.body}');
          }
        } else {
          print('  No x-user header');
        }
      } else {
        print('  Auth failed: ${authResp.statusCode}');
      }
    } catch (e) {
      print('  Error: $e');
    }
  }
}
