import 'dart:convert';
import 'package:http/http.dart' as http;

final String _token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOjMwNTUwMDcwNDM4MDEzMDE5ODQsImF0cCI6MywiZXh0IjoiMTc4MjY0ODA3NyIsImV4cCI6MTc5MDQyNDA3NywiaWF0IjoxNzgyNjQ3Nzc3fQ.r_tpdF-ZqIrGbR1jFxPpbpsSdsU3i1K2iwJ0c0nAsig';

Future<void> main() async {
  final movies = [
    'Home Alone',
    'Iron Man',
    'Titanic',
    'The Matrix',
    'Avatar'
  ];

  final headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36',
    'Referer': 'https://www.movieboxpro.app/',
    'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"1234567890"}',
    'Authorization': 'Bearer $_token',
  };

  for (final movie in movies) {
    print('=== Testing MovieBox for: "$movie" ===');
    
    // Search subject
    final searchUri = Uri.parse('https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search');
    final searchPayload = {
      'keyword': movie,
      'page': 1,
      'perPage': 15,
      'subjectType': 1,
    };
    
    try {
      final searchResp = await http.post(searchUri, headers: headers, body: json.encode(searchPayload));
      if (searchResp.statusCode == 200) {
        final searchData = json.decode(searchResp.body);
        final list = searchData['data']?['items'] as List? ?? [];
        if (list.isNotEmpty) {
          final first = list.first;
          final subjectId = first['subjectId']?.toString();
          print('First match title: "${first['title']}", ID: $subjectId');
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
                print('Success! MovieBox returned links for "$movie"!');
              }
            } else {
              print('Download API status: ${downloadResp.statusCode}');
            }
          }
        } else {
          print('No search results found.');
        }
      } else {
        print('Search API status: ${searchResp.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
    print('\n');
  }
}
