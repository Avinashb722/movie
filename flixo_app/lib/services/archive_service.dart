import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

/// A resolved stream from Internet Archive CDN
class ArchiveStream {
  final String label;
  final String url;
  final bool isHls;
  final int qualityScore; // higher = better quality
  final String language;

  const ArchiveStream({
    required this.label,
    required this.url,
    required this.isHls,
    required this.qualityScore,
    this.language = '',
  });
}

/// Service that searches Internet Archive (archive.org) for free, legal,
/// CDN-hosted movie streams (.m3u8 HLS or direct .mp4).
class ArchiveService {
  static const String _searchUrl =
      'https://archive.org/advancedsearch.php';
  static const String _metaBase =
      'https://archive.org/metadata';
  static const String _downloadBase =
      'https://archive.org/download';

  static final _headers = {
    'User-Agent':
        'Mozilla/5.0 (Android; Mobile) AppleWebKit/537.36 Chrome/120 Safari/537.36',
    'Accept': 'application/json',
  };

  // Sends a GET request directly, or routes through unblocking gateways if blocked/failed
  static Future<http.Response> _sendGetWithFailover(Uri uri, Map<String, String> headers) async {
    // Try Cloudflare Proxy first if configured
    try {
      final prefs = await SharedPreferences.getInstance();
      final cfProxy = prefs.getString('cloudflare_proxy_url') ?? '';
      if (cfProxy.isNotEmpty) {
        final proxyUri = Uri.parse('$cfProxy?url=${Uri.encodeComponent(uri.toString())}');
        final resp = await http.get(proxyUri, headers: headers).timeout(const Duration(seconds: 15));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          return resp;
        }
        debugPrint('[Archive] Cloudflare proxy GET returned status ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('[Archive] Cloudflare proxy GET failed: $e');
    }

    if (!kIsWeb) {
      // Native: try direct connection first (no CORS restrictions)
      try {
        final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          return resp;
        }
        throw Exception('Direct GET returned status ${resp.statusCode}');
      } catch (e) {
        debugPrint('[Archive] Direct GET failed/blocked: $e. Trying private Vercel proxy...');
      }
    }
    // For Web, try Vercel proxy, but if it fails or returns invalid contents, fall back immediately to corsproxy.io.
    try {
      final unblockUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(uri.toString())}');
      final resp = await http.get(unblockUri, headers: headers).timeout(const Duration(seconds: 15));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = resp.body.trim();
        if (body.length > 10 && body != '{}') {
          return resp;
        }
      }
      throw Exception('Vercel Proxy returned empty or invalid response');
    } catch (e2) {
      debugPrint('[Archive] Vercel Proxy failed: $e2. Trying backup unblocker...');
      // Ensure backup unblocker query params are built correctly
      final unblockUri2 = Uri.parse('https://corsproxy.io/?url=${Uri.encodeComponent(uri.toString())}');
      return await http.get(unblockUri2, headers: headers).timeout(const Duration(seconds: 15));
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Search Internet Archive for the given movie [title] across multiple languages concurrently.
  static Future<List<ArchiveStream>> resolveStreams(
    String title, {
    int? year,
    String? imdbId,
  }) async {
    final languages = ['', 'Hindi', 'Tamil', 'Telugu', 'Kannada', 'Malayalam', 'Bengali'];
    final List<ArchiveStream> allStreams = [];
    final Set<String> processedIdentifiers = {};

    try {

      // 1. Search for matching identifiers concurrently (staggered on Web to prevent proxy rate limits)
      int sIdx = 0;
      final searchTasks = languages.map((lang) async {
        final currentIdx = sIdx++;
        if (kIsWeb && currentIdx > 0) {
          await Future.delayed(Duration(milliseconds: 150 * currentIdx));
        }
        final query = lang.isEmpty ? title : '$title $lang';
        return await _findIdentifiersForQuery(query, title, language: lang, year: year);
      });

      final searchResults = await Future.wait(searchTasks);
      final List<Map<String, String>> identifiersToResolve = [];

      for (var list in searchResults) {
        for (var item in list) {
          final id = item['identifier'];
          if (id != null && processedIdentifiers.add(id)) {
            identifiersToResolve.add(item);
          }
        }
      }

      // Group identifiers by language to ensure language variety
      final Map<String, List<Map<String, String>>> grouped = {};
      for (var item in identifiersToResolve) {
        final lang = item['language'] ?? '';
        grouped.putIfAbsent(lang, () => []).add(item);
      }

      // Interleave items from each language group
      final List<Map<String, String>> interleaved = [];
      bool addedAny = true;
      int idx = 0;
      while (addedAny && interleaved.length < 8) {
        addedAny = false;
        for (final lang in grouped.keys) {
          final list = grouped[lang]!;
          if (idx < list.length) {
            interleaved.add(list[idx]);
            addedAny = true;
            if (interleaved.length >= 8) break;
          }
        }
        idx++;
      }

      final itemsToResolve = interleaved;
      debugPrint('[Archive] Resolving files for ${itemsToResolve.length} matching identifier(s) with language diversity.');

      // 2. Resolve files for each identifier concurrently (staggered on Web to prevent proxy rate limits)
      int rIdx = 0;
      final resolveTasks = itemsToResolve.map((item) async {
        final currentIdx = rIdx++;
        if (kIsWeb && currentIdx > 0) {
          await Future.delayed(Duration(milliseconds: 150 * currentIdx));
        }
        return await _resolveFiles(item['identifier']!, title, item['language']!);
      });

      final resolveResults = await Future.wait(resolveTasks);
      for (var list in resolveResults) {
        allStreams.addAll(list);
      }

      // Deduplicate streams by URL
      final seenUrls = <String>{};
      final uniqueStreams = <ArchiveStream>[];
      for (var stream in allStreams) {
        if (seenUrls.add(stream.url)) {
          uniqueStreams.add(stream);
        }
      }
      return uniqueStreams;
    } catch (e) {
      debugPrint('[Archive] resolve streams total error: $e');
      return [];
    }
  }

  static Future<List<Map<String, String>>> _findIdentifiersForQuery(
    String query,
    String originalTitle, {
    required String language,
    int? year,
  }) async {
    final List<Map<String, String>> results = [];
    try {
      final uri = Uri.parse(_searchUrl).replace(queryParameters: {
        'q': 'title:($query) AND mediatype:movies',
        'fl[]': 'identifier,title,year,downloads',
        'sort[]': 'downloads desc',
        'rows': '50',
        'output': 'json',
        'page': '1',
      });

      final resp = await _sendGetWithFailover(uri, _headers);

      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body);
      final docs = data['response']?['docs'] as List?;
      if (docs == null || docs.isEmpty) return [];

      final queryNorm = _normalize(originalTitle);

      // TV broadcast channel prefixes — these are copyright-restricted recordings
      // that always return 403 and are never actual movies.
      const tvPrefixes = [
        'CNNW_', 'CNN_', 'FOXNEWS_', 'MSNBC_', 'ABC_', 'CBS_', 'NBC_',
        'BBC_', 'BBCW_', 'FOX_', 'CNBC_', 'CSPAN_', 'PBS_', 'NPR_',
        'RT_', 'ALJAZ_', 'FRANCE24_', 'DW_', 'NHK_',
      ];

      for (final doc in docs) {
        final docTitleRaw = doc['title'] as String? ?? '';
        final identifier = doc['identifier'] as String? ?? '';
        if (identifier.isEmpty) continue;

        // Skip TV broadcast captures (always copyright-restricted, always 403)
        final bool isTvCapture = tvPrefixes.any((p) => identifier.startsWith(p));
        if (isTvCapture) continue;

        // Verify if title is a correct match for the movie
        if (!_isTitleMatch(docTitleRaw, originalTitle)) continue;

        // Detect actual language
        String finalLanguage = language;
        if (finalLanguage.isEmpty) {
          final docTitleLower = (doc['title'] as String? ?? '').toLowerCase();
          final idLower = identifier.toLowerCase();
          if (docTitleLower.contains('hindi') || idLower.contains('hindi')) finalLanguage = 'Hindi';
          else if (docTitleLower.contains('tamil') || idLower.contains('tamil')) finalLanguage = 'Tamil';
          else if (docTitleLower.contains('telugu') || idLower.contains('telugu')) finalLanguage = 'Telugu';
          else if (docTitleLower.contains('kannada') || idLower.contains('kannada')) finalLanguage = 'Kannada';
          else if (docTitleLower.contains('malayalam') || idLower.contains('malayalam')) finalLanguage = 'Malayalam';
          else if (docTitleLower.contains('bengali') || idLower.contains('bengali')) finalLanguage = 'Bengali';
          else if (docTitleLower.contains('english') || idLower.contains('english')) finalLanguage = 'English';
        }

        results.add({
          'identifier': identifier,
          'language': finalLanguage,
        });
      } // end for loop
    } catch (e) {
      debugPrint('[Archive] search query "$query" error: $e');
    }
    return results;
  }

  static Future<List<ArchiveStream>> _resolveFiles(
      String identifier, String title, String language) async {
    final uri = Uri.parse('$_metaBase/$identifier');
    final resp = await _sendGetWithFailover(uri, _headers);

    if (resp.statusCode != 200) return [];

    final data = json.decode(resp.body);
    if (data is! Map) return [];

    final files = (data['files'] as List?) ?? [];
    if (files.isEmpty) {
      return [];
    }

    final streams = <ArchiveStream>[];

    // Prefer HLS (.m3u8) first
    for (final file in files) {
      final name = file['name'] as String? ?? '';
      if (name.endsWith('.m3u8') && !name.contains('_thumb')) {
        String finalLanguage = language;
        if (finalLanguage.isEmpty) {
          final identifierLower = identifier.toLowerCase();
          final nameLower = name.toLowerCase();
          if (identifierLower.contains('hindi') || nameLower.contains('hindi')) finalLanguage = 'Hindi';
          else if (identifierLower.contains('tamil') || nameLower.contains('tamil')) finalLanguage = 'Tamil';
          else if (identifierLower.contains('telugu') || nameLower.contains('telugu')) finalLanguage = 'Telugu';
          else if (identifierLower.contains('kannada') || nameLower.contains('kannada')) finalLanguage = 'Kannada';
          else if (identifierLower.contains('malayalam') || nameLower.contains('malayalam')) finalLanguage = 'Malayalam';
          else if (identifierLower.contains('bengali') || nameLower.contains('bengali')) finalLanguage = 'Bengali';
          else if (identifierLower.contains('english') || nameLower.contains('english')) finalLanguage = 'English';
        }

        streams.add(ArchiveStream(
          label: 'HLS Adaptive',
          url: '$_downloadBase/$identifier/$name',
          isHls: true,
          qualityScore: 100,
          language: finalLanguage,
        ));
      }
    }

    // Then MP4 files sorted by resolution
    for (final file in files) {
      final name = file['name'] as String? ?? '';
      final format = (file['format'] as String? ?? '').toLowerCase();
      final sizeStr = file['size'] as String? ?? '0';
      final sizeBytes = int.tryParse(sizeStr) ?? 0;

      final isVideo = name.endsWith('.mp4') ||
          name.endsWith('.mkv') ||
          name.endsWith('.webm') ||
          name.endsWith('.avi') ||
          name.endsWith('.mov') ||
          name.endsWith('.mpeg4') ||
          format.contains('mpeg-4') ||
          format.contains('h.264') ||
          format.contains('mp4') ||
          format.contains('matroska') ||
          format.contains('mkv') ||
          format.contains('webm');

      final lengthStr = file['length'] as String? ?? '0';
      final lengthSeconds = double.tryParse(lengthStr) ?? 0.0;

      // Skip files shorter than 40 mins (2400s). For files with missing duration, skip if under 100MB.
      final bool isShortOrSmall = (lengthSeconds > 0 && lengthSeconds < 2400) ||
          (lengthSeconds <= 0 && sizeBytes < 100 * 1024 * 1024);

      final isSkip = name.contains('_thumb') ||
          name.contains('_sample') ||
          name.contains('_trailer') ||
          name.contains('_preview') ||
          name.contains('thumb.') ||
          isShortOrSmall;

      if (isVideo && !isSkip) {
        final quality = _detectQuality(name, sizeBytes);
        String finalLanguage = language;
        if (finalLanguage.isEmpty) {
          final identifierLower = identifier.toLowerCase();
          final nameLower = name.toLowerCase();
          if (identifierLower.contains('hindi') || nameLower.contains('hindi')) finalLanguage = 'Hindi';
          else if (identifierLower.contains('tamil') || nameLower.contains('tamil')) finalLanguage = 'Tamil';
          else if (identifierLower.contains('telugu') || nameLower.contains('telugu')) finalLanguage = 'Telugu';
          else if (identifierLower.contains('kannada') || nameLower.contains('kannada')) finalLanguage = 'Kannada';
          else if (identifierLower.contains('malayalam') || nameLower.contains('malayalam')) finalLanguage = 'Malayalam';
          else if (identifierLower.contains('bengali') || nameLower.contains('bengali')) finalLanguage = 'Bengali';
          else if (identifierLower.contains('english') || nameLower.contains('english')) finalLanguage = 'English';
        }

        streams.add(ArchiveStream(
          label: quality.label,
          url: '$_downloadBase/$identifier/${Uri.encodeComponent(name)}',
          isHls: false,
          qualityScore: quality.score,
          language: finalLanguage,
        ));
      }
    }

    streams.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));

    final unique = <String>{};
    final result = <ArchiveStream>[];
    for (final s in streams) {
      if (unique.add('${s.label}_${s.language}') && result.length < 15) {
        result.add(s);
      }
    }

    return result;
  }

  // ── Utility ─────────────────────────────────────────────────────────────────

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    if (a.contains(b) || b.contains(a)) return 0.85;

    final aChars = a.split('').toSet();
    final bChars = b.split('').toSet();
    final common = aChars.intersection(bChars).length;
    return common / (aChars.length + bChars.length - common);
  }

  static ({String label, int score}) _detectQuality(
      String name, int sizeBytes) {
    final n = name.toLowerCase();
    if (n.contains('1080') || sizeBytes > 3 * 1024 * 1024 * 1024) {
      return (label: '1080p HD', score: 90);
    }
    if (n.contains('720') || sizeBytes > 1 * 1024 * 1024 * 1024) {
      return (label: '720p HD', score: 80);
    }
    if (n.contains('480') ||
        (sizeBytes > 400 * 1024 * 1024 && sizeBytes <= 1024 * 1024 * 1024)) {
      return (label: '480p SD', score: 60);
    }
    if (n.contains('360') || sizeBytes > 100 * 1024 * 1024) {
      return (label: '360p', score: 40);
    }
    final ext = name.split('.').last.toUpperCase();
    final defaultLabel = ['MP4', 'MKV', 'WEBM', 'AVI', 'MOV'].contains(ext) ? ext : 'Video';
    return (label: defaultLabel, score: 30);
  }
  static String _cleanTitle(String title) {
    var t = title.toLowerCase().trim();
    // Keep spaces, strip all other punctuation
    return t.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isTitleMatch(String docTitleRaw, String queryRaw) {
    final cleanedDoc = _cleanTitle(docTitleRaw);
    final cleanedQuery = _cleanTitle(queryRaw);

    if (cleanedDoc == cleanedQuery) return true;

    final queryWords = cleanedQuery.split(' ').where((w) => w.isNotEmpty).toList();
    if (queryWords.isEmpty) return false;

    final docWords = cleanedDoc.split(' ').where((w) => w.isNotEmpty).toList();

    // Each word in the query must match (as a prefix) at least one word in the document title
    for (final qWord in queryWords) {
      bool wordMatched = false;
      for (final dWord in docWords) {
        final isNum = RegExp(r'^\d+$').hasMatch(qWord);
        if (isNum) {
          if (dWord == qWord || dWord == '${qWord}nd' || dWord == '${qWord}rd' || dWord == '${qWord}th' || dWord == '${qWord}st') {
            wordMatched = true;
            break;
          }
        } else {
          if (dWord.startsWith(qWord)) {
            wordMatched = true;
            break;
          }
        }
      }
      if (!wordMatched) return false;
    }

    // Position adjacency check for numbers/sequels
    for (int i = 1; i < queryWords.length; i++) {
      final prevWord = queryWords[i - 1];
      final currWord = queryWords[i];
      final isNum = RegExp(r'^\d+$').hasMatch(currWord);
      
      if (isNum) {
        int prevIdx = -1;
        int currIdx = -1;
        for (int j = 0; j < docWords.length; j++) {
          if (docWords[j].startsWith(prevWord)) prevIdx = j;
          if (docWords[j] == currWord || docWords[j] == '${currWord}nd' || docWords[j] == '${currWord}rd' || docWords[j] == '${currWord}th' || docWords[j] == '${currWord}st') {
            currIdx = j;
          }
        }
        if (prevIdx != -1 && currIdx != -1) {
          final diff = currIdx - prevIdx;
          if (diff < 0 || diff > 2) {
            return false;
          }
        }
      }
    }

    // Only run extra words limit for short queries (1 or 2 words) to prevent false hits
    if (queryWords.length <= 2) {
      final docFilterWords = cleanedDoc
          .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '') // remove years
          .replaceAll(RegExp(r'\b(hindi|tamil|telugu|kannada|malayalam|bengali|english|dubbed|dual|audio|web|rip|hd|720p|1080p|bluray|dvd|mp4|mkv|avi|mov|webm|film|movie)\b'), '')
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toSet();

      final queryFilterWords = cleanedQuery
          .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '')
          .replaceAll(RegExp(r'\b(hindi|tamil|telugu|kannada|malayalam|bengali|english|dubbed|dual|audio|web|rip|hd|720p|1080p|bluray|dvd|mp4|mkv|avi|mov|webm|film|movie)\b'), '')
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toSet();

      final extraWords = docFilterWords.difference(queryFilterWords);
      final maxExtra = queryFilterWords.length; // 1 extra for 1-word query, 2 extra for 2-word query

      if (extraWords.length > maxExtra) {
        return false;
      }
    }

    return true;
  }
}
