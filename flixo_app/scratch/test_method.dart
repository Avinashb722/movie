import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String authUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest';
const String searchUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search';
const String downloadUrl = 'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/download';

Future<void> main() async {
  print('=== WARMING TOKEN ===');
  String? token;
  try {
    final uri = Uri.parse(authUrl);
    final body = json.encode({'keyword': 'avatar_${DateTime.now().millisecondsSinceEpoch}', 'perPage': 0});
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Referer': 'https://h5.aoneroom.com/',
      'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"${DateTime.now().millisecondsSinceEpoch}"}',
    };

    final response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
    final xUserHeader = response.headers['x-user'] ?? response.headers['X-User'];
    if (xUserHeader != null) {
      token = json.decode(xUserHeader)['token'];
    }
  } catch (e) {
    print('Failed to warm token: $e');
    return;
  }

  if (token == null) return;

  print('\n=== SEARCHING FOR MOVIE "Karuppu" ===');
  String? subjectId;
  String? detailPath;
  try {
    final searchUri = Uri.parse(searchUrl);
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Referer': 'https://h5.aoneroom.com/',
      'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"${DateTime.now().millisecondsSinceEpoch}"}',
      'Authorization': 'Bearer $token',
    };
    final payload = {
      'keyword': 'Karuppu',
      'page': 1,
      'perPage': 15,
      'subjectType': 1,
    };

    final response = await http.post(searchUri, headers: headers, body: json.encode(payload)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['data']?['items'] as List? ?? [];
      if (items.isNotEmpty) {
        subjectId = items.first['subjectId']?.toString();
        detailPath = items.first['detailPath'] as String?;
      }
    }
  } catch (e) {
    print('Search failed: $e');
  }

  if (subjectId == null) return;

  print('\n=== TESTING GET REQUEST ON DOWNLOAD ENDPOINT ===');
  try {
    final downloadUri = Uri.parse(downloadUrl).replace(queryParameters: {
      'subjectId': subjectId,
      'se': '0',
      'ep': '0',
      '_t': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
    });
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Referer': 'https://h5.aoneroom.com/movies/$detailPath',
      'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"${DateTime.now().millisecondsSinceEpoch}"}',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(downloadUri, headers: headers).timeout(const Duration(seconds: 10));
    print('GET Response code: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final downloadsList = data['data']?['downloads'] as List? ?? [];
      for (var d in downloadsList) {
        print('GET Download: ${d['resolution']}p, URL: ${d['url']}');
      }
    }
  } catch (e) {
    print('GET failed: $e');
  }

  print('\n=== TESTING POST REQUEST ON DOWNLOAD ENDPOINT ===');
  try {
    final downloadUri = Uri.parse(downloadUrl);
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Referer': 'https://h5.aoneroom.com/movies/$detailPath',
      'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"${DateTime.now().millisecondsSinceEpoch}"}',
      'Authorization': 'Bearer $token',
    };
    final payload = {
      'subjectId': subjectId,
      'se': 0,
      'ep': 0,
    };

    final response = await http.post(downloadUri, headers: headers, body: json.encode(payload)).timeout(const Duration(seconds: 10));
    print('POST Response code: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final downloadsList = data['data']?['downloads'] as List? ?? [];
      for (var d in downloadsList) {
        print('POST Download: ${d['resolution']}p, URL: ${d['url']}');
      }
    }
  } catch (e) {
    print('POST failed: $e');
  }
}
