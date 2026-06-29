import 'dart:convert';
import 'package:http/http.dart' as http;

/// Check the DETAIL endpoint response structure - specifically the `resource` field
/// which may contain streaming URLs that the download endpoint doesn't expose.
Future<void> main() async {
  // Warm token
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
  
  // Fetch FULL detail response for Blast and print ALL nested data
  final detailUrl = 'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/detail?detailPath=blast-mFhuBhMIbu1';
  final resp = await http.get(Uri.parse(detailUrl), headers: dlHeaders).timeout(const Duration(seconds: 10));
  
  if (resp.statusCode == 200) {
    final data = json.decode(resp.body);
    final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
    print('=== FULL DETAIL RESPONSE ===');
    print(prettyJson);
  } else {
    print('Status: ${resp.statusCode}');
    print('Body: ${resp.body}');
  }
}
