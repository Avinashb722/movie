import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Represents a single torrent stream from Torrentio
class TorrentStream {
  final String name;        // e.g. "[BluRay 1080p]"
  final String title;       // Full title with quality info
  final String infoHash;    // The torrent info hash
  final int fileIdx;        // File index within the torrent
  final String quality;     // Detected quality label
  final String size;        // Human-readable size if available
  final bool isCached;      // Cached on Debrid status
  /// Direct HTTP stream URL from Torrentio's proxy (when available).
  /// This can be played directly by media_kit without needing a torrent client.
  final String streamUrl;

  const TorrentStream({
    required this.name,
    required this.title,
    required this.infoHash,
    required this.fileIdx,
    required this.quality,
    required this.size,
    this.isCached = false,
    this.streamUrl = '',
  });

  TorrentStream copyWith({
    String? name,
    String? title,
    String? infoHash,
    int? fileIdx,
    String? quality,
    String? size,
    bool? isCached,
    String? streamUrl,
  }) {
    return TorrentStream(
      name: name ?? this.name,
      title: title ?? this.title,
      infoHash: infoHash ?? this.infoHash,
      fileIdx: fileIdx ?? this.fileIdx,
      quality: quality ?? this.quality,
      size: size ?? this.size,
      isCached: isCached ?? this.isCached,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }

  /// Build a magnet link from the info hash.
  /// Returns empty string only if infoHash is truly empty.
  String get magnetUri {
    if (infoHash.isEmpty) {
      debugPrint('[TorrentStream] WARNING: Empty infoHash, cannot build magnet');
      return '';
    }
    final encodedTitle = Uri.encodeComponent(title.split('\n').first);
    final trackers = [
      // WebRTC / WebSocket trackers (Required for WebTorrent/Browser clients)
      'wss%3A%2F%2Ftracker.btorrent.xyz',
      'wss%3A%2F%2Ftracker.openwebtorrent.com',
      'wss%3A%2F%2Ftracker.fastcast.nz',
      'wss%3A%2F%2Ftracker.novage.com.ua',
      // Standard BitTorrent UDP/HTTP trackers (For hybrid clients/seeds)
      'udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce',
      'udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969%2Fannounce',
      'udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce',
      'udp%3A%2F%2Fp4p.arenabg.ch%3A1337%2Fannounce',
      'udp%3A%2F%2Ftracker.cyberia.is%3A6969%2Fannounce',
      'udp%3A%2F%2Ftracker.internetwarriors.net%3A1337%2Fannounce',
      'udp%3A%2F%2Ftracker.openbittorrent.com%3A6969%2Fannounce',
      'udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce',
      'udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce',
      'udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce',
      'udp%3A%2F%2Fipv4.tracker.harry.lu%3A80%2Fannounce',
      'udp%3A%2F%2Ftracker.tiny-vps.com%3A6969%2Fannounce',
      'udp%3A%2F%2Fopen.demonii.com%3A1337%2Fannounce',
    ].map((t) => '&tr=$t').join();
    return 'magnet:?xt=urn:btih:$infoHash&dn=$encodedTitle$trackers';
  }

  /// Build a magnet link from a raw infoHash string.
  /// Useful when the stream object only has an infoHash but no full magnet.
  static String magnetFromInfoHash(String infoHash, {String? displayName}) {
    if (infoHash.isEmpty) return '';
    final dn = displayName != null ? '&dn=${Uri.encodeComponent(displayName)}' : '';
    return 'magnet:?xt=urn:btih:$infoHash$dn';
  }

  @override
  String toString() => 'TorrentStream($quality, $size, hash=${infoHash.substring(0, infoHash.length.clamp(0, 8))}...)';
}

/// Queries Torrentio (Stremio add-on) for torrent streams by IMDB ID.
///
/// Torrentio is a free, public Stremio add-on that indexes public torrents
/// and returns stream info (infoHash) for any IMDB movie ID.
///
/// API: https://torrentio.strem.fun/stream/movie/{imdbId}.json
class TorrentioService {
  static const _baseUrl = 'https://torrentio.strem.fun';

  static final _headers = {
    'User-Agent': 'Mozilla/5.0 (Android; Mobile) AppleWebKit/537.36',
    'Accept': 'application/json',
  };

