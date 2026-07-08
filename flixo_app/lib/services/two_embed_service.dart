import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Pure-Dart resolver for 2Embed streams.
/// Supports both:
///  - swish path: 2embed → streamsrcs.2embed.cc/swish → lookmovie → packed JS → HLS4/HLS2
///  - vnest path: 2embed → streamsrcs.2embed.cc/vnest → vidnest → vidnest API → decrypt → MP4/HLS
class TwoEmbedService {
  static final TwoEmbedService instance = TwoEmbedService._internal();
  void _log(String msg) { print(msg); }
  TwoEmbedService._internal();

  late final HttpClient? _client = kIsWeb ? null : (HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..badCertificateCallback = (cert, host, port) => true);

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  /// Vidnest custom base-64 alphabet for decryption (extracted from client JS)
  static const _vidnestAlphabet =
      'RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=';

  /// Vidnest API base URL and provider paths
  static const _vidnestBase = 'https://new.vidnest.fun';
  static const _vidnestProviders = [
    '/moviesapi/movie', // returns HLS streams, good multilingual
    '/allmovies/movie', // returns HLS streams from archive
    '/moviebox/movie',  // returns MP4 from hakunaymatata
    '/movies5f/movie',  // catflix
  ];

  Future<String?> resolveStreamUrl(String imdbId, [String? tmdbId]) async {
    try {
      _log('[TwoEmbedService] Resolving stream for IMDb ID: $imdbId, TMDB ID: $tmdbId');
      
      String? embedPageBody;
      if (imdbId.isNotEmpty) {
        // Step 1: Fetch 2embed page
        embedPageBody = await _fetchText(
          'https://www.2embed.cc/embed/$imdbId',
          headers: {'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8'},
        );
      }

      final List<String> combinedStreams = [];

      if (embedPageBody != null) {
        // Try swish path (Dhurandhar / LookMovie style)
        final swishResult = await _resolveSwishPath(embedPageBody);
        if (swishResult != null && swishResult.isNotEmpty) {
          combinedStreams.add(swishResult);
        }

        // Try vnest path (KGF / vidnest style)
        final vnestResult = await _resolveVnestPath(embedPageBody);
        if (vnestResult != null && vnestResult.isNotEmpty) {
          combinedStreams.add(vnestResult);
        }
      }

      // Direct fallback or additional provider check using TMDB ID if provided
      if (tmdbId != null && tmdbId.isNotEmpty) {
        _log('[TwoEmbedService] Querying vnest providers using TMDB ID: $tmdbId');
        final directVnest = await _queryVnestProviders(tmdbId);
        if (directVnest != null && directVnest.isNotEmpty) {
          combinedStreams.add(directVnest);
        }
      }

      if (combinedStreams.isNotEmpty) {
        return combinedStreams.join('||');
      }

      _log('[TwoEmbedService] No stream found via any path');
      return null;
    } catch (e) {
      _log('[TwoEmbedService] Error resolving stream: $e');
      return null;
    }
  }

  // ─── Swish Path (LookMovie → packed JS → HLS4/HLS2) ───────────────────────

