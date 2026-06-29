import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WatchoStream {
  final String label;
  final String url;
  final String partner;
  final String language;

  const WatchoStream({
    required this.label,
    required this.url,
    required this.partner,
    required this.language,
  });
}

class WatchoService {
  // Hardcoded working defaults to support direct playback for all distributed users
  static const String _defaultSessionId = '9b6b3a731c567eb32f0c';
  static const String _defaultBoxId = 'e47683dc-31fd-d916-981a-47aad2dc9649';

  static String _slugify(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }

  // Sends a GET request with clean CORS proxy fallback on Web
  static Future<http.Response> _sendGetWithFailover(Uri uri, Map<String, String> headers) async {
    final prefs = await SharedPreferences.getInstance();
    final cfProxy = prefs.getString('cloudflare_proxy_url') ?? '';

    // 1. On Web: Try proxy first to bypass CORS
    if (kIsWeb) {
      // Try corsproxy.io first
      try {
        final localProxyUri = Uri.parse('https://corsproxy.io/?url=${Uri.encodeComponent(uri.toString())}');
        final resp = await http.get(localProxyUri, headers: headers).timeout(const Duration(seconds: 10));
        if (resp.statusCode >= 200 && resp.statusCode < 300) return resp;
      } catch (e) {
        debugPrint('[Watcho] corsproxy.io proxy GET failed: $e');
      }

      // Try Cloudflare Proxy if set
      if (cfProxy.isNotEmpty) {
        try {
          final proxyUri = Uri.parse('$cfProxy?url=${Uri.encodeComponent(uri.toString())}');
          final resp = await http.get(proxyUri, headers: headers).timeout(const Duration(seconds: 10));
          if (resp.statusCode >= 200 && resp.statusCode < 300) return resp;
        } catch (e) {
          debugPrint('[Watcho] CF proxy GET failed: $e');
        }
      }

      // Try public fallback proxy
      try {
        final publicProxyUri = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(uri.toString())}');
        return await http.get(publicProxyUri, headers: headers).timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[Watcho] Public proxy GET failed: $e');
      }
    }