  /// Fetches available torrent streams for a movie by its IMDB ID.
  /// Returns sorted list (best quality first).
  static Future<List<TorrentStream>> getStreams(String imdbId, {bool isTv = false, int season = 1, int episode = 1}) async {
    if (!imdbId.startsWith('tt')) {
      debugPrint('[Torrentio] Invalid IMDB ID: $imdbId');
      return [];
    }

    try {
      debugPrint('[Torrentio] Fetching streams for $imdbId (isTv=$isTv, S=$season, E=$episode)');
      final path = isTv ? 'series/$imdbId:$season:$episode' : 'movie/$imdbId';
      final uri = Uri.parse('$_baseUrl/stream/$path.json');

      http.Response resp;
      if (kIsWeb) {
        // Web: Try corsproxy.io first to bypass CORS and Cloudflare blocks
        try {
          final localProxyUri = Uri.parse('https://corsproxy.io/?url=${Uri.encodeComponent(uri.toString())}');
          resp = await http.get(localProxyUri, headers: _headers).timeout(const Duration(seconds: 8));
          if (resp.statusCode != 200) throw Exception('corsproxy.io returned ${resp.statusCode}');
        } catch (e) {
          debugPrint('[Torrentio] corsproxy.io proxy failed ($e). Trying Vercel proxy...');
          final proxyUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(uri.toString())}');
          resp = await http.get(proxyUri, headers: _headers).timeout(const Duration(seconds: 12));
        }
      } else {
        // Native: try direct connection first, fallback to proxy if blocked by ISP
        try {
          resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('[Torrentio] Direct connection failed ($e). Trying Vercel proxy...');
          final proxyUri = Uri.parse('https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(uri.toString())}');
          resp = await http.get(proxyUri, headers: _headers).timeout(const Duration(seconds: 12));
        }
      }

      if (resp.statusCode != 200) {
        debugPrint('[Torrentio] HTTP ${resp.statusCode}');
        return [];
      }

      final data = json.decode(resp.body);
      final rawStreams = data['streams'] as List?;
      if (rawStreams == null || rawStreams.isEmpty) {
        debugPrint('[Torrentio] No streams returned');
        return [];
      }

      final streams = <TorrentStream>[];
      for (final s in rawStreams) {
        final infoHash = (s['infoHash'] as String? ?? '').trim();
        if (infoHash.isEmpty) {
          debugPrint('[Torrentio] Skipping stream with empty infoHash');
          continue;
        }

        final name = s['name'] as String? ?? '';
        final title = s['title'] as String? ?? '';
        final fileIdx = (s['fileIdx'] as int?) ?? 0;

        final stream = TorrentStream(
          name: name,
          title: title,
          infoHash: infoHash,
          fileIdx: fileIdx,
          quality: _detectQuality(title),
          size: _extractSize(title),
          // Capture direct HTTP streaming URL if Torrentio provides one (for desktop playback)
          streamUrl: (s['url'] as String? ?? '').trim(),
        );

        // Validate that magnetUri was built successfully
        if (stream.magnetUri.isEmpty) {
          debugPrint('[Torrentio] WARNING: Failed to build magnet for hash: $infoHash');
          continue;
        }

        debugPrint('[Torrentio] Stream: ${stream.quality} | ${stream.size} | hash=${infoHash.substring(0, infoHash.length.clamp(0, 12))}...');
        streams.add(stream);
      }

      // Sort by quality score (best first)
      streams.sort((a, b) =>
          _qualityScore(b.quality).compareTo(_qualityScore(a.quality)));

      debugPrint('[Torrentio] Found ${streams.length} streams for $imdbId');
      return streams;
    } catch (e) {
      debugPrint('[Torrentio] Error: $e');
      return [];
    }
  }

  static String _detectQuality(String title) {
    final t = title.toLowerCase();
    if (t.contains('2160p') || t.contains('4k') || t.contains('uhd')) {
      return '4K UHD';
    }
    if (t.contains('1080p')) {
      if (t.contains('bluray') || t.contains('blu-ray') || t.contains('bdrip')) {
        return '1080p BluRay';
      }
      return '1080p HD';
    }
    if (t.contains('720p')) return '720p HD';
    if (t.contains('480p')) return '480p SD';
    if (t.contains('cam') || t.contains('ts ') || t.contains('hdts')) {
      return 'CAM';
    }
    return 'HD';
  }

  static int _qualityScore(String q) {
    switch (q) {
      case '4K UHD': return 100;
      case '1080p BluRay': return 90;
      case '1080p HD': return 80;
      case '720p HD': return 60;
      case '480p SD': return 40;
      case 'HD': return 50;
      case 'CAM': return 10;
      default: return 30;
    }
  }

  static String _extractSize(String title) {
    // Try to find "X.X GB" or "XXX MB" in the title
    final gbMatch = RegExp(r'(\d+\.?\d*)\s*GB', caseSensitive: false).firstMatch(title);
    if (gbMatch != null) return '${gbMatch.group(1)} GB';
    final mbMatch = RegExp(r'(\d+\.?\d*)\s*MB', caseSensitive: false).firstMatch(title);
    if (mbMatch != null) return '${mbMatch.group(1)} MB';
    return '';
  }
}