  Future<String?> _resolveSwishPath(String embedPageBody) async {
    final swishRegex = RegExp(
      r'''(?:data-src|src)=["'](https://streamsrcs\.2embed\.cc/swish\?id=([^&"']+)[^"']*)['"]]?''',
      caseSensitive: false,
    );
    final swishMatch = swishRegex.firstMatch(embedPageBody);
    if (swishMatch == null) {
      _log('[TwoEmbedService] No swish ID found in 2embed page');
      return null;
    }
    final streamId = swishMatch.group(2)!;
    _log('[TwoEmbedService] Found swish streamId: $streamId');

    final lookmovieBody = await _fetchText(
      'https://lookmovie2.skin/e/$streamId',
      headers: {
        'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
        'Referer': 'https://streamsrcs.2embed.cc/',
      },
    );
    if (lookmovieBody == null) return null;

    final evalRegex = RegExp(r"eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)");
    final evalMatch = evalRegex.firstMatch(lookmovieBody);
    if (evalMatch == null) {
      _log('[TwoEmbedService] Packed JS not found in LookMovie page');
      return null;
    }

    final unpacked = _unpackJs(evalMatch.group(0)!);
    if (unpacked == null) return null;

    final hls4Match = RegExp(r'"hls4"\s*:\s*"([^"]+)"').firstMatch(unpacked);
    if (hls4Match != null) {
      final url = 'https://lookmovie2.skin${hls4Match.group(1)!}';
      _log('[TwoEmbedService] Swish → HLS4 stream: $url');
      return url;
    }

    final hls2Match = RegExp(r'"hls2"\s*:\s*"([^"]+)"').firstMatch(unpacked);
    if (hls2Match != null) {
      _log('[TwoEmbedService] Swish → HLS2 stream: ${hls2Match.group(1)!}');
      return hls2Match.group(1)!;
    }

    final m3u8Match = RegExp(r'https?://[^\s"]+\.m3u8[^\s"]*', caseSensitive: false).firstMatch(unpacked);
    if (m3u8Match != null) {
      _log('[TwoEmbedService] Swish → m3u8 fallback: ${m3u8Match.group(0)!}');
      return m3u8Match.group(0)!;
    }

    _log('[TwoEmbedService] Swish path: no stream URL in unpacked JS');
    return null;
  }

  // ─── Vnest Path (vidnest → encrypted API → decrypt → HLS/MP4) ─────────────

  Future<String?> _resolveVnestPath(String embedPageBody) async {
    // Find tmdb= parameter in the vnest URL
    final vnestRegex = RegExp(
      r'streamsrcs\.2embed\.cc/vnest\?tmdb=(\d+)',
      caseSensitive: false,
    );
    final vnestMatch = vnestRegex.firstMatch(embedPageBody);
    if (vnestMatch == null) {
      _log('[TwoEmbedService] No vnest tmdb ID found in 2embed page');
      return null;
    }
    final tmdbId = vnestMatch.group(1)!;
    _log('[TwoEmbedService] Found vnest tmdbId: $tmdbId');
    return _queryVnestProviders(tmdbId);
  }

  Future<String?> _queryVnestProviders(String tmdbId) async {
    final List<String> allStreams = [];

    for (final providerPath in _vidnestProviders) {
      final url = '$_vidnestBase$providerPath/$tmdbId';
      _log('[TwoEmbedService] Trying provider: $url');

      final body = await _fetchText(
        url,
        headers: {
          'Accept': 'application/json, */*',
          'Origin': 'https://vidnest.fun',
          'Referer': 'https://vidnest.fun/',
        },
      );
      if (body == null) continue;

      try {
        final json = jsonDecode(body) as Map<String, dynamic>;

        // Decrypt if encrypted
        final Map<String, dynamic> data;
        if (json['encrypted'] == true && json['data'] is String) {
          final decrypted = _decryptVidnest(json['data'] as String);
          final parsed = jsonDecode(decrypted);
          data = parsed is Map<String, dynamic> ? parsed : {};
        } else {
          data = json;
        }

        // Extract all streams (to support multiple separate language links)
        final streamString = _extractAllStreams(data);
        if (streamString != null && streamString.isNotEmpty) {
          allStreams.add(streamString);
        }
      } catch (e) {
        _log('[TwoEmbedService] Provider $providerPath error: $e');
      }
    }

    if (allStreams.isNotEmpty) {
      final combined = allStreams.join('||');
      _log('[TwoEmbedService] Vnest combined stream configs: $combined');
      return combined;
    }

    _log('[TwoEmbedService] Vnest path: no stream found from any provider');
    return null;
  }

