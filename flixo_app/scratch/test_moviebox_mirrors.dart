import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test MovieBox download endpoint across MULTIPLE mirror hosts and endpoints.
/// The JS SDK mentions these mirrors: h5.aoneroom.com, movieboxapp.in
/// We also try the streaming endpoint (getMovieStreamUrl) that uses detailPath.
Future<void> main() async {
  // 1. Warm a fresh guest token from h5-api.aoneroom.com
  final authUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest';
  final headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36',
    'Referer': 'https://www.movieboxpro.app/',
    'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"a1b2c3d4e5f6g7h8"}',
  };
  final authBody = json.encode({'keyword': 'avatar_${DateTime.now().millisecondsSinceEpoch}', 'perPage': 0});
  
  String? token;
  try {
    final authResp = await http.post(Uri.parse(authUrl), headers: headers, body: authBody).timeout(const Duration(seconds: 10));
    if (authResp.statusCode == 200) {
      final xUserHeader = authResp.headers['x-user'];
      if (xUserHeader != null) {
        final userData = json.decode(xUserHeader);
        token = userData['token'];
        print('[1] Token warmed: ${token?.substring(0, 20)}...');
        
        // Decode JWT payload
        final parts = token!.split('.');
        final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        print('[1] JWT Payload: $payload');
      }
    }
  } catch (e) {
    print('[1] Error: $e');
  }
  if (token == null) { print('No token. Aborting.'); return; }

  final dlHeaders = Map<String, String>.from(headers);
  dlHeaders['Authorization'] = 'Bearer $token';

  // 2. Test different hosts for the download endpoint
  final hosts = ['h5.aoneroom.com', 'movieboxapp.in'];
  final subjectId = '8354513314264793488'; // Blast
  final detailPath = 'blast-mFhuBhMIbu1';
  
  for (final host in hosts) {
    print('\n=== Testing host: $host ===');
    
    // A. Standard download endpoint  
    final downloadUrl = 'https://$host/wefeed-h5-bff/web/subject/download?subjectId=$subjectId&se=0&ep=0&_t=${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    try {
      final resp = await http.get(Uri.parse(downloadUrl), headers: dlHeaders).timeout(const Duration(seconds: 10));
      print('[A] Download ($host) status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final downloads = data['data']?['downloads'] as List? ?? [];
        print('[A] Downloads: ${downloads.length}, hasResource: ${data['data']?['hasResource']}');
        if (downloads.isNotEmpty) {
          for (var dl in downloads) print('  * ${dl['resolution']}p: ${dl['url']}');
        }
      } else {
        print('[A] Body: ${resp.body.substring(0, 200)}');
      }
    } catch (e) {
      print('[A] Error: $e');
    }
    
    // B. Detail endpoint (to check if movie exists and has resources)
    final detailUrl = 'https://$host/wefeed-h5-bff/web/subject/detail?detailPath=$detailPath';
    try {
      final resp = await http.get(Uri.parse(detailUrl), headers: dlHeaders).timeout(const Duration(seconds: 10));
      print('[B] Detail ($host) status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final subjectData = data['data'] as Map? ?? {};
        print('[B] Title: ${subjectData['title']}, hasResource: ${subjectData['hasResource']}, freeResource: ${subjectData['freeResource']}, vipOnly: ${subjectData['vipOnly']}');
        // Print all keys to see what fields exist
        print('[B] Data keys: ${subjectData.keys.toList()}');
      }
    } catch (e) {
      print('[B] Error: $e');
    }
  }

  // 3. Also test the API host directly
  print('\n=== Testing h5-api.aoneroom.com (API host) ===');
  final apiDownloadUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/download?subjectId=$subjectId&se=0&ep=0';
  try {
    final resp = await http.get(Uri.parse(apiDownloadUrl), headers: dlHeaders).timeout(const Duration(seconds: 10));
    print('[3] API Download status: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final downloads = data['data']?['downloads'] as List? ?? [];
      print('[3] Downloads: ${downloads.length}, hasResource: ${data['data']?['hasResource']}');
    } else {
      print('[3] Body: ${resp.body}');
    }
  } catch (e) {
    print('[3] Error: $e');
  }
  
  // 4. Test with a well-known, older, popular movie that would DEFINITELY have free resources
  print('\n=== Testing with Titanic (well-known movie) ===');
  final searchUri = Uri.parse('https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search');
  final searchBody = json.encode({'keyword': 'Titanic', 'page': 1, 'perPage': 5, 'subjectType': 1});
  try {
    final resp = await http.post(searchUri, headers: dlHeaders, body: searchBody).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final items = data['data']?['items'] as List? ?? [];
      print('[4] Found ${items.length} results');
      for (var item in items.take(3)) {
        final sid = item['subjectId']?.toString() ?? '';
        final title = item['title'] ?? '';
        final dp = item['detailPath'] ?? '';
        print('  * $title (subjectId=$sid, detailPath=$dp)');
        
        // Try download for each
        final dlUrl = 'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/download?subjectId=$sid&se=0&ep=0&_t=${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
        try {
          final dlResp = await http.get(Uri.parse(dlUrl), headers: dlHeaders).timeout(const Duration(seconds: 10));
          if (dlResp.statusCode == 200) {
            final dlData = json.decode(dlResp.body);
            final dls = dlData['data']?['downloads'] as List? ?? [];
            print('    Downloads: ${dls.length}, hasResource: ${dlData['data']?['hasResource']}');
            if (dls.isNotEmpty) {
              for (var dl in dls) print('    >> ${dl['resolution']}p: ${dl['url']}');
            }
          }
        } catch (e) {
          print('    Download Error: $e');
        }
      }
    }
  } catch (e) {
    print('[4] Error: $e');
  }
}
