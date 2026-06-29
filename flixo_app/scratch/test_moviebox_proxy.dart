import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36',
    'Referer': 'https://www.movieboxpro.app/',
    'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"1234567890"}',
  };

  print('=== Testing Complete Proxy Flow (Warm + Download) ===');
  
  // 1. Warm guest token via proxy
  final authUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest';
  final authProxyUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(authUrl)}');
  final authBody = json.encode({'keyword': 'avatar_${DateTime.now().millisecondsSinceEpoch}', 'perPage': 0});
  
  String? token;
  try {
    final authResp = await http.post(authProxyUri, headers: headers, body: authBody);
    if (authResp.statusCode == 200) {
      final xUserHeader = authResp.headers['x-user'] ?? authResp.headers['X-User'] ?? authResp.headers['x-user'];
      if (xUserHeader != null) {
        final userData = json.decode(xUserHeader);
        token = userData['token'];
        print('Warmed Token successfully via Vercel: ${token != null ? "${token.substring(0, 15)}..." : "null"}');
      } else {
        print('x-user header missing. Headers: ${authResp.headers}');
      }
    } else {
      print('Warming failed: ${authResp.statusCode} - ${authResp.body}');
    }
  } catch (e) {
    print('Warming Error: $e');
  }

  if (token == null) {
    print('Cannot proceed without token.');
    return;
  }

  // 2. Fetch downloads via proxy
  final subjectId = '8354513314264793488'; // Blast
  final downloadUrl = 'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/download?subjectId=$subjectId&se=0&ep=0&_t=${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
  final downloadProxyUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(downloadUrl)}');
  
  final dlHeaders = Map<String, String>.from(headers);
  dlHeaders['Authorization'] = 'Bearer $token';

  try {
    final response = await http.get(downloadProxyUri, headers: dlHeaders);
    print('Download Response Status Code: ${response.statusCode}');
    if (response.statusCode == 200) {
      final dlData = json.decode(response.body);
      final downloads = dlData['data']?['downloads'] as List? ?? [];
      final hasResource = dlData['data']?['hasResource'] ?? false;
      print('Downloads Count: ${downloads.length}, HasResource: $hasResource');
      if (downloads.isNotEmpty) {
        print('SUCCESS! The Vercel proxy resolved download links successfully!');
        for (final dl in downloads) {
          print('  * Resolution: ${dl['resolution']}p, URL: ${dl['url']}');
        }
      } else {
        print('Body: ${response.body}');
      }
    } else {
      print('Failed with body: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
