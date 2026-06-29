import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String authUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest';
const String searchUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search';
const String downloadUrl = 'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/download';

Future<void> main() async {
  print('=== STEP 1: WARMING TOKEN ===');
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
      final userData = json.decode(xUserHeader);
      token = userData['token'];
      print('Token obtained successfully: ${token!.substring(0, 15)}...');
    }
  } catch (e) {
    print('Failed to warm token: $e');
    return;
  }

  if (token == null) {
    print('No token warmed.');
    return;
  }

  print('\n=== STEP 2: SEARCHING FOR MOVIE "Inception" ===');
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
      'keyword': 'Inception',
      'page': 1,
      'perPage': 15,
      'subjectType': 1,
    };

    final response = await http.post(searchUri, headers: headers, body: json.encode(payload)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['data']?['items'] as List? ?? [];
      if (items.isNotEmpty) {
        final firstItem = items.first;
        subjectId = firstItem['subjectId']?.toString();
        detailPath = firstItem['detailPath'] as String?;
        print('Found subjectId: $subjectId, detailPath: $detailPath');
      }
    }
  } catch (e) {
    print('Search failed: $e');
  }

  if (subjectId == null) {
    print('No subjectId found.');
    return;
  }

  print('\n=== STEP 3: FETCHING DOWNLOAD LINKS ===');
  List<Map<String, dynamic>> downloads = [];
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
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final downloadsList = data['data']?['downloads'] as List? ?? [];
      for (var d in downloadsList) {
        if (d is Map) {
          downloads.add(Map<String, dynamic>.from(d));
        }
      }
      print('Obtained ${downloads.length} download links.');
    } else {
      print('Download URL fetch returned ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    print('Download fetch failed: $e');
  }

  if (downloads.isEmpty) {
    print('No downloads available.');
    return;
  }

  // Print all options
  for (int i = 0; i < downloads.length; i++) {
    final dl = downloads[i];
    final url = dl['url'] as String? ?? '';
    final res = dl['resolution'];
    final tMatch = RegExp(r'[&?]t=(\d+)').firstMatch(url);
    final tValue = tMatch?.group(1) ?? 'unknown';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final age = now - (int.tryParse(tValue) ?? now);
    print('Link $i: Resolution: ${res}p, Age: ${age}s, URL: $url');
  }

  // Let's test the fresh link (pick the youngest or first one, e.g. index 0)
  final testDl = downloads.first;
  final String targetUrl = testDl['url'] as String? ?? '';
  final uri = Uri.parse(targetUrl);

  print('\n=== STEP 4: TESTING CDN ACCESS WITH DIFFERENT HEADER CONFIGURATIONS ===');

  final configurations = [
    {
      'name': 'Option A: Exact original request headers (Desktop UA, Referer h5.aoneroom.com, with Auth)',
      'headers': {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://h5.aoneroom.com/movies/$detailPath',
        'Origin': 'https://h5.aoneroom.com',
        'Authorization': 'Bearer $token',
        'Range': 'bytes=0-99',
      }
    },
    {
      'name': 'Option B: Desktop UA, Referer h5.aoneroom.com, NO Auth',
      'headers': {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://h5.aoneroom.com/movies/$detailPath',
        'Origin': 'https://h5.aoneroom.com',
        'Range': 'bytes=0-99',
      }
    },
    {
      'name': 'Option C: Mobile UA, Referer h5.aoneroom.com, NO Auth',
      'headers': {
        'User-Agent': 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36',
        'Referer': 'https://h5.aoneroom.com/movies/$detailPath',
        'Origin': 'https://h5.aoneroom.com',
        'Range': 'bytes=0-99',
      }
    },
    {
      'name': 'Option D: No Referer or Origin, Desktop UA',
      'headers': {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Range': 'bytes=0-99',
      }
    },
    {
      'name': 'Option E: No Referer, Mobile UA',
      'headers': {
        'User-Agent': 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36',
        'Range': 'bytes=0-99',
      }
    },
    {
      'name': 'Option F: No Referer, No UA (raw request)',
      'headers': {
        'Range': 'bytes=0-99',
      }
    },
    {
      'name': 'Option G: Referer movieboxpro.app, Desktop UA, NO Auth',
      'headers': {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://www.movieboxpro.app/',
        'Origin': 'https://www.movieboxpro.app',
        'Range': 'bytes=0-99',
      }
    },
  ];

  for (var config in configurations) {
    final String name = config['name'] as String;
    final Map<String, String> headers = Map<String, String>.from(config['headers'] as Map);
    try {
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      print('\n--- $name ---');
      print('Status Code: ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('SUCCESS! Content-Length: ${response.headers['content-length']}');
      } else {
        print('FAILED! Response headers: ${response.headers}');
        if (response.body.length > 200) {
          print('Body snippet: ${response.body.substring(0, 200)}');
        } else {
          print('Body: ${response.body}');
        }
      }
    } catch (e) {
      print('\n--- $name ---');
      print('EXCEPTION: $e');
    }
  }
}