  /// Extracts all HLS streams with their language metadata
  String? _extractAllStreams(Map<String, dynamic> data) {
    final List<String> parts = [];

    // Format 1: streams
    final streamsList = data['streams'];
    if (streamsList is List && streamsList.isNotEmpty) {
      for (final s in streamsList) {
        if (s is Map && s['url'] is String) {
          final url = s['url'] as String;
          if (_isValidStreamUrl(url)) {
            var appended = _appendReferer(url, s['headers'] as Map?);
            final type = (s['type'] ?? '').toString().toLowerCase();
            if (type == 'cloudflare' || url.contains('.txt') || url.contains('cf-master')) {
              appended = '$appended|use_proxy=true';
            }
            final lang = s['language'] ?? s['lang'] ?? 'Unknown';
            parts.add('$appended|language=$lang');
          }
        }
      }
    }

    // Format 2: url (MovieBox style)
    final urlList = data['url'];
    if (urlList is List && urlList.isNotEmpty) {
      for (final s in urlList) {
        if (s is Map) {
          final url = (s['link'] ?? s['url']) as String?;
          if (url != null && _isValidStreamUrl(url)) {
            final appended = _appendReferer(url, s['headers'] as Map?);
            final lang = s['lang'] ?? s['language'] ?? 'Unknown';
            final res = s['resolution'] ?? '';
            final label = res.isNotEmpty ? '$lang ($res)' : lang.toString();
            parts.add('$appended|language=$label');
          }
        }
      }
    }

    // Format 3: data.downloads (MovieBox / movies5f style)
    final dataMap = data['data'];
    if (dataMap is Map) {
      final downloadsList = dataMap['downloads'];
      if (downloadsList is List && downloadsList.isNotEmpty) {
        for (final s in downloadsList) {
          if (s is Map && s['url'] is String) {
            final url = s['url'] as String;
            if (_isValidStreamUrl(url)) {
              final appended = _appendReferer(url, s['headers'] as Map?);
              final res = s['resolution'];
              final label = res != null ? 'Multi ($res)' : 'Multi';
              parts.add('$appended|language=$label');
            }
          }
        }
      }
    }

    if (parts.isNotEmpty) {
      // Prioritize Cloudflare / use_proxy streams to the front
      parts.sort((a, b) {
        final aProxy = a.contains('|use_proxy=true');
        final bProxy = b.contains('|use_proxy=true');
        if (aProxy && !bProxy) return -1;
        if (!aProxy && bProxy) return 1;
        return 0;
      });
      return parts.join('||');
    }

    return _extractBestStream(data);
  }

