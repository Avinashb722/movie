import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String authUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest';
const String searchUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search';
const String downloadUrl = 'https://h5.aoneroom.com/wefeed-h5-bff/web/subject/download';

const String mobileUA = 'Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36';

Future<void> main() async {
  print('=== STEP 1: WARMING GUEST TOKEN WITH MOBILE UA ===');
  String? token;
  try {
    final uri = Uri.parse(authUrl);
    final body = json.encode({'keyword': 'avatar_${DateTime.now().millisecondsSinceEpoch}', 'perPage': 0});
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': mobileUA,
      'Referer': 'https://h5.aoneroom.com/',
      'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"${DateTime.now().millisecondsSinceEpoch}"}',
    };

    final response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
    final xUserHeader = response.headers['x-user'] ?? response.headers['X-User'];
    if (xUserHeader != null) {
      token = json.decode(xUserHeader)['token'];
      print('Token: ${token!.substring(0, 15)}...');
    }
  } catch (e) {
    print('Failed: $e');
    return;
  }

  if (token == null) return;

  print('\n=== STEP 2: SEARCHING FOR MOVIE "Karuppu" ===');
  String? subjectId;
  String? detailPath;
  try {
    final searchUri = Uri.parse(searchUrl);
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': mobileUA,
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
        print('Found: $subjectId, $detailPath');
      }
    }
  } catch (e) {
    print('Failed: $e');
  }

  if (subjectId == null) return;

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
      'User-Agent': mobileUA,
      'Referer': 'https://h5.aoneroom.com/movies/$detailPath',
      'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"${DateTime.now().millisecondsSinceEpoch}"}',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(downloadUri, headers: headers).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final downloadsList = data['data']?['downloads'] as List? ?? [];
      for (var d in downloadsList) {
        if (d is Map) downloads.add(Map<String, dynamic>.from(d));
      }
      print('Obtained ${downloads.length} links.');
    }
  } catch (e) {
    print('Failed: $e');
  }

  if (downloads.isEmpty) return;

  // Let's test the youngest link immediately!
  Map<String, dynamic>? freshDl;
  int minAge = 999999;
  for (var dl in downloads) {
    final url = dl['url'] as String? ?? '';
    final tMatch = RegExp(r'[&?]t=(\d+)').firstMatch(url);
    if (tMatch != null) {
      final t = int.parse(tMatch.group(1)!);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final age = now - t;
      if (age < minAge) {
        minAge = age;
        freshDl = dl;
      }
    }
  }

  if (freshDl == null) {
    print('No fresh link found.');
    return;
  }

  final String targetUrl = freshDl['url'] as String? ?? '';
  final int resolution = freshDl['resolution'] as int? ?? 0;
  print('\nSelected Fresh Link: ${resolution}p, Age: ${minAge}s');
  print('URL: $targetUrl');

  final uri = Uri.parse(targetUrl);
  final cases = [
    {
      'name': 'Case 1: Mobile UA, NO Referer, NO Origin, NO Auth',
      'headers': {
        'User-Agent': mobileUA,
        'Range': 'bytes=0-99',
      }
    },
    {
      'name': 'Case 2: Mobile UA, Referer h5.aoneroom.com, Origin h5.aoneroom.com',
      'headers': {
        'User-Agent': mobileUA,
        'Referer': 'https://h5.aoneroom.com/movies/$detailPath',
        'Origin': 'https://h5.aoneroom.com',
        'Range': 'bytes=0-99',
      }
    },
    {
      'name': 'Case 3: Mobile UA, Referer movieboxpro.app, Origin movieboxpro.app',
      'headers': {
        'User-Agent': mobileUA,
        'Referer': 'https://www.movieboxpro.app/',
        'Origin': 'https://www.movieboxpro.app',
        'Range': 'bytes=0-99',
      }
    },
    {
      'name': 'Case 4: Desktop UA, Referer h5.aoneroom.com, Origin h5.aoneroom.com',
      'headers': {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://h5.aoneroom.com/movies/$detailPath',
        'Origin': 'https://h5.aoneroom.com',
        'Range': 'bytes=0-99',
      }
    },
  ];

  for (var c in cases) {
    final String name = c['name'] as String;
    final Map<String, String> headers = Map<String, String>.from(c['headers'] as Map);
    try {
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      print('\n--- $name ---');
      print('Status: ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('SUCCESS! Content-Length: ${response.headers['content-length']}');
      } else {
        print('FAILED! Response headers: ${response.headers}');
        print('Body snippet: ${response.body.length > 150 ? response.body.substring(0, 150) : response.body}');
      }
    } catch (e) {
      print('\n--- $name ---');
      print('EXCEPTION: $e');
    }
  }
}
