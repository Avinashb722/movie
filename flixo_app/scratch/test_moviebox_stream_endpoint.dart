import 'dart:convert';
import 'package:http/http.dart' as http;

/// The detail endpoint confirms resources exist (360p, 480p, 1080p).
/// The download endpoint returns empty because it's VIP-only.
/// Now let's find the STREAMING endpoint that the web player uses.
/// The JS SDK has getMovieStreamUrl which likely calls a different API path.
Future<void> main() async {
  final headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36',
    'Referer': 'https://www.movieboxpro.app/',
    'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"a1b2c3d4e5f6g7h8"}',
  };
  
  final authBody = json.encode({'keyword': 'test_${DateTime.now().millisecondsSinceEpoch}', 'perPage': 0});
  final authResp = await http.post(
    Uri.parse('https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest'),
    headers: headers, body: authBody,
  ).timeout(const Duration(seconds: 10));
  
  final xUser = authResp.headers['x-user'];
  if (xUser == null) { print('No token'); return; }
  final token = json.decode(xUser)['token'];
  print('Token: ${token.substring(0, 20)}...');
  
  final dlHeaders = Map<String, String>.from(headers);
  dlHeaders['Authorization'] = 'Bearer $token';
  
  final subjectId = '1247971396999862152'; // Blast (from detail response)
  final detailPath = 'blast-mFhuBhMIbu1';
  
  // Try different streaming endpoint patterns
  final endpoints = [
    // Pattern 1: Play endpoint (common in streaming apps)
    'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/play?subjectId=$subjectId&se=0&ep=0&resolution=360',
    'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/play?detailPath=$detailPath&se=0&ep=0&resolution=360',
    
    // Pattern 2: Stream endpoint
    'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/stream?subjectId=$subjectId&se=0&ep=0&resolution=360',
    
    // Pattern 3: Resource endpoint  
    'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/resource?subjectId=$subjectId&se=0&ep=0&resolution=360',
    
    // Pattern 4: Video endpoint
    'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/video?subjectId=$subjectId&se=0&ep=0&resolution=360',
    
    // Pattern 5: Media/playUrl
    'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/playUrl?subjectId=$subjectId&se=0&ep=0&resolution=360',
    
    // Pattern 6: Try the API host
    'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/play?subjectId=$subjectId&se=0&ep=0&resolution=360',
    'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/stream?subjectId=$subjectId&se=0&ep=0&resolution=360',
    'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/resource?subjectId=$subjectId&se=0&ep=0&resolution=360',
    'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/playUrl?subjectId=$subjectId&se=0&ep=0&resolution=360',
    
    // Pattern 7: Watch endpoint
    'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/watch?subjectId=$subjectId&se=0&ep=0&resolution=360',
    'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/watch?subjectId=$subjectId&se=0&ep=0&resolution=360',
  ];
  
  for (final url in endpoints) {
    try {
      // Try GET first
      var resp = await http.get(Uri.parse(url), headers: dlHeaders).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 405) {
        // Try POST if GET returns 405
        resp = await http.post(Uri.parse(url), headers: dlHeaders, body: '{}').timeout(const Duration(seconds: 5));
      }
      final shortUrl = url.replaceAll('https://h5.aoneroom.com/wefeed-h5-bff/web/', '').replaceAll('https://h5-api.aoneroom.com/wefeed-h5api-bff/', 'API:');
      if (resp.statusCode == 200) {
        print('[OK 200] $shortUrl');
        final body = resp.body;
        if (body.length < 500) {
          print('  Body: $body');
        } else {
          print('  Body (first 500): ${body.substring(0, 500)}');
        }
      } else if (resp.statusCode == 404) {
        print('[404] $shortUrl');
      } else {
        print('[${resp.statusCode}] $shortUrl');
        if (resp.body.length < 200) print('  Body: ${resp.body}');
      }
    } catch (e) {
      final shortUrl = url.replaceAll('https://h5.aoneroom.com/wefeed-h5-bff/web/', '').replaceAll('https://h5-api.aoneroom.com/wefeed-h5api-bff/', 'API:');
      print('[ERR] $shortUrl: $e');
    }
  }
}