  /// Checks if the stream URL is a direct media stream (m3u8, mp4, ts) rather than a web embed page
  bool _isValidStreamUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('chillx.top') || lower.contains('/v/') || lower.contains('/embed/')) {
      return false;
    }
    if (lower.contains('korso420dim.com') || lower.contains('hakunaymatata.com') || lower.contains('aoneroom.com')) {
      return true;
    }
    return lower.contains('.m3u8') || lower.contains('.mp4') || lower.contains('.ts') || lower.contains('.txt') || lower.contains('/cf-master') || lower.contains('/stream/') || lower.contains('/resource/');
  }

  String _appendReferer(String url, Map? headers) {
    if (headers != null) {
      final referer = headers['Referer'] ?? headers['referer'];
      if (referer is String && referer.isNotEmpty) {
        return '$url|referer=$referer';
      }
    }
    // Fallback referer for moviesapi (IP hosts like 185.237.x.x, 45.156.x.x)
    final lower = url.toLowerCase();
    final isIp = RegExp(r'https?://\d+\.\d+\.\d+\.\d+').hasMatch(lower);
    if (lower.contains('185.237.107.') || lower.contains('185.237.') || lower.contains('45.156.') || isIp) {
      return '$url|referer=https://vidnest.fun/';
    }
    return url;
  }

  /// Extract the best available stream URL from decoded vidnest data.
  /// Prefers: HLS m3u8 > direct MP4 (highest resolution)
  String? _extractBestStream(Map<String, dynamic> data) {
    // Format 1: {streams: [{url, type, headers}, ...]}
    final streamsList = data['streams'];
    if (streamsList is List && streamsList.isNotEmpty) {
      // First, try to find a Cloudflare / use_proxy stream
      for (final s in streamsList) {
        if (s is Map && s['url'] is String) {
          final url = s['url'] as String;
          if (_isValidStreamUrl(url)) {
            final type = (s['type'] ?? '').toString().toLowerCase();
            if (type == 'cloudflare' || url.contains('.txt') || url.contains('cf-master')) {
              return '${_appendReferer(url, s['headers'] as Map?)}|use_proxy=true';
            }
          }
        }
      }
      // Prefer HLS next
      for (final s in streamsList) {
        if (s is Map && s['url'] is String) {
          final url = s['url'] as String;
          if (_isValidStreamUrl(url)) {
            final type = (s['type'] ?? '').toString().toLowerCase();
            if (type == 'hls' || url.contains('.m3u8')) {
              return _appendReferer(url, s['headers'] as Map?);
            }
          }
        }
      }
      // Fall back to any valid URL
      for (final s in streamsList) {
        if (s is Map && s['url'] is String) {
          final url = s['url'] as String;
          if (_isValidStreamUrl(url)) {
            return _appendReferer(url, s['headers'] as Map?);
          }
        }
      }
    }

    // Format 2: {url: [{link, resolution, type, headers}, ...]}
    final urlList = data['url'];
    if (urlList is List && urlList.isNotEmpty) {
      // Sort by resolution descending, pick highest
      final sorted = List<Map<String, dynamic>>.from(
        urlList.whereType<Map<String, dynamic>>().where((e) => e['link'] is String && _isValidStreamUrl(e['link'] as String)),
      )..sort((a, b) {
          final ra = int.tryParse(((a['resolution'] ?? '0').toString()).replaceAll(RegExp(r'\D'), '')) ?? 0;
          final rb = int.tryParse(((b['resolution'] ?? '0').toString()).replaceAll(RegExp(r'\D'), '')) ?? 0;
          return rb.compareTo(ra);
        });
      if (sorted.isNotEmpty) {
        final best = sorted.first;
        return _appendReferer(best['link'] as String, best['headers'] as Map?);
      }
    }

    // Format 3: {data: {stream: {playlist: ..., headers: ...}}}
    final innerData = data['data'];
    if (innerData is Map<String, dynamic>) {
      final stream = innerData['stream'];
      if (stream is Map<String, dynamic> && stream['playlist'] is String) {
        final url = stream['playlist'] as String;
        if (_isValidStreamUrl(url)) {
          return _appendReferer(url, (stream['headers'] ?? innerData['headers'] ?? data['headers']) as Map?);
        }
      }
      // hakunaymatata: direct url list
      final dataUrl = innerData['url'];
      if (dataUrl is List && dataUrl.isNotEmpty) {
        for (final first in dataUrl) {
          if (first is Map) {
            final link = (first['url'] ?? first['link']) as String?;
            if (link != null && _isValidStreamUrl(link)) {
              return _appendReferer(link, (first['headers'] ?? innerData['headers']) as Map?);
            }
          }
        }
      }
    }

    return null;
  }

  // ─── Vidnest Decryption ────────────────────────────────────────────────────

  /// Decrypts vidnest encrypted stream response using the custom base64 alphabet.
  String _decryptVidnest(String data) {
    final lookup = <String, int>{};
    for (int i = 0; i < _vidnestAlphabet.length; i++) {
      lookup[_vidnestAlphabet[i]] = i;
    }

    final result = <int>[];
    for (int t = 0; t < data.length; t += 4) {
      var chunk = data.substring(t, (t + 4).clamp(0, data.length));
      while (chunk.length < 4) { chunk += '='; }

      final indices = <int>[];
      for (int e = 0; e < 4; e++) {
        indices.add(lookup[chunk[e]] ?? 64);
      }

      result.add((indices[0] << 2) | (indices[1] >> 4));
      if (indices[2] != 64) {
        result.add(((indices[1] & 15) << 4) | (indices[2] >> 2));
      }
      if (indices[3] != 64) {
        result.add(((indices[2] & 3) << 6) | indices[3]);
      }
    }

    return utf8.decode(result, allowMalformed: true);
  }

  // ─── HTTP Helper ──────────────────────────────────────────────────────────

  Future<String?> _fetchText(String url, {Map<String, String> headers = const {}}) async {
    try {
      if (kIsWeb) {
        // Route web requests through corsproxy.io CORS proxy to bypass browser CORS blocks
        final String proxyUrl = 'https://corsproxy.io/?url=${Uri.encodeComponent(url)}';
        _log('[TwoEmbedService] Web fetching via corsproxy.io: $proxyUrl');
        try {
          final response = await http.get(Uri.parse(proxyUrl));
          // Accept both 200 and 403 statuses for Lookmovie because it serves the HTML even on 403
          final bool isValidStatus = response.statusCode == 200 || 
              (url.contains('lookmovie') && response.statusCode == 403 && response.body.contains('eval(function'));
              
          if (isValidStatus) {
            return response.body;
          }
          _log('[TwoEmbedService] Web HTTP ${response.statusCode} fetching $url via corsproxy.io. Trying Vercel proxy fallback...');
        } catch (err) {
          _log('[TwoEmbedService] corsproxy.io proxy request failed: $err. Trying Vercel proxy fallback...');
        }

        // Vercel proxy fallback
        try {
          String vercelProxyUrl = 'https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(url)}';
          if (headers.containsKey('Referer')) {
            vercelProxyUrl += '&referer=${Uri.encodeComponent(headers['Referer']!)}';
          }
          _log('[TwoEmbedService] Web fetching via Vercel proxy: $vercelProxyUrl');
          // Forward custom headers mapping (Accept, Origin, etc.)
          final Map<String, String> finalHeaders = {
            ...headers,
            'User-Agent': _userAgent,
          };
          final response = await http.get(Uri.parse(vercelProxyUrl), headers: finalHeaders);
          final bool isValidStatus = response.statusCode == 200 || 
              (url.contains('lookmovie') && response.statusCode == 403 && response.body.contains('eval(function'));
          if (isValidStatus) {
            return response.body;
          }
          _log('[TwoEmbedService] Web HTTP ${response.statusCode} fetching $url via Vercel proxy');
        } catch (e) {
          _log('[TwoEmbedService] Vercel proxy fallback failed: $e');
        }
        return null;
      }
      
      final uri = Uri.parse(url);
      final req = await _client!.getUrl(uri);
      req.headers.set('User-Agent', _userAgent);
      for (final entry in headers.entries) {
        req.headers.set(entry.key, entry.value);
      }
      final resp = await req.close();
      if (resp.statusCode >= 400) {
        _log('[TwoEmbedService] HTTP ${resp.statusCode} fetching $url');
        return null;
      }
      return await resp.transform(utf8.decoder).join();
    } catch (e) {
      _log('[TwoEmbedService] Fetch error for $url: $e');
      return null;
    }
  }

  // ─── JS Unpacker ──────────────────────────────────────────────────────────

  /// Pure Dart port of Dean Edwards' JavaScript p,a,c,k,e,d unpacker.
  String? _unpackJs(String packedCode) {
    try {
      final argsRegex = RegExp(
        r"\}\s*\(\s*'([\s\S]*)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([\s\S]*)'\s*\.\s*split\s*\(\s*'\|'\s*\)\s*\)",
      );
      final match = argsRegex.firstMatch(packedCode);
      if (match == null) return null;

      final payload = match.group(1)!;
      final int radix = int.parse(match.group(2)!);
      final wordsList = match.group(4)!.split('|');

      String unbase(String str) {
        const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
        var result = 0;
        for (int i = 0; i < str.length; i++) {
          final c = str[str.length - 1 - i];
          final pos = chars.indexOf(c);
          if (pos < 0) return str;
          result += pos * _pow(radix, i);
        }
        return result.toString();
      }

      final tokenRegex = RegExp(r'\b\w+\b');
      return payload.replaceAllMapped(tokenRegex, (m) {
        final token = m.group(0)!;
        final idx = int.tryParse(unbase(token));
        if (idx != null && idx < wordsList.length && wordsList[idx].isNotEmpty) {
          return wordsList[idx];
        }
        return token;
      });
    } catch (e) {
      _log('[TwoEmbedService] Unpack error: $e');
      return null;
    }
  }

  int _pow(int base, int exponent) {
    if (exponent == 0) return 1;
    int result = 1;
    for (int i = 0; i < exponent; i++) { result *= base; }
    return result;
  }
}
