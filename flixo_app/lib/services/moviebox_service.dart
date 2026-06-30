import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MovieBoxStream {
  final String url;
  final int resolution;
  final String size;
  final String language;
  final String referer;
  final String subjectId;
  final String detailPath;

  const MovieBoxStream({
    required this.url,
    required this.resolution,
    required this.size,
    this.language = 'English',
    this.referer = '',
    required this.subjectId,
    required this.detailPath,
  });
}

class MovieBoxService {
  static const String _searchUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search';
  // The /play endpoint returns streams/hls/dash arrays (works with both guest & VIP tokens)
  // The /download endpoint only returns download links for VIP tokens, so we avoid it
  static const String _playUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/play';
  static const String _authUrl = 'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest';

  static String? _token;
  static String? get token => _token;

  // We MUST use Android headers on both Android and Windows: Aoneroom servers block free desktop/web guest tokens,
  // but allow free mobile app guest tokens to fetch SD/HD streams.
  static String get _userAgent => 'okhttp/4.10.0';
  static String get _referer => 'https://www.movieboxpro.app/';

  // Generates or retrieves a persistent static device ID to prevent bot detection flags on the backend
  static Future<String> _getPersistentDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('moviebox_device_id');
    if (deviceId == null || deviceId.isEmpty) {
      final rand = math.Random();
      final hexChars = '0123456789abcdef';
      final buffer = StringBuffer();
      for (int i = 0; i < 16; i++) {
        buffer.write(hexChars[rand.nextInt(16)]);
      }
      deviceId = buffer.toString();
      await prefs.setString('moviebox_device_id', deviceId);
      debugPrint('[MovieBox] Generated new persistent device ID: $deviceId');
    }
    return deviceId;
  }

  // Sends a POST request, trying direct connection first on native to get IP-matching signatures,
  // and proxy first on web to bypass CORS.
  static Future<http.Response> _sendPostWithFailover(Uri uri, Map<String, String> headers, String body) async {
    final bool isApiRequest = uri.toString().contains('/subject/');
    final bool isMovieBoxStream = (uri.host.contains('aoneroom.com') || uri.host.contains('hakunaymatata.com')) &&
                                  !uri.host.contains('h5-api.aoneroom.com');

    // 1. On Web: CORS requires us to route API/metadata requests through the local proxy
    if (kIsWeb && isApiRequest) {
      try {
        final localProxyUri = Uri.parse('https://corsproxy.io/?url=${Uri.encodeComponent(uri.toString())}');
        final proxyHeaders = Map<String, String>.from(headers);
        if (headers.containsKey('Referer')) {
          proxyHeaders['X-App-Referer'] = headers['Referer']!;
        } else if (headers.containsKey('referer')) {
          proxyHeaders['X-App-Referer'] = headers['referer']!;
        }
        final resp = await http.post(localProxyUri, headers: proxyHeaders, body: body).timeout(const Duration(seconds: 10));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          return resp;
        }
      } catch (e) {
        debugPrint('[MovieBox] Web local proxy POST failed: $e');
      }
    }

    // 2. Try Direct connection (Native, or Web proxy fallback)
    try {
      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return resp;
      }
      throw Exception('Direct POST returned status ${resp.statusCode}');
    } catch (e) {
      debugPrint('[MovieBox] Direct POST failed: $e. Trying Vercel proxy...');
    }

    // 3. Fallback: Vercel proxy (only for non-stream URLs to prevent blocks)
    if (isMovieBoxStream) {
      throw Exception('POST request failed direct. Bypassing public proxies for media streams.');
    }

    try {
      final unblockUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(uri.toString())}');
      final resp = await http.post(unblockUri, headers: headers, body: body).timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return resp;
      }
      throw Exception('Vercel Proxy POST returned status ${resp.statusCode}');
    } catch (e2) {
      debugPrint('[MovieBox] Vercel Proxy failed: $e2. Trying corsproxy.io...');
      final unblockUri2 = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(uri.toString())}');
      return await http.post(unblockUri2, headers: headers, body: body).timeout(const Duration(seconds: 8));
    }
  }

  // Sends a GET request, trying direct connection first on native to get IP-matching signatures,
  // and proxy first on web to bypass CORS.
  static Future<http.Response> _sendGetWithFailover(Uri uri, Map<String, String> headers) async {
    // 1. On Web: CORS requires us to try proxies first
    final bool isMovieBoxStream = (uri.host.contains('aoneroom.com') || uri.host.contains('hakunaymatata.com')) &&
                                  !uri.host.contains('h5-api.aoneroom.com');
    final bool isArchive = uri.host.contains('archive.org');

    if (kIsWeb) {
      if (isArchive) {
        // Always route Archive.org requests through the Cloudflare Worker to bypass ISP block
        try {
          final cfProxy = 'https://long-wind-ad98.avinashbiradar722.workers.dev/';
          final proxyUri = Uri.parse('$cfProxy?url=${Uri.encodeComponent(uri.toString())}');
          final resp = await http.get(proxyUri, headers: headers).timeout(const Duration(seconds: 10));
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            return resp;
          }
        } catch (e) {
          debugPrint('[MovieBox] Web CF proxy GET failed for Archive: $e');
        }
      } else if (!isMovieBoxStream) {
        // Always route MovieBox API requests through corsproxy.io
        try {
          final localProxyUri = Uri.parse('https://corsproxy.io/?url=${Uri.encodeComponent(uri.toString())}');
          final proxyHeaders = Map<String, String>.from(headers);
          if (headers.containsKey('Referer')) {
            proxyHeaders['X-App-Referer'] = headers['Referer']!;
          } else if (headers.containsKey('referer')) {
            proxyHeaders['X-App-Referer'] = headers['referer']!;
          }
          final resp = await http.get(localProxyUri, headers: proxyHeaders).timeout(const Duration(seconds: 10));
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            return resp;
          }
        } catch (e) {
          debugPrint('[MovieBox] Web Local proxy GET failed for MovieBox: $e');
        }
      }
    }

    // 2. Try Direct connection (Native, or Web proxy fallback)
    try {
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return resp;
      }
      throw Exception('Direct GET returned status ${resp.statusCode}');
    } catch (e) {
      debugPrint('[MovieBox] Direct GET failed: $e. Trying Vercel proxy...');
    }

    // 3. Fallback: Vercel proxy (only for non-aoneroom/non-archive streams to prevent blocks)
    if (isMovieBoxStream || isArchive) {
      throw Exception('GET request failed direct and proxy. Bypassing public proxies.');
    }

    try {
      final unblockUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(uri.toString())}');
      final resp = await http.get(unblockUri, headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return resp;
      }
      throw Exception('Vercel Proxy GET returned status ${resp.statusCode}');
    } catch (e2) {
      debugPrint('[MovieBox] Vercel Proxy GET failed: $e2. Trying corsproxy.io...');
      final unblockUri2 = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(uri.toString())}');
      return await http.get(unblockUri2, headers: headers).timeout(const Duration(seconds: 8));
    }
  }

  // Warm token to obtain the Bearer token in the x-user response header.
  // On Windows: uses curl.exe which has a different TLS fingerprint than Dart's http client.
  // Android/iOS/Web: uses Dart's http client directly (already gets mobile atp tokens).
  static Future<void> _warmToken(String deviceId) async {
    try {
      final uri = Uri.parse(_authUrl);
      final body = json.encode({'keyword': 'avatar_${DateTime.now().millisecondsSinceEpoch}', 'perPage': 0});
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'MovieBox/3.1.2 (Android 13)',
        'Referer': _referer,
        'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"$deviceId","os":"android","version":"3.1.2"}',
      };

      http.Response? response;

      // On Windows, try curl.exe first — it has a different TLS fingerprint (Schannel/OpenSSL)
      // that the MovieBox server may classify as a mobile client (atp:1/2) instead of web (atp:3).
      if (!kIsWeb && Platform.isWindows) {
        try {
          response = await _warmTokenViaCurl(uri.toString(), body, headers, deviceId);
        } catch (e) {
          debugPrint('[MovieBox] curl.exe token warming failed, falling back to Dart HTTP: $e');
        }
      }

      // Fall back to Dart HTTP with Vercel proxy failover
      if (response == null) {
        response = await _sendPostWithFailover(uri, headers, body);
      }
          
      if (response.statusCode == 200) {
        final xUserHeader = response.headers['x-user'] ?? response.headers['X-User'] ?? response.headers['x-user'];
        if (xUserHeader != null) {
          final userData = json.decode(xUserHeader);
          final token = userData['token'];
          if (token != null) {
            _token = token;
            // Check atp value to know if we got a mobile or web token
            try {
              final parts = (token as String).split('.');
              final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
              final payloadData = json.decode(payload);
              final atp = payloadData['atp'];
              debugPrint('[MovieBox] Token warmed successfully (atp=$atp) — ${atp == 3 ? "web token (streams may be limited)" : "mobile token (free streams available)"}');
            } catch (_) {
              debugPrint('[MovieBox] Token warmed successfully');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[MovieBox] Token warming error: $e');
    }
  }

  /// Uses curl.exe on Windows to make the auth POST request.
  /// curl has a different TLS fingerprint than Dart's HTTP client,
  /// which may result in getting an atp:1 (mobile) token from the server.
  static Future<http.Response?> _warmTokenViaCurl(
    String url, String body, Map<String, String> headers, String deviceId) async {
    // Build curl command with Android-like TLS options
    final List<String> curlArgs = [
      '-s',                        // silent
      '-X', 'POST',
      url,
      '-H', 'Accept: application/json',
      '-H', 'Content-Type: application/json',
      '-H', 'User-Agent: $_userAgent',
      '-H', 'Referer: $_referer',
      '-H', 'X-Client-Info: {"timezone":"Asia/Kolkata","device_id":"$deviceId"}',
      '-d', body,
      '-D', '-',                   // dump headers to stdout (before body)
      '--tlsv1.2',                 // minimum TLS 1.2 like Android
      '--tls-max', '1.3',          // allow up to TLS 1.3
      '--connect-timeout', '10',
      '--max-time', '12',
    ];

    final result = await Process.run('curl.exe', curlArgs).timeout(const Duration(seconds: 15));
    if (result.exitCode != 0) {
      throw Exception('curl.exe exited with code ${result.exitCode}: ${result.stderr}');
    }

    final output = result.stdout as String;
    // curl -D - dumps: HTTP/1.1 200 OK\r\n<headers>\r\n\r\n<body>
    // Split on the blank line between headers and body
    final blankLineIdx = output.indexOf('\r\n\r\n');
    if (blankLineIdx == -1) throw Exception('curl output malformed — no header/body separator');

    final headerSection = output.substring(0, blankLineIdx);
    final responseBody = output.substring(blankLineIdx + 4);

    // Parse status code from first line (e.g. "HTTP/1.1 200 OK")
    final statusMatch = RegExp(r'HTTP/[\d.]+ (\d+)').firstMatch(headerSection);
    final statusCode = int.tryParse(statusMatch?.group(1) ?? '0') ?? 0;

    // Parse headers — look for x-user
    final parsedHeaders = <String, String>{};
    for (final line in headerSection.split('\r\n').skip(1)) {
      final colon = line.indexOf(':');
      if (colon == -1) continue;
      final key = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      parsedHeaders[key] = value;
    }

    debugPrint('[MovieBox] curl.exe auth status: $statusCode, x-user present: ${parsedHeaders.containsKey("x-user")}');

    // Build a fake http.Response so the caller can parse it uniformly
    return http.Response(responseBody, statusCode, headers: parsedHeaders);
  }

  // Helper to check if a JWT token is expired (using exp claim)
  static bool _isTokenOld(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      // Decode the payload (second part of JWT)
      final String normalized = base64Url.normalize(parts[1]);
      final String payload = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> data = json.decode(payload);
      
      final exp = data['exp'] as int?;
      if (exp == null) return true;
      
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Consider token old if it expires in less than 5 minutes (300 seconds)
      return exp - now < 300;
    } catch (e) {
      debugPrint('[MovieBox] Error parsing token age: $e');
      return true;
    }
  }

  static Future<List<MovieBoxStream>> resolveStreams(
    String title, {
    int? tmdbId,
    String? imdbId,
  }) async {
    final List<MovieBoxStream> allStreams = [];
    
    final logFile = File('C:/Users/Hp/.gemini/antigravity-ide/brain/beaaf5ff-4bbb-4179-8f14-fa28ed772630/moviebox_logs.txt');
    void log(String msg) {
      debugPrint('[MovieBoxLog] $msg');
      try {
        logFile.writeAsStringSync('$msg\n', mode: FileMode.append);
      } catch (_) {}
    }

    try {
      log('--- NEW RESOLVE STREAMS CALL ---');
      log('Title: $title, tmdbId: $tmdbId, imdbId: $imdbId');
      
      final deviceId = await _getPersistentDeviceId();
      
      // Check if user has saved a valid, fresh token in settings
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('aoneroom_token');
      if (savedToken != null && savedToken.isNotEmpty) {
        if (!_isTokenOld(savedToken)) {
          _token = savedToken;
          log('Using valid token from settings: ${_token!.substring(0, 10)}...');
        } else {
          log('Saved VIP token is expired. Falling back to guest mode.');
          _token = null;
          await _warmToken(deviceId);
        }
      } else {
        // In Guest Mode: Reuse token as long as it's not expired to prevent spamming Aoneroom
        // backend which triggers IP rate limits / shadowban.
        bool isWebToken = false;
        if (_token != null) {
          try {
            final parts = _token!.split('.');
            final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
            final payloadData = json.decode(payload);
            if (payloadData['atp'] == 3) isWebToken = true;
          } catch (_) {}
        }

        if (_token != null && !_isTokenOld(_token!) && (!Platform.isAndroid || !isWebToken)) {
          log('Using cached guest token: ${_token!.substring(0, 10)}...');
        } else {
          log('Guest token missing, expired, or web-level on Android. Warming fresh guest token.');
          _token = null;
          await _warmToken(deviceId);
        }
        log('Token after warmToken: ${_token != null ? "${_token!.substring(0, 10)}..." : "null"}');
      }

      if (_token != null) {
        debugPrint('=========================================');
        debugPrint('[MovieBox] COPY THIS TOKEN FOR WEB SETTINGS:');
        debugPrint(_token);
        debugPrint('=========================================');
      }

      debugPrint('[MovieBox] Resolving streams for: $title (Token: ${_token != null ? "${_token!.substring(0, 10)}..." : "null"})');
      if (_token == null) {
        log('Cannot search, no token available.');
        return [];
      }

      // 1. Gather subjects across base title and language variations
      final List<String> searchKeywords = [title, '$title Hindi', '$title Tamil', '$title Telugu'];
      final List<Map<String, dynamic>> matchingSubjects = [];
      final Set<String> addedSubjectIds = {};

      for (final kw in searchKeywords) {
        log('Searching with query: "$kw"');
        try {
          final searchUri = Uri.parse(_searchUrl);
          final searchHeaders = {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent': _userAgent,
            'Referer': _referer,
            'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"$deviceId"}',
            'Authorization': 'Bearer $_token',
          };
          
          final searchPayload = {
            'keyword': kw,
            'page': 1,
            'perPage': 15,
            'subjectType': 1,
          };

          http.Response response = await _sendPostWithFailover(searchUri, searchHeaders, json.encode(searchPayload));

          if (response.statusCode == 200) {
            final searchData = json.decode(response.body);
            final items = (searchData['data'] != null ? searchData['data']['items'] : []) as List? ?? [];
            final queryNorm = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

            for (var item in items) {
              if (item is Map) {
                final subjectId = item['subjectId']?.toString();
                if (subjectId != null && !addedSubjectIds.contains(subjectId)) {
                  final itemTitle = item['title'] as String? ?? '';
                  final itemNorm = itemTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

                  if (itemNorm.contains(queryNorm) || queryNorm.contains(itemNorm)) {
                    addedSubjectIds.add(subjectId);
                    final Map<String, dynamic> subjMap = Map<String, dynamic>.from(item);
                    subjMap['_queryLanguage'] = kw.replaceAll(title, '').trim();
                    matchingSubjects.add(subjMap);
                  }
                }
              }
            }
          }
        } catch (e) {
          log('Search Exception for "$kw": $e');
        }
      }
      log('Total unique matching subjects count: ${matchingSubjects.length}');

      if (matchingSubjects.isEmpty) {
        log('No matching subjects found for: $title');
        return [];
      }

      // Resolve downloads for each unique subject concurrently
      final resolveTasks = matchingSubjects.take(12).map((subj) async {
        final subjectId = subj['subjectId']?.toString();
        final detailPath = subj['detailPath'] as String? ?? '';
        log('Resolving subjectId: $subjectId, detailPath: $detailPath');
        if (subjectId == null) return <MovieBoxStream>[];

        final queryLanguage = subj['_queryLanguage'] as String? ?? '';
        final subjectTitle = subj['title'] as String? ?? '';
        
        String finalLanguage = queryLanguage;
        if (finalLanguage.isEmpty) {
          final titleStr = subjectTitle.toLowerCase();
          if (titleStr.contains('hindi')) {
            finalLanguage = 'Hindi';
          } else if (titleStr.contains('tamil')) {
            finalLanguage = 'Tamil';
          } else if (titleStr.contains('telugu')) {
            finalLanguage = 'Telugu';
          } else if (titleStr.contains('kannada')) {
            finalLanguage = 'Kannada';
          } else if (titleStr.contains('malayalam')) {
            finalLanguage = 'Malayalam';
          } else if (titleStr.contains('bengali')) {
            finalLanguage = 'Bengali';
          } else if (titleStr.contains('english')) {
            finalLanguage = 'English';
          }
        }

        try {
          // Use the /play endpoint which works for both guest (mobile) and VIP tokens
          // and returns streams/hls/dash arrays instead of download-only links
          final resolutions = [360, 480, 720, 1080];
          final List<MovieBoxStream> subjectStreams = [];

          for (final res in resolutions) {
            final playUri = Uri.parse(_playUrl).replace(queryParameters: {
              'subjectId': subjectId,
              'se': '0',
              'ep': '0',
              'resolution': res.toString(),
            });

            final playHeaders = {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'User-Agent': _userAgent,
              'Referer': _referer,
              'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"$deviceId"}',
              'Authorization': 'Bearer $_token',
              'Cache-Control': 'no-cache, no-store, must-revalidate',
            };

            http.Response playResponse = await _sendGetWithFailover(playUri, playHeaders);

            log('Subject $subjectId [${res}p] HTTP Response Status: ${playResponse.statusCode}');
            if (playResponse.statusCode == 200) {
              final playData = json.decode(playResponse.body);
              final dataObj = playData['data'] as Map? ?? {};
              
              // Try streams[] first, then hls[], then dash[]
              final streamsList = dataObj['streams'] as List? ?? [];
              final hlsList = dataObj['hls'] as List? ?? [];

              log('Subject $subjectId [${res}p]: ${streamsList.length} streams, ${hlsList.length} hls, hasResource=${dataObj["hasResource"]}');

              for (var stream in [...streamsList, ...hlsList]) {
                if (stream is! Map) continue;
                final url = stream['url'] as String? ?? stream['playUrl'] as String? ?? '';
                if (url.isEmpty) continue;

                subjectStreams.add(MovieBoxStream(
                  url: url,
                  resolution: res,
                  size: '',
                  language: finalLanguage.isNotEmpty ? finalLanguage : (stream['lang'] ?? stream['language'] ?? 'English'),
                  referer: 'https://h5.aoneroom.com/movies/$detailPath',
                  subjectId: subjectId,
                  detailPath: detailPath,
                ));
              }
            } else {
              log('Subject $subjectId [${res}p] error: ${playResponse.body}');
            }
          }

          // Fallback: If /play returned no streams, query /download endpoint for direct MP4 links
          if (subjectStreams.isEmpty) {
            log('Subject $subjectId: /play streams empty. Fetching /download fallback...');
            final downloadUri = Uri.parse('https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/download').replace(queryParameters: {
              'subjectId': subjectId,
              'se': '0',
              'ep': '0',
            });
            final dlHeaders = {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'User-Agent': _userAgent,
              'Referer': _referer,
              'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"$deviceId"}',
              'Authorization': 'Bearer $_token',
            };

            http.Response dlResponse = await _sendGetWithFailover(downloadUri, dlHeaders);

            if (dlResponse.statusCode == 200) {
              final dlData = json.decode(dlResponse.body);
              final downloads = (dlData['data'] != null ? dlData['data']['downloads'] : []) as List? ?? [];
              log('Subject $subjectId /download fallback returned ${downloads.length} items');
              for (var item in downloads) {
                if (item is Map) {
                  final url = item['url'] as String? ?? '';
                  final res = item['resolution'] as int? ?? 720;
                  if (url.isNotEmpty) {
                    subjectStreams.add(MovieBoxStream(
                      url: url,
                      resolution: res,
                      size: '',
                      language: finalLanguage,
                      referer: 'https://h5.aoneroom.com/movies/$detailPath',
                      subjectId: subjectId,
                      detailPath: detailPath,
                    ));
                  }
                }
              }
            }
          }
          return subjectStreams;
        } catch (e) {
          log('Resolve streams for subject $subjectId error: $e');
        }
        return <MovieBoxStream>[];
      });

      final resolveResults = await Future.wait(resolveTasks);
      for (var list in resolveResults) {
        allStreams.addAll(list);
      }

      // Deduplicate
      final seenUrls = <String>{};
      final uniqueStreams = <MovieBoxStream>[];
      for (var stream in allStreams) {
        if (seenUrls.add(stream.url)) {
          uniqueStreams.add(stream);
        }
      }
      return uniqueStreams;
    } catch (e) {
      debugPrint('[MovieBox] resolve streams total error: $e');
      return [];
    }
  }

  /// Re-fetches a fresh signed URL immediately before playback.
  /// The hakunaymatata CDN signs URLs with a short TTL (~5 min).
  /// Call this right before navigating to PlayerScreen.
  static Future<MovieBoxStream> refreshUrl(MovieBoxStream stream) async {
    if (stream.subjectId.isEmpty) return stream;
    try {
      final deviceId = await _getPersistentDeviceId();
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('aoneroom_token');
      
      if (savedToken != null && savedToken.isNotEmpty) {
        if (!_isTokenOld(savedToken)) {
          _token = savedToken;
        } else {
          _token = null;
          await _warmToken(deviceId);
        }
      } else {
        // Guest mode: Reuse guest token as long as it's not expired
        if (_token == null || _isTokenOld(_token!)) {
          _token = null;
          await _warmToken(deviceId);
        }
      }
      if (_token == null) return stream;

      final playUri = Uri.parse(_playUrl).replace(queryParameters: {
        'subjectId': stream.subjectId,
        'se': '0',
        'ep': '0',
        'resolution': stream.resolution.toString(),
      });
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': _userAgent,
        'Referer': _referer,
        'X-Client-Info': '{"timezone":"Asia/Kolkata","device_id":"$deviceId"}',
        'Authorization': 'Bearer $_token',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
      };
      
       http.Response resp = await _sendGetWithFailover(playUri, headers);
      
      debugPrint('[MovieBox] refreshUrl API status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        debugPrint('[MovieBox] refreshUrl body: ${resp.body}');
        final data = json.decode(resp.body);
        final downloads = (data['data']?['downloads'] as List?) ?? [];
        debugPrint('[MovieBox] refreshUrl got ${downloads.length} download links');
        // Try matching resolution first
        for (var dl in downloads) {
          if (dl is! Map) continue;
          final res = dl['resolution'] as int? ?? 0;
          if (res == stream.resolution) {
            final url = dl['url'] as String? ?? '';
            if (url.isNotEmpty) {
              // Extract the t= parameter to verify freshness
              final tMatch = RegExp(r'[&?]t=(\d+)').firstMatch(url);
              final tValue = tMatch?.group(1) ?? 'unknown';
              final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              debugPrint('[MovieBox] Refreshed URL t=$tValue (now=$now, age=${now - (int.tryParse(tValue) ?? now)}s) for ${stream.resolution}p');
              return MovieBoxStream(
                url: url,
                resolution: stream.resolution,
                size: stream.size,
                language: stream.language,
                referer: stream.referer,
                subjectId: stream.subjectId,
                detailPath: stream.detailPath,
              );
            }
          }
        }
        
        // Fallback: Pick the first available URL from the list so it is at least fresh
        for (var dl in downloads) {
          if (dl is! Map) continue;
          final url = dl['url'] as String? ?? '';
          if (url.isNotEmpty) {
            final res = dl['resolution'] as int? ?? stream.resolution;
            debugPrint('[MovieBox] Refreshed URL using fallback resolution: ${res}p');
            return MovieBoxStream(
              url: url,
              resolution: res,
              size: stream.size,
              language: stream.language,
              referer: stream.referer,
              subjectId: stream.subjectId,
              detailPath: stream.detailPath,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[MovieBox] refreshUrl error: $e');
    }
    return stream;
  }
}
