import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const authUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest';
  const searchUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search';
  const headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': 'https://h5.aoneroom.com/',
    'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"1234567890"}',
  };

  try {
    // 1. Warm token
    print('Warming token...');
    final body = json.encode({'keyword': 'avatar_1234567890', 'perPage': 0});
    final authResp = await http.post(Uri.parse(authUrl), headers: headers, body: body);
    final xUser = authResp.headers['x-user'] ?? authResp.headers['X-User'] ?? '';
    
    if (xUser.isEmpty) {
      print('Failed to warm token, x-user header missing. Headers: ${authResp.headers}');
      return;
    }
    
    final userData = json.decode(xUser);
    final token = userData['token'];
    print('Token warmed: $token');

    // 2. Search for "Junior"
    print('Searching Aoneroom for "Junior"...');
    final searchHeaders = {
      ...headers,
      'Authorization': 'Bearer $token',
    };
    final searchPayload = json.encode({
      'keyword': 'Junior',
      'page': 1,
      'perPage': 15,
      'subjectType': 1,
    });
    
    final searchResp = await http.post(Uri.parse(searchUrl), headers: searchHeaders, body: searchPayload);
    print('Search response status: ${searchResp.statusCode}');
    print('Search response: ${searchResp.body}');
  } catch (e) {
    print('Error: $e');
  }
}
