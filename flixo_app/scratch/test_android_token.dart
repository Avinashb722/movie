import 'dart:convert';
import 'package:http/http.dart' as http;

final String _token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOjQ3MDQyMzkzMDEwOTIxNzU2NTYsImF0cCI6MywiZXh0IjoiMTc4MjY0ODU0MyIsImV4cCI6MTc5MDQyNDU0MywiaWF0IjoxNzgyNjQ4MjQzfQ.1zrqgc4ijcAbCq7M-8Nhk8Xk_W3TCLWlPnn1WVd06Gg';

Future<void> main() async {
  final headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36',
    'Referer': 'https://www.movieboxpro.app/',
    'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"1234567890"}',
    'Authorization': 'Bearer $_token',
  };

  print('=== Testing Android Warmed Token on Computer ===');
  
  // Search Blast subjects
  final searchUri = Uri.parse('https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search');
  final searchPayload = {
    'keyword': 'Blast',
    'page': 1,
    'perPage': 15,
    'subjectType': 1,
  };
  
  try {
    final searchResp = await http.post(searchUri, headers: headers, body: json.encode(searchPayload));
    if (searchResp.statusCode == 200) {
      final searchData = json.decode(searchResp.body);
      final list = searchData['data']?['items'] as List? ?? [];
      for (final first in list.take(1)) {
        final subjectId = first['subjectId']?.toString();
        print('Found: "${first['title']}", ID: $subjectId');
        if (subjectId != null) {
          // Get download info
          final downloadUri = Uri.parse('https://h5.aoneroom.com/wefeed-h5-bff/web/subject/download').replace(queryParameters: {
            'subjectId': subjectId,
            'se': '0',
            'ep': '0',
            '_t': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
          });
          
          final downloadResp = await http.get(downloadUri, headers: headers);
          if (downloadResp.statusCode == 200) {
            final dlData = json.decode(downloadResp.body);
            final downloads = dlData['data']?['downloads'] as List? ?? [];
            final hasResource = dlData['data']?['hasResource'] ?? false;
            print('Downloads Count: ${downloads.length}, HasResource: $hasResource');
            if (downloads.isNotEmpty) {
              print('SUCCESS! The Android guest token resolved download links on the computer!');
              for (final dl in downloads) {
                print('  * Resolution: ${dl['resolution']}p, URL: ${dl['url']}');
              }
            } else {
              print('Response: ${downloadResp.body}');
            }
          } else {
            print('Download API status: ${downloadResp.statusCode}');
          }
        }
      }
    } else {
      print('Search API status: ${searchResp.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