    // 2. On Native (or fallbacks): Try direct call
    return await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
  }

  /// Performs a search on Watcho Search API to dynamically lookup the correct content slug
  static Future<String?> _findSlugBySearch(String title, String sessionId, String boxId) async {
    final queryUrl = 'https://dishtv-searchapi.revlet.net/search/api/v3/get/search/query?query=${Uri.encodeComponent(title)}&pageSize=36&last_search_order=typesense&bucket=all';

    final headers = {
      'Accept': 'application/json, text/plain, */*',
      'Session-Id': sessionId,
      'Box-Id': boxId,
      'Tenant-Code': 'dishtv',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Origin': 'https://www.watcho.com',
      'Referer': 'https://www.watcho.com/',
    };

    try {
      debugPrint('[Watcho] Performing search lookup for title: "$title"');
      final response = await _sendGetWithFailover(Uri.parse(queryUrl), headers);
      if (response.statusCode != 200) {
        debugPrint('[Watcho] Search lookup failed with status: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      if (data['status'] != true) {
        debugPrint('[Watcho] Search API status is false');
        return null;
      }

      final searchResults = data['response']?['searchResults'] ?? {};
      final dataList = searchResults['data'] as List? ?? [];

      // 1st pass: exact title match
      for (final item in dataList) {
        final itemTitle = item['display']?['title'] as String? ?? '';
        if (itemTitle.toLowerCase().trim() == title.toLowerCase().trim()) {
          final target = item['target'] ?? {};
          final path = target['path'] as String? ?? '';
          if (path.isNotEmpty) {
            debugPrint('[Watcho] Found exact match path: $path');
            return _convertToPlayPath(path);
          }
        }
      }

      // 2nd pass: fuzzy/contains title match in BOTH directions (handles "Dridam LockUp" matching "Dridam")
      for (final item in dataList) {
        final itemTitle = item['display']?['title'] as String? ?? '';
        final t1 = itemTitle.toLowerCase().trim();
        final t2 = title.toLowerCase().trim();
        
        if (t1.isNotEmpty && t2.isNotEmpty && (t1.contains(t2) || t2.contains(t1))) {
          final target = item['target'] ?? {};
          final path = target['path'] as String? ?? '';
          if (path.isNotEmpty) {
            debugPrint('[Watcho] Found bidirectional fuzzy match path: $path (Title: $itemTitle)');
            return _convertToPlayPath(path);
          }
        }
      }
    } catch (e) {
      debugPrint('[Watcho] Search lookup failed: $e');
    }
    return null;
  }

  static String _convertToPlayPath(String path) {
    if (path.startsWith('movie/')) {
      return path.replaceFirst('movie/', 'movie/play/');
    } else if (path.startsWith('tvshow/')) {
      return path.replaceFirst('tvshow/', 'tvshow/play/');
    } else if (path.startsWith('series/')) {
      return path.replaceFirst('series/', 'series/play/');
    }
    return path;
  }

  /// Resolves streaming options from Watcho.com API
  static Future<List<WatchoStream>> resolveStreams(String title) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load custom credentials if configured, otherwise fallback to defaults
    final customSessionId = prefs.getString('watcho_session_id') ?? '';
    final customBoxId = prefs.getString('watcho_box_id') ?? '';
    
    final sessionId = customSessionId.isNotEmpty ? customSessionId : _defaultSessionId;
    final boxId = customBoxId.isNotEmpty ? customBoxId : _defaultBoxId;

    // First try to look up exact slug path via Search API
    String? resolvedPath = await _findSlugBySearch(title, sessionId, boxId);
    
    // Fallback to simple slug prediction if search returns nothing
    if (resolvedPath == null) {
      final fallbackSlug = _slugify(title);
      resolvedPath = 'movie/play/$fallbackSlug';
      debugPrint('[Watcho] Search yielded no paths. Falling back to predicted path: $resolvedPath');
    }

    final String streamApiUrl = 'https://dishtv-api.revlet.net/service/api/v1/page/stream?path=${Uri.encodeComponent(resolvedPath)}&appVersion=1.0&versionCode=1.0';

    final headers = {
      'Accept': 'application/json, text/plain, */*',
      'Session-Id': sessionId,
      'Box-Id': boxId,
      'Tenant-Code': 'dishtv',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Origin': 'https://www.watcho.com',
      'Referer': 'https://www.watcho.com/',
    };

    try {
      debugPrint('[Watcho] Attempting to resolve stream for path: $resolvedPath');
      final response = await _sendGetWithFailover(Uri.parse(streamApiUrl), headers);
      if (response.statusCode != 200) {
        debugPrint('[Watcho] API returned status code ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      if (data['status'] == false) {
        final errorMsg = data['error']?['message'] ?? 'Unknown error';
        debugPrint('[Watcho] API error: $errorMsg');
        return [];
      }

      final streamsData = data['response']?['streams'] as List? ?? [];
      final List<WatchoStream> resolved = [];

      for (final s in streamsData) {
        final streamUrl = s['url'] as String? ?? '';
        if (streamUrl.isEmpty) continue;

        final partner = s['attributes']?['partnerCode'] as String? ?? 'Watcho';
        final isTrailer = s['isTrailer'] as bool? ?? false;
        if (isTrailer) continue; // Skip trailer streams

        // Map content language if available in attributes/params
        final String language = data['response']?['pageAttributes']?['language'] ?? 'Hindi';

        resolved.add(WatchoStream(
          label: 'Watcho HLS Stream',
          url: streamUrl,
          partner: partner,
          language: language,
        ));
      }

      debugPrint('[Watcho] Resolved ${resolved.length} stream(s) for "$title"');
      return resolved;
    } catch (e) {
      debugPrint('[Watcho] Error resolving streams: $e');
      return [];
    }
  }
}
