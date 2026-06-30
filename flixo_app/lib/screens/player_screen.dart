import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';
import '../services/torrentio_service.dart';
import '../services/download_service.dart';
import '../services/history_service.dart';
import '../services/moviebox_service.dart';
import '../services/windows_torrent_service.dart';
import '../widgets/web_video_player_stub.dart'
    if (dart.library.html) '../widgets/web_video_player_web.dart';
import 'stream_screen.dart';
import '../services/local_streaming_proxy.dart';
import '../services/archive_service.dart';


class PlayerScreen extends StatefulWidget {
  final Movie movie;
  final String? imdbId;
  final int? year;
  final String? localFilePath;
  final String? directUrl;
  final String? referer;
  final String? fallbackUrl;

  final String? subjectId;
  final String? detailPath;
  final int? resolution;

  const PlayerScreen({
    super.key,
    required this.movie,
    this.imdbId,
    this.year,
    this.localFilePath,
    this.directUrl,
    this.referer,
    this.fallbackUrl,
    this.subjectId,
    this.detailPath,
    this.resolution,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  List<TorrentStream> _streams = [];
  int _activeIndex = 0;
  bool _loading = true;
  String _statusMessage = 'Loading player...';

  BetterPlayerController? _betterPlayerController;
  VideoPlayerController? _webVideoPlayerController;
  ChewieController? _chewieController;
  bool _isDirectPlayback = false;
  bool _hasError = false;
  String _errorMessage = '';
  // For web: store the proxied URL to pass to HtmlElementView
  String? _webPlayUrl;

  // For Windows native playback via media_kit
  mk.Player? _mediaKitPlayer;
  mkv.VideoController? _mediaKitVideoController;
  // For Windows in-app P2P torrent streaming
  WindowsTorrentStreamService? _windowsTorrentService;

  // Double-tap skip visual indicators
  bool _showLeftIndicator = false;
  bool _showRightIndicator = false;
  Timer? _indicatorTimer;

  // Multi-language stream selection fields
  final List<Map<String, String>> _alternativeLanguageStreams = [];
  int _currentLanguageStreamIndex = 0;
  String? _originalDirectUrl;

  List<TorrentStream> _bgTorrents = [];
  List<MovieBoxStream> _bgMovieBox = [];
  List<ArchiveStream> _bgArchives = [];
  bool _bgLoading = true;

  @override
  void initState() {
    super.initState();
    _forceLandscape();

    _originalDirectUrl = widget.directUrl;
    if (_originalDirectUrl != null && _originalDirectUrl!.contains('||')) {
      final streams = _originalDirectUrl!.split('||');
      for (final s in streams) {
        final parts = s.split('|');
        final urlPart = parts[0];
        String language = 'Unknown';
        String? referer;
        for (final p in parts) {
          if (p.startsWith('language=')) {
            language = p.substring('language='.length);
          } else if (p.startsWith('referer=')) {
            referer = p.substring('referer='.length);
          }
        }
        // Map original language code to name
        final Map<String, String> originalLanguageNames = {
          'hi': 'Hindi',
          'kn': 'Kannada',
          'te': 'Telugu',
          'ta': 'Tamil',
          'ml': 'Malayalam',
          'bn': 'Bengali',
          'pa': 'Punjabi',
          'mr': 'Marathi',
          'gu': 'Gujarati',
        };
        final String origLangCode = widget.movie.language.toLowerCase();
        final String actualOrigLang = originalLanguageNames[origLangCode] ?? widget.movie.language;

        // Correct incorrect provider labeling (e.g. labeling Kannada as English)
        if (language.startsWith('English') && 
            origLangCode != 'en' && 
            (urlPart.contains('hakunaymatata.com') || urlPart.contains('aoneroom.com'))) {
          language = language.replaceFirst('English', actualOrigLang);
        }

        String sanitizedUrl = urlPart;
        if (sanitizedUrl.contains('|language=')) {
          sanitizedUrl = sanitizedUrl.split('|language=')[0];
        }

        _alternativeLanguageStreams.add({
          'url': sanitizedUrl + (referer != null ? '|referer=$referer' : ''),
          'language': language,
        });
        debugPrint('[PlayerScreen] Language stream detected: $language → ${urlPart.substring(0, urlPart.length.clamp(0, 60))}...');
      }
      debugPrint('[PlayerScreen] Total language streams: ${_alternativeLanguageStreams.length}');
    } else {
      debugPrint('[PlayerScreen] Single stream (no multi-lang), url contains ||: ${_originalDirectUrl?.contains('||')}');
    }

    if (widget.localFilePath != null) {
      debugPrint('[PlayerScreen] Playing local file: ${widget.localFilePath}');
      _isDirectPlayback = true;
      _initLocalPlayer();
    } else if (widget.directUrl != null) {
      // Extract the first stream from double-pipe separated directUrl configs if present
      String url = widget.directUrl!;
      if (url.contains('||')) {
        url = url.split('||')[0];
      }
      debugPrint('[PlayerScreen] Selected stream: ${widget.movie.title}');
      // Validate URL before playing
      if (url.trim().isEmpty) {
        debugPrint('[PlayerScreen] ERROR: Empty URL received');
        _setError('Stream unavailable. URL is empty.');
        return;
      }

      // Extract actual url and referer from pipe parameters
      String cleanUrl = url;
      String? cleanReferer = widget.referer;
      if (url.contains('|referer=')) {
        final parts = url.split('|referer=');
        cleanUrl = parts[0];
        if (parts.length > 1 && parts[1].isNotEmpty) {
          cleanReferer = parts[1];
          if (cleanReferer.contains('|')) {
            cleanReferer = cleanReferer.split('|')[0];
          }
        }
      }

      // Detect stream type
      if (_isMagnetLink(url)) {
        debugPrint('[PlayerScreen] Detected magnet link');

        // On Windows: try WebTorrent CLI for in-app streaming
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startWindowsTorrentStream(url);
          });
          return;
        }

        // Mobile (Android/iOS): use StreamScreen with native P2P engine
        debugPrint('[PlayerScreen] Redirecting to P2P StreamScreen');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StreamScreen(
                magnetLink: url,
                title: widget.movie.title,
              ),
            ),
          );
        });
        return;
      }


      _isDirectPlayback = true;
      final bool isWindowsRefresh = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      if ((kIsWeb || isWindowsRefresh) && widget.subjectId != null && widget.subjectId!.isNotEmpty) {
        // Force refresh URL at playtime — on Windows this also ensures the sign is for IPv4
        setState(() {
          _loading = true;
          _statusMessage = 'Refreshing stream link...';
        });
        MovieBoxService.refreshUrl(MovieBoxStream(
          url: cleanUrl,
          resolution: widget.resolution ?? 480,
          size: '',
          referer: cleanReferer ?? '',
          subjectId: widget.subjectId!,
          detailPath: widget.detailPath ?? '',
        )).then((freshStream) {
          if (mounted) {
            debugPrint('[PlayerScreen] Web - Refreshed playtime URL: ${freshStream.url}');
            _initNetworkPlayer(freshStream.url);
          }
        }).catchError((err) {
          if (mounted) {
            debugPrint('[PlayerScreen] Web - Playtime URL refresh failed: $err. Playing original.');
            _initNetworkPlayer(cleanUrl);
          }
        });
      } else {
        _initNetworkPlayer(url);
      }
    } else {
      _loadStreams();
    }
  }

  /// Detect if a URL is a magnet link or info hash
  bool _isMagnetLink(String url) {
    final trimmed = url.trim().toLowerCase();
    return trimmed.startsWith('magnet:') ||
        (trimmed.length == 40 && RegExp(r'^[a-f0-9]+$').hasMatch(trimmed)) ||
        (trimmed.length == 64 && RegExp(r'^[a-f0-9]+$').hasMatch(trimmed));
  }

  /// Windows-only: Start in-app P2P streaming via WebTorrent CLI.
  /// Falls back to asking user if webtorrent is not installed.
  Future<void> _startWindowsTorrentStream(String magnetUri) async {

    setState(() {
      _loading = true;
      _statusMessage = 'Checking WebTorrent...';
    });

    // Check if webtorrent is installed
    final available = await WindowsTorrentStreamService.isAvailable();
    if (!available) {
      if (!mounted) return;
      // Offer to install or fall back to external
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('WebTorrent Required', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: const Text(
            'In-app P2P streaming on Windows requires WebTorrent CLI (free, via Node.js).\n\n'
            'Install it automatically (requires Node.js), or open the magnet link in your external torrent client.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'external'),
              child: const Text('Open Externally', style: TextStyle(color: AppColors.accent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, 'install'),
              child: const Text('Install WebTorrent', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (choice == 'install') {
        if (!mounted) return;
        setState(() { _statusMessage = 'Installing WebTorrent CLI...\n(this may take a minute)'; });
        final installed = await WindowsTorrentStreamService.install();
        if (!installed) {
          if (!mounted) return;
          _setError('WebTorrent installation failed.\nPlease run: npm install -g webtorrent-cli');
          return;
        }
        // Retry after install
        await _startWindowsTorrentStream(magnetUri);
        return;
      } else if (choice == 'external') {
        try { await launchUrl(Uri.parse(magnetUri)); } catch (_) {}
        if (mounted) Navigator.pop(context);
        return;
      } else {
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    // WebTorrent is available — start streaming
    setState(() { _statusMessage = 'Starting torrent stream...\n(fetching metadata)'; });
    _windowsTorrentService = WindowsTorrentStreamService();

    try {
      // Start WebTorrent process — wait for server URL in stdout
      final streamUrl = await _windowsTorrentService!.startStream(magnetUri, onProgress: (line) {
        if (!mounted) return;
        setState(() {
          if (line.contains('Server running')) {
            _statusMessage = 'Starting playback...';
          } else {
            _statusMessage = 'WebTorrent status:\n$line';
          }
        });
      });

      if (!mounted) return;

      // Play the local HTTP stream via media_kit
      _isDirectPlayback = true;
      await _initNetworkPlayer(streamUrl);
    } on TimeoutException {
      // stdout parse timed out — try polling the HTTP server directly
      debugPrint('[PlayerScreen] WebTorrent stdout timeout, trying HTTP poll...');
      if (!mounted) return;
      setState(() { _statusMessage = 'Connecting to peers...\n(this can take up to a minute)'; });
      try {
        final streamUrl = await _windowsTorrentService!.waitForServer();
        if (!mounted) return;
        _isDirectPlayback = true;
        await _initNetworkPlayer(streamUrl);
      } catch (e) {
        if (!mounted) return;
        _setError('Torrent stream failed to start.\nTry opening it externally:\n${magnetUri.substring(0, 60)}...');
      }
    } catch (e) {
      if (!mounted) return;
      _setError('WebTorrent error: $e');
    }
  }


  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasError = true;
      _errorMessage = message;
    });
    
    // Automatically trigger the alternative servers sheet so user can choose another stream
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _showAlternativeServersSheet();
      }
    });
  }

  void _forceLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initLocalPlayer() async {
    try {
      final file = File(widget.localFilePath!);
      if (!await file.exists()) {
        _setError('Local file not found.');
        return;
      }

      final bool isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux;

      if (isDesktop) {
        final vc = VideoPlayerController.file(file);
        await vc.initialize();
        if (mounted) {
          setState(() {
            _webVideoPlayerController = vc;
            _chewieController = ChewieController(
              videoPlayerController: vc,
              aspectRatio: 16 / 9,
              autoPlay: true,
              looping: false,
            );
            _loading = false;
          });
        }
      } else {
        final betterPlayerConfiguration = BetterPlayerConfiguration(
          aspectRatio: 16 / 9,
          autoPlay: true,
          looping: false,
          allowedScreenSleep: false,
          fit: BoxFit.contain,
          placeholder: const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            enableAudioTracks: true,
            enableSubtitles: true,
            enableQualities: false,
            controlBarColor: Colors.black45,
          ),
        );

        final dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.file,
          widget.localFilePath!,
        );

        final controller = BetterPlayerController(betterPlayerConfiguration);
        await controller.setupDataSource(dataSource);

        if (mounted) {
          setState(() {
            _betterPlayerController = controller;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Local playback error: $e');
      _setError('Error playing file: $e');
    }
  }

  String _getOriginalUrl(String currentUrl) {
    try {
      final uri = Uri.parse(currentUrl);
      if (uri.queryParameters.containsKey('url')) {
        return Uri.decodeComponent(uri.queryParameters['url']!);
      }
    } catch (_) {}
    return currentUrl;
  }

  Future<void> _initNetworkPlayer(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final cfProxyUrl = prefs.getString('cloudflare_proxy_url') ?? '';
    final bool hasCfProxy = cfProxyUrl.isNotEmpty;

    // Extract actual url and referer from pipe parameters
    String cleanUrl = url;
    String? cleanReferer = widget.referer;
    if (url.contains('|referer=')) {
      final parts = url.split('|referer=');
      cleanUrl = parts[0];
      if (parts.length > 1 && parts[1].isNotEmpty) {
        cleanReferer = parts[1];
        if (cleanReferer.contains('|')) {
          cleanReferer = cleanReferer.split('|')[0];
        }
      }
    }
    
    // Strip language metadata if it exists directly on the target URL
    if (cleanUrl.contains('|language=')) {
      cleanUrl = cleanUrl.split('|language=')[0];
    }

    String playUrl = cleanUrl;
    final Map<String, String> playHeaders = {};

    try {
      debugPrint('[PlayerScreen] Initializing network player for: ${cleanUrl.substring(0, cleanUrl.length.clamp(0, 100))}...');

      if (mounted) {
        setState(() => _statusMessage = 'Connecting to stream...');
      }

      final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      if (isWindows) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Initializing Windows native player...';
          });
        }
        
        final player = mk.Player();
        // Configure mpv for aggressive buffering on slow mobile (Jio/Airtel) connections
        player.stream.log.listen((event) {
          // Only log errors, not info spam
          if (event.level == 'error' || event.level == 'fatal') {
            debugPrint('[mpv] ${event.prefix}: ${event.text}');
          }
        });
        player.stream.error.listen((error) {
          debugPrint('[mpv] ERROR: $error');
          
          final nextIndex = _currentLanguageStreamIndex + 1;
          if (nextIndex < _alternativeLanguageStreams.length) {
            debugPrint('[PlayerScreen] Default stream failed. Trying next alternative stream at index $nextIndex...');
            _switchLanguageStream(nextIndex);
            return;
          }

          _setError('Direct stream playback failed. Please go back and select a different streaming source.');
        });
        
        player.stream.width.listen((width) {
          if (width != null && width > 0 && _loading) {
            if (mounted) {
              setState(() => _loading = false);
            }
          }
        });
        
        final controller = mkv.VideoController(player);
        _mediaKitPlayer = player;
        _mediaKitVideoController = controller;
        
        // Boost mpv buffer to handle throttled mobile networks (Jio/Airtel 5G)
        // 128MB buffer = ~60 seconds of 1080p HLS at ~15 Mbps
        // Optimize buffer for instant startup play (2-3 seconds)
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
          try {
            final dynamic native = player.platform;
            await native.setProperty('demuxer-max-bytes', '4MiB');
            await native.setProperty('demuxer-readahead-secs', '5');
            await native.setProperty('cache-secs', '5');
            await native.setProperty('network-timeout', '30');
          } catch (_) {}
        }
        
        // mpv/libmpv cannot make HTTPS connections on Windows.
        // Route ALL video through the internal Dart proxy (HTTP localhost).
        final proxyPort = LocalStreamingProxy.instance.port;
        
        String targetUrl = url;
        // Only inject aoneroom referer/auth for hakunaymatata/aoneroom CDN URLs
        final bool isMovieBoxCdn = targetUrl.contains('hakunaymatata.com') || targetUrl.contains('aoneroom.com');
        String ref = widget.referer ?? (isMovieBoxCdn ? 'https://h5.aoneroom.com/' : '');
        
        // Extract embed-specific referer if passed via pipe delimiter
        if (targetUrl.contains('|referer=')) {
          final parts = targetUrl.split('|referer=');
          targetUrl = parts[0];
          if (parts.length > 1 && parts[1].isNotEmpty) {
            ref = parts[1];
          }
        }

        final authParam = (isMovieBoxCdn && MovieBoxService.token != null)
            ? '&auth=${Uri.encodeComponent('Bearer ${MovieBoxService.token}')}' 
            : '';
            
        final bool isArchive = targetUrl.contains('archive.org');
        if (isArchive) {
          const cfWorker = 'https://long-wind-ad98.avinashbiradar722.workers.dev/';
          targetUrl = '$cfWorker?url=${Uri.encodeComponent(targetUrl)}';
          debugPrint('[PlayerScreen] Windows - Routing Archive stream through CF Worker: $targetUrl');
        }
        
        final refParam = ref.isNotEmpty ? '&referer=${Uri.encodeComponent(ref)}' : '';
        
        if (isMovieBoxCdn) {
           playUrl = 'https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(targetUrl)}&referer=${Uri.encodeComponent(ref)}';
        } else {
           playUrl = 'http://127.0.0.1:$proxyPort/play?url=${Uri.encodeComponent(targetUrl)}$refParam$authParam';
        }

        if (mounted) {
          setState(() {
            _statusMessage = 'Buffering video segment... (Starting in 5-6s)';
          });
        }
        await player.open(mk.Media(playUrl), play: true);
        
        HistoryService.instance.addToHistory(widget.movie);
        return;
      }

      // Set headers for direct playback
      final bool isMovieBoxUrl = (cleanUrl.contains('hakunaymatata.com') ||
          cleanUrl.contains('aoneroom.com') ||
          widget.referer != null) && !cleanUrl.contains('korso420dim.com') && !cleanUrl.contains('cdn30092');
      if (isMovieBoxUrl) {
        playHeaders['Referer'] = 'https://www.movieboxpro.app/';
        playHeaders['User-Agent'] = 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36';
        playHeaders['Origin'] = 'https://www.movieboxpro.app';
        // Cookie header helps some CDNs validate the session
        playHeaders['Accept'] = '*/*';
        playHeaders['Accept-Language'] = 'en-US,en;q=0.9';
        playHeaders['Range'] = 'bytes=0-';
      } else if (cleanUrl.contains('lookmovie2.skin') || cleanUrl.contains('lookmovie') || cleanUrl.contains('korso420dim.com') || cleanUrl.contains('cdn30091') || cleanUrl.contains('cdn30092')) {
        playHeaders['Referer'] = cleanReferer ?? 'https://lookmovie2.skin/';
        playHeaders['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
        playHeaders['Origin'] = 'https://lookmovie2.skin';
        playHeaders['Accept'] = '*/*';
        playHeaders['Accept-Language'] = 'en-US,en;q=0.9';
        playHeaders['Connection'] = 'keep-alive';
      } else if (cleanUrl.contains('archive.org')) {
        playHeaders['User-Agent'] = 'Mozilla/5.0 (Android; Mobile) AppleWebKit/537.36 Chrome/120 Safari/537.36';
      }

      if (kIsWeb) {
        final bool isMovieBox = cleanUrl.contains('hakunaymatata.com') || cleanUrl.contains('aoneroom.com');
        final bool isArchive = cleanUrl.contains('archive.org');
        final bool is2Embed = cleanUrl.contains('korso420dim.com') || cleanUrl.contains('stream2');
        final bool isMp4 = cleanUrl.toLowerCase().contains('.mp4');
        
        if (is2Embed) {
          // 2Embed HLS streams play directly on Web
          playUrl = cleanUrl;
          debugPrint('[PlayerScreen] Web - Playing 2Embed HLS stream directly: $playUrl');
        } else if (isMp4) {
          // Play direct MP4 links natively without Vercel proxy, as browsers handle MP4s natively
          playUrl = cleanUrl;
          debugPrint('[PlayerScreen] Web - Playing MP4 stream directly: $playUrl');
        } else if (isArchive) {
          // Route Archive.org streams through Cloudflare Worker (corsproxy.io blocks archive with 403)
          const cfWorker = 'https://long-wind-ad98.avinashbiradar722.workers.dev/';
          playUrl = '$cfWorker?url=${Uri.encodeComponent(cleanUrl)}';
          debugPrint('[PlayerScreen] Web - Routing Archive stream through CF Worker: $playUrl');
        } else if (isMovieBox) {
          // Use Vercel proxy for MovieBox streams on web as well (corsproxy.io blocks MovieBox with 403)
          playUrl = 'https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(cleanUrl)}&referer=${Uri.encodeComponent(cleanReferer ?? 'https://h5.aoneroom.com/')}';
          debugPrint('[PlayerScreen] Web - Routing MovieBox stream through Vercel Proxy: $playUrl');
        } else {
          // General stream: route through Vercel proxy as primary fallback since corsproxy.io is blocking domains
          playUrl = 'https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(cleanUrl)}';
          if (cleanReferer != null) {
            playUrl += '&referer=${Uri.encodeComponent(cleanReferer)}';
          }
          debugPrint('[PlayerScreen] Web - Routing general stream through Vercel Proxy: $playUrl');
        }
      } else {
        // Native (Android/iOS/Windows): Direct play with headers, except on Windows where we use Vercel proxy/CF worker
        final bool isWindows = defaultTargetPlatform == TargetPlatform.windows;
        if (isWindows) {
          final bool isMovieBox = url.contains('hakunaymatata.com') || url.contains('aoneroom.com');
          if (isMovieBox) {
            final String ref = widget.referer ?? 'https://h5.aoneroom.com/';
            playUrl = 'https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(url)}&referer=${Uri.encodeComponent(ref)}';
            debugPrint('[PlayerScreen] Windows - Routing MovieBox stream through Vercel Proxy: $playUrl');
          } else {
            // Play all other streams (Archive.org, direct video links, etc.) directly on Windows without proxy
            playUrl = url;
            debugPrint('[PlayerScreen] Windows - Playing stream directly: $playUrl');
          }
        } else {
          final bool isProxyUrl = url.contains('ver-orcin-alpha.vercel.app') || url.contains('127.0.0.1') || (hasCfProxy && url.startsWith(cfProxyUrl));
          if (!isProxyUrl) {
            final bool isLookMovieOrKorso = cleanUrl.contains('lookmovie2.skin') || cleanUrl.contains('lookmovie') || cleanUrl.contains('korso420dim.com') || cleanUrl.contains('cdn30091') || cleanUrl.contains('cdn30092') || cleanUrl.contains('tiktokcdn.com');
            if (isLookMovieOrKorso) {
              final proxyPort = LocalStreamingProxy.instance.port;
              final ref = cleanReferer ?? 'https://lookmovie2.skin/';
              playUrl = 'http://127.0.0.1:$proxyPort/play?url=${Uri.encodeComponent(cleanUrl)}&referer=${Uri.encodeComponent(ref)}';
              debugPrint('[PlayerScreen] Native Android - Routing stream through LocalStreamingProxy localhost port: $playUrl');
            } else {
              playUrl = cleanUrl;
              debugPrint('[PlayerScreen] Native Android - Playing stream directly: $playUrl');
            }
          } else {
            playUrl = url;
            // Keep headers even for proxy — Vercel proxy forwards them
            debugPrint('[PlayerScreen] Native - Playing via Proxy: $playUrl');
          }
        }
      }

      // Use video_player + chewie for ALL platforms (web and native).
      // video_player passes httpHeaders directly to ExoPlayer's MediaItem on Android,
      // which correctly signs the request — unlike better_player_plus which ignores
      // headers for BetterPlayerVideoFormat.other (plain MP4).
      debugPrint('[PlayerScreen] Using video_player+chewie with headers: ${playHeaders.keys.toList()}');

      // On web, use WebVideoPlayerWidget to render HTML video/iframe. 
      // This is required to support crossOrigin='anonymous' headers on Chrome,
      // avoiding ORB/CORS media decode blocks.
      if (kIsWeb) {
        HistoryService.instance.addToHistory(widget.movie);
        if (mounted) {
          setState(() {
            _webPlayUrl = playUrl;
            _loading = false;
          });
        }
        return;
      }

      final vc = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        httpHeaders: kIsWeb ? const {} : (playHeaders.isNotEmpty ? playHeaders : const {}),
      );
      await vc.initialize();

      final cc = ChewieController(
        videoPlayerController: vc,
        aspectRatio: 16 / 9,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        showControls: true,
        allowMuting: true,
        placeholder: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );

      HistoryService.instance.addToHistory(widget.movie);

      if (kIsWeb) {
        // On web, skip video_player entirely — use native <video> element via HtmlElementView
        // video_player on web cannot handle proxied URLs or custom headers
        vc.dispose();
        cc.dispose();
        if (mounted) {
          setState(() {
            _webPlayUrl = playUrl;
            _loading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _webVideoPlayerController = vc;
          _chewieController = cc;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Network playback error: $e');
      
      // On web we go straight to HTML video, no exceptions expected
      // On native, try proxy failover for MovieBox streams
      if (kIsWeb) {
        _setError('Error playing stream: $e');
        return;
      }

      final String originalUrl = _getOriginalUrl(url);
      final bool isMovieBox = originalUrl.contains('hakunaymatata.com') || originalUrl.contains('aoneroom.com');
      final bool isArchive = originalUrl.contains('archive.org');
      final bool isLookMovieOrKorso = originalUrl.contains('lookmovie2.skin') || originalUrl.contains('lookmovie') || originalUrl.contains('korso420dim.com') || originalUrl.contains('cdn30091') || originalUrl.contains('cdn30092') || originalUrl.contains('tiktokcdn.com');
      final bool alreadyTriedVercel = playUrl.contains('ver-orcin-alpha.vercel.app');
      final bool alreadyTriedCf = hasCfProxy && playUrl.startsWith(cfProxyUrl);
      
      if (isMovieBox || isArchive) {
        if (!alreadyTriedVercel) {
          String vercelUrl = 'https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(originalUrl)}';
          if (isMovieBox) {
            vercelUrl += '&referer=${Uri.encodeComponent(widget.referer ?? 'https://h5.aoneroom.com/')}';
          }
          debugPrint('[PlayerScreen] Playback failed. Attempting automatic Vercel Proxy failover: $vercelUrl');
          _webVideoPlayerController?.dispose();
          _webVideoPlayerController = null;
          _chewieController?.dispose();
          _chewieController = null;
          _initNetworkPlayer(vercelUrl);
          return;
        } else if (hasCfProxy && !alreadyTriedCf) {
          String cfUrl = '$cfProxyUrl?url=${Uri.encodeComponent(originalUrl)}';
          if (isMovieBox) {
            cfUrl += '&referer=${Uri.encodeComponent(widget.referer ?? 'https://h5.aoneroom.com/')}';
          }
          debugPrint('[PlayerScreen] Playback failed. Attempting Cloudflare Proxy failover: $cfUrl');
          _webVideoPlayerController?.dispose();
          _webVideoPlayerController = null;
          _chewieController?.dispose();
          _chewieController = null;
          _initNetworkPlayer(cfUrl);
          return;
        }
      } else if (isLookMovieOrKorso) {
        if (!alreadyTriedVercel) {
          String vercelUrl = 'https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(originalUrl)}';
          if (cleanReferer != null) {
            vercelUrl += '&referer=${Uri.encodeComponent(cleanReferer)}';
          } else {
            vercelUrl += '&referer=${Uri.encodeComponent('https://lookmovie2.skin/')}';
          }
          debugPrint('[PlayerScreen] LookMovie direct playback failed. Falling back to Vercel Proxy: $vercelUrl');
          _webVideoPlayerController?.dispose();
          _webVideoPlayerController = null;
          _chewieController?.dispose();
          _chewieController = null;
          _initNetworkPlayer(vercelUrl);
          return;
        }
      }
      
      _setError('Error playing URL: $e');
    }
  }

  Future<void> _loadStreams() async {
    final imdb = widget.imdbId ?? '';
    if (!imdb.startsWith('tt')) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = 'No IMDb ID available for torrent lookup.';
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() => _statusMessage = 'Searching for streams...');
      }

      // Run on background isolate to prevent UI jank
      final streams = await compute(_fetchStreamsIsolate, imdb);

      if (!mounted) return;
      setState(() {
        _streams = streams;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[Player] Error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = 'Failed to load streams';
        });
      }
    }
  }

  /// Run Torrentio fetch in a background isolate to prevent frame drops
  static Future<List<TorrentStream>> _fetchStreamsIsolate(String imdbId) async {
    return await TorrentioService.getStreams(imdbId);
  }

  void _initPlayer(int index) {
    if (index < 0 || index >= _streams.length) return;
    final stream = _streams[index];
    final magnet = stream.magnetUri;

    // Debug logging
    debugPrint('[PlayerScreen] Selected stream: ${stream.quality} - ${stream.name}');
    debugPrint('[PlayerScreen] Magnet: ${magnet.substring(0, magnet.length.clamp(0, 100))}...');

    // Validate magnet
    if (magnet.isEmpty) {
      debugPrint('[PlayerScreen] ERROR: Empty magnet URI for stream');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Magnet link unavailable for this stream.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _activeIndex = index);
    }

    final title = '${widget.movie.title} - ${stream.quality}';

    // For Windows, try in-app P2P streaming via WebTorrent
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      _startWindowsTorrentStream(magnet);
      return;
    }

    final bool isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (isDesktop) {
      debugPrint('[PlayerScreen] Desktop - Launching magnet link in external app: $magnet');
      launchUrl(Uri.parse(magnet), mode: LaunchMode.externalApplication).then((success) {
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to open default torrent client. Please install one (e.g. qBittorrent).')),
          );
        }
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StreamScreen(
          magnetLink: magnet,
          title: title,
        ),
      ),
    );
  }

  Future<void> _downloadTorrent() async {
    if (_activeIndex >= _streams.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a quality first to download'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final stream = _streams[_activeIndex];

    if (stream.magnetUri.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Magnet link unavailable for download.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    DownloadService.instance.addDownload(
      widget.movie.title,
      '2h 00m',
      stream.quality,
      widget.movie.posterUrl,
      magnetUri: stream.magnetUri,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${widget.movie.title}" (${stream.quality}) added to downloads queue!'),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }

  @override
  void dispose() {
    _windowsTorrentService?.dispose();
    _betterPlayerController?.dispose();
    _webVideoPlayerController?.dispose();
    _chewieController?.dispose();
    _mediaKitPlayer?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.space) {
            if (_mediaKitPlayer != null) {
              _mediaKitPlayer!.playOrPause();
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowRight) {
            if (_mediaKitPlayer != null) {
              final currentPosition = _mediaKitPlayer!.state.position;
              final maxDuration = _mediaKitPlayer!.state.duration;
              final newPosition = currentPosition + const Duration(seconds: 10);
              _mediaKitPlayer!.seek(newPosition > maxDuration ? maxDuration : newPosition);
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowLeft) {
            if (_mediaKitPlayer != null) {
              final currentPosition = _mediaKitPlayer!.state.position;
              final newPosition = currentPosition - const Duration(seconds: 10);
              _mediaKitPlayer!.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowUp) {
            if (_mediaKitPlayer != null) {
              final currentVolume = _mediaKitPlayer!.state.volume;
              _mediaKitPlayer!.setVolume((currentVolume + 5.0).clamp(0.0, 100.0));
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.arrowDown) {
            if (_mediaKitPlayer != null) {
              final currentVolume = _mediaKitPlayer!.state.volume;
              _mediaKitPlayer!.setVolume((currentVolume - 5.0).clamp(0.0, 100.0));
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(child: _buildPlayer()),
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
          if (!_isDirectPlayback && _streams.isNotEmpty)
            Positioned(bottom: 10, left: 0, right: 0, child: _buildQualityBar()),
        ]),
      ),
    );
  }

  Widget _buildPlayer() {
    if (_hasError) {
      final bool isMovieBoxWebError = kIsWeb &&
          widget.directUrl != null &&
          (widget.directUrl!.contains('hakunaymatata.com') || widget.directUrl!.contains('aoneroom.com'));

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              if (isMovieBoxWebError) ...[
                const Text(
                  'MovieBox stream access was denied by the CDN (403 Forbidden).',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aoneroom CDN restricts free guest playback on PC browsers.\n'
                  'To play MovieBox streams on Web, please obtain your JWT token from h5.aoneroom.com and paste it under Settings > Preferences.\n'
                  'Alternatively, go back and select an Archive.org stream instead.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
          const SizedBox(height: 16),
          Text(_statusMessage,
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ));
    }

    if (kIsWeb && _webPlayUrl != null) {
      return WebVideoPlayerWidget(
        url: _webPlayUrl!, 
        referer: widget.referer ?? (widget.directUrl != null && (widget.directUrl!.contains('hakunaymatata.com') || widget.directUrl!.contains('aoneroom.com')) ? 'https://h5.aoneroom.com/' : null),
        token: MovieBoxService.token,
      );
    }

    if (_mediaKitVideoController != null) {
      return mkv.MaterialVideoControlsTheme(
        normal: mkv.MaterialVideoControlsThemeData(
          buttonBarButtonColor: Colors.white,
          buttonBarButtonSize: 22.0,
          seekBarMargin: const EdgeInsets.only(bottom: 58.0, left: 16.0, right: 16.0),
          seekBarHeight: 4.0,
          seekBarThumbSize: 12.0,
          bottomButtonBarMargin: const EdgeInsets.only(bottom: 8.0, left: 16.0, right: 16.0),
          bottomButtonBar: [
            const mkv.MaterialPlayOrPauseButton(),
            const mkv.MaterialDesktopVolumeButton(),
            const mkv.MaterialPositionIndicator(),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.speed_rounded, color: Colors.white),
              iconSize: 20.0,
              onPressed: () => _showSpeedSelector(),
              tooltip: 'Playback Speed',
            ),
            IconButton(
              icon: const Icon(Icons.audiotrack_rounded, color: Colors.white),
              iconSize: 20.0,
              onPressed: () => _showMultiStreamSelector(),
              tooltip: 'Switch Audio Language',
            ),
            const mkv.MaterialFullscreenButton(),
          ],
        ),
        fullscreen: mkv.MaterialVideoControlsThemeData(
          buttonBarButtonColor: Colors.white,
          buttonBarButtonSize: 22.0,
          seekBarMargin: const EdgeInsets.only(bottom: 58.0, left: 16.0, right: 16.0),
          seekBarHeight: 4.0,
          seekBarThumbSize: 12.0,
          bottomButtonBarMargin: const EdgeInsets.only(bottom: 8.0, left: 16.0, right: 16.0),
          bottomButtonBar: [
            const mkv.MaterialPlayOrPauseButton(),
            const mkv.MaterialDesktopVolumeButton(),
            const mkv.MaterialPositionIndicator(),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.speed_rounded, color: Colors.white),
              iconSize: 20.0,
              onPressed: () => _showSpeedSelector(),
              tooltip: 'Playback Speed',
            ),
            IconButton(
              icon: const Icon(Icons.audiotrack_rounded, color: Colors.white),
              iconSize: 20.0,
              onPressed: () => _showMultiStreamSelector(),
              tooltip: 'Switch Audio Language',
            ),
            const mkv.MaterialFullscreenButton(),
          ],
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final tapPosition = details.globalPosition.dx;
            final currentPosition = _mediaKitPlayer!.state.position;
            
            _indicatorTimer?.cancel();
            if (tapPosition < screenWidth / 2) {
              final newPosition = currentPosition - const Duration(seconds: 10);
              _mediaKitPlayer!.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
              setState(() {
                _showLeftIndicator = true;
                _showRightIndicator = false;
              });
            } else {
              final newPosition = currentPosition + const Duration(seconds: 10);
              final maxDuration = _mediaKitPlayer!.state.duration;
              final seekTarget = (newPosition > maxDuration) ? maxDuration : newPosition;
              _mediaKitPlayer!.seek(seekTarget);
              setState(() {
                _showLeftIndicator = false;
                _showRightIndicator = true;
              });
            }
            _indicatorTimer = Timer(const Duration(milliseconds: 650), () {
              if (mounted) {
                setState(() {
                  _showLeftIndicator = false;
                  _showRightIndicator = false;
                });
              }
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              mkv.Video(
                controller: _mediaKitVideoController!,
                controls: mkv.MaterialVideoControls,
              ),
              if (_showLeftIndicator)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width / 2,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fast_rewind_rounded, color: Colors.white, size: 36),
                          SizedBox(height: 6),
                          Text('10s', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_showRightIndicator)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width / 2,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fast_forward_rounded, color: Colors.white, size: 36),
                          SizedBox(height: 6),
                          Text('10s', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (_isDirectPlayback) {
      if (_chewieController != null) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final tapPosition = details.globalPosition.dx;
            final videoController = _chewieController!.videoPlayerController;
            final currentPosition = videoController.value.position;
            
            if (tapPosition < screenWidth / 2) {
              // Double tapped on Left Half -> Rewind 10s
              final newPosition = currentPosition - const Duration(seconds: 10);
              videoController.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⏪ -10 seconds'),
                  duration: Duration(milliseconds: 600),
                  behavior: SnackBarBehavior.floating,
                  width: 120,
                ),
              );
            } else {
              // Double tapped on Right Half -> Forward 10s
              final newPosition = currentPosition + const Duration(seconds: 10);
              final maxDuration = videoController.value.duration;
              final seekTarget = (maxDuration != null && newPosition > maxDuration) ? maxDuration : newPosition;
              videoController.seekTo(seekTarget);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⏩ +10 seconds'),
                  duration: Duration(milliseconds: 600),
                  behavior: SnackBarBehavior.floating,
                  width: 120,
                ),
              );
            }
          },
          child: Chewie(controller: _chewieController!),
        );
      }
      if (_betterPlayerController != null) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final tapPosition = details.globalPosition.dx;
            
            if (_betterPlayerController!.videoPlayerController != null) {
              final videoController = _betterPlayerController!.videoPlayerController!;
              final currentPosition = videoController.value.position;
              
              if (tapPosition < screenWidth / 2) {
                final newPosition = currentPosition - const Duration(seconds: 10);
                videoController.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⏪ -10 seconds'),
                    duration: Duration(milliseconds: 600),
                    behavior: SnackBarBehavior.floating,
                    width: 120,
                  ),
                );
              } else {
                final newPosition = currentPosition + const Duration(seconds: 10);
                final maxDuration = videoController.value.duration;
                final seekTarget = (maxDuration != null && newPosition > maxDuration) ? maxDuration : newPosition;
                videoController.seekTo(seekTarget);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⏩ +10 seconds'),
                    duration: Duration(milliseconds: 600),
                    behavior: SnackBarBehavior.floating,
                    width: 120,
                  ),
                );
              }
            }
          },
          child: BetterPlayer(controller: _betterPlayerController!),
        );
      }
      return const Center(child: Text(
        'Failed to load video.',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ));
    }

    if (kIsWeb) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'P2P Torrent streams cannot be played in a sandboxed web browser.',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please go back and select a MovieBox or Archive.org stream instead.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_streams.isEmpty) {
      return const Center(child: Text(
        'No torrent streams available.\nThis movie requires an IMDb ID.',
        style: TextStyle(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      ));
    }

    return const Center(child: Text(
      'Select a quality below to start streaming',
      style: TextStyle(color: Colors.white70, fontSize: 14),
    ));
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(bottom: false, child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(child: Text(widget.movie.title,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14,
              fontWeight: FontWeight.w700))),
        if (_mediaKitPlayer != null || _alternativeLanguageStreams.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.audiotrack, color: Colors.white, size: 20),
            tooltip: 'Change Audio Language',
            onPressed: () {
              if (_alternativeLanguageStreams.isNotEmpty) {
                _showMultiStreamSelector();
              } else {
                _showAudioTrackSelector();
              }
            },
          ),
        IconButton(
          icon: const Icon(Icons.dns_rounded, color: Colors.white, size: 20),
          tooltip: 'Alternative Playing Links',
          onPressed: () => _showAlternativeServersSheet(),
        ),
        if (!_isDirectPlayback && _streams.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white, size: 20),
            onPressed: _downloadTorrent,
          ),
      ])),
    );
  }

  void _showAudioTrackSelector() {
    if (_mediaKitPlayer == null) return;
    
    final tracks = _mediaKitPlayer!.state.tracks.audio;
    final currentTrack = _mediaKitPlayer!.state.track.audio;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'Select Audio Track',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 16),
                    if (tracks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No alternative audio tracks found',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: tracks.length,
                          itemBuilder: (context, index) {
                            final track = tracks[index];
                            final isSelected = track.id == currentTrack.id;
                            
                            String trackName = 'Track ${index + 1}';
                            if (track.title != null && track.title!.isNotEmpty) {
                              trackName = track.title!;
                            } else if (track.language != null && track.language!.isNotEmpty) {
                              trackName = track.language!.toUpperCase();
                            }
                            if (track.id == 'no') {
                              trackName = 'Mute';
                            }
                            
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                              leading: Icon(
                                isSelected ? Icons.check_circle : Icons.audiotrack,
                                color: isSelected ? Colors.greenAccent : Colors.white30,
                                size: 20,
                              ),
                              title: Text(
                                trackName,
                                style: TextStyle(
                                  color: isSelected ? Colors.greenAccent : Colors.white,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              onTap: () {
                                _mediaKitPlayer!.setAudioTrack(track);
                                setModalState(() {});
                                setState(() {});
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Audio switched to: $trackName'),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    width: 250,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _switchLanguageStream(int index) async {
    if (index < 0 || index >= _alternativeLanguageStreams.length) return;
    
    final selected = _alternativeLanguageStreams[index];
    final targetUrl = selected['url']!;
    final languageName = selected['language']!;

    if (kIsWeb) {
      final position = _webVideoPlayerController?.value.position ?? Duration.zero;
      if (mounted) setState(() { _loading = true; _statusMessage = 'Switching to $languageName...'; });
      
      final oldVc = _webVideoPlayerController;
      final oldCc = _chewieController;
      _webVideoPlayerController = null;
      _chewieController = null;
      
      if (oldVc != null) await oldVc.dispose();
      if (oldCc != null) oldCc.dispose();
      
      _currentLanguageStreamIndex = index;
      await _initNetworkPlayer(targetUrl);
      
      if (_webVideoPlayerController != null) {
        await _webVideoPlayerController!.seekTo(position);
        await _webVideoPlayerController!.play();
      }
      return;
    }

    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    if (!isWindows) {
      // Android / iOS native: uses video_player + chewie controllers instead of media_kit
      final position = _chewieController?.videoPlayerController.value.position ?? Duration.zero;
      if (mounted) setState(() { _loading = true; _statusMessage = 'Switching to $languageName...'; });

      final oldVc = _webVideoPlayerController;
      final oldCc = _chewieController;
      _webVideoPlayerController = null;
      _chewieController = null;

      if (oldVc != null) await oldVc.dispose();
      if (oldCc != null) oldCc.dispose();

      _currentLanguageStreamIndex = index;
      _isDirectPlayback = true; // Mark as direct to use Chewie controller layouts
      await _initNetworkPlayer(targetUrl);

      if (_chewieController != null) {
        await _chewieController!.videoPlayerController.seekTo(position);
        await _chewieController!.videoPlayerController.play();
      }
      return;
    }

    if (_mediaKitPlayer == null) return;
    
    // Save position before disposing
    final position = _mediaKitPlayer!.state.position;
    
    if (mounted) setState(() { _loading = true; _statusMessage = 'Switching to $languageName...'; });
    
    // 1. Clear old controller references and rebuild UI first
    final oldPlayer = _mediaKitPlayer!;
    if (mounted) {
      setState(() {
        _mediaKitPlayer = null;
        _mediaKitVideoController = null;
        _currentLanguageStreamIndex = index;
      });
    } else {
      _mediaKitPlayer = null;
      _mediaKitVideoController = null;
      _currentLanguageStreamIndex = index;
    }
    
    // 2. Wait for UI thread to finish frame rendering so mkv.Video is unmounted
    await Future.delayed(const Duration(milliseconds: 150));
    
    // 3. Safely dispose the old native player in the background
    oldPlayer.dispose().catchError((_) {});
    
    // Create new player + controller
    final player = mk.Player();
    player.stream.error.listen((error) {
      debugPrint('[PlayerScreen] Language stream error: $error');
      
      final nextIndex = _currentLanguageStreamIndex + 1;
      if (nextIndex < _alternativeLanguageStreams.length) {
        debugPrint('[PlayerScreen] Switched stream failed. Trying next alternative stream at index $nextIndex...');
        _switchLanguageStream(nextIndex);
        return;
      }

      _setError('Direct stream playback failed. Please go back and select a different streaming source.');
    });
    
    // Apply identical buffer properties on the new player instance
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final dynamic native = player.platform;
        await native.setProperty('demuxer-max-bytes', '128MiB');
        await native.setProperty('demuxer-readahead-secs', '60');
        await native.setProperty('cache-secs', '60');
        await native.setProperty('network-timeout', '30');
      } catch (_) {}
    }

    final controller = mkv.VideoController(player);
    
    // CRITICAL: setState before opening media so Video widget attaches to new controller
    if (mounted) {
      setState(() {
        _mediaKitPlayer = player;
        _mediaKitVideoController = controller;
      });
    } else {
      _mediaKitPlayer = player;
      _mediaKitVideoController = controller;
    }
    
    final proxyPort = LocalStreamingProxy.instance.port;
    String rawUrl = targetUrl;
    
    final bool isMovieBoxCdn = rawUrl.contains('hakunaymatata.com') || rawUrl.contains('aoneroom.com');
    String ref = widget.referer ?? (isMovieBoxCdn ? 'https://h5.aoneroom.com/' : '');
    
    if (rawUrl.contains('|referer=')) {
      final parts = rawUrl.split('|referer=');
      rawUrl = parts[0];
      if (parts.length > 1) ref = parts[1];
    }
    
    final authParam = (isMovieBoxCdn && MovieBoxService.token != null)
        ? '&auth=${Uri.encodeComponent('Bearer ${MovieBoxService.token}')}' 
        : '';
        
    final bool isArchive = rawUrl.contains('archive.org');
    if (isArchive) {
      const cfWorker = 'https://long-wind-ad98.avinashbiradar722.workers.dev/';
      rawUrl = '$cfWorker?url=${Uri.encodeComponent(rawUrl)}';
    }
    
    final refParam = ref.isNotEmpty ? '&referer=${Uri.encodeComponent(ref)}' : '';
    final playUrl = 'http://127.0.0.1:$proxyPort/play?url=${Uri.encodeComponent(rawUrl)}$refParam$authParam';
    debugPrint('[PlayerScreen] Switching language stream → $languageName: $playUrl');
    
    // Open and start playing immediately
    await player.open(mk.Media(playUrl), play: true);
    
    // Wait for playlist to load before seeking
    if (position.inSeconds > 2) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (_mediaKitPlayer != null && mounted) {
        await player.seek(position);
      }
    }
    
    if (mounted) {
      setState(() { _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('▶ $languageName stream loaded'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 220,
        ),
      );
    }
  }

  void _showMultiStreamSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Select Audio Language',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Divider(color: Colors.white10, height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _alternativeLanguageStreams.length,
                    itemBuilder: (context, index) {
                      final stream = _alternativeLanguageStreams[index];
                      final isSelected = index == _currentLanguageStreamIndex;
                      final languageName = stream['language']!;
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                        leading: Icon(
                          isSelected ? Icons.check_circle : Icons.audiotrack,
                          color: isSelected ? Colors.greenAccent : Colors.white30,
                          size: 20,
                        ),
                        title: Text(
                          languageName,
                          style: TextStyle(
                            color: isSelected ? Colors.greenAccent : Colors.white,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _switchLanguageStream(index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSpeedSelector() {
    if (_mediaKitPlayer == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final currentRate = _mediaKitPlayer!.state.rate;
        final rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white10),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    'Playback Speed',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                ...rates.map((r) {
                  final isSelected = r == currentRate;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.speed,
                      color: isSelected ? Colors.greenAccent : Colors.white30,
                    ),
                    title: Text(
                      '${r}x',
                      style: TextStyle(
                        color: isSelected ? Colors.greenAccent : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _mediaKitPlayer!.setRate(r);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('⚡ Speed set to ${r}x'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          width: 150,
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchAlternativeSources() async {
    final title = widget.movie.title;
    final yearVal = int.tryParse(widget.movie.year);
    final imdb = widget.imdbId ?? '';

    try {
      final results = await Future.wait([
        imdb.startsWith('tt')
            ? TorrentioService.getStreams(imdb)
            : Future.value(<TorrentStream>[]),
        MovieBoxService.resolveStreams(
          title,
          tmdbId: widget.movie.id,
          imdbId: imdb.isNotEmpty ? imdb : null,
        ),
        ArchiveService.resolveStreams(title, year: yearVal, imdbId: imdb.isNotEmpty ? imdb : null),
      ]);
      if (mounted) {
        setState(() {
          _bgTorrents = results[0] as List<TorrentStream>;
          _bgMovieBox = results[1] as List<MovieBoxStream>;
          _bgArchives = results[2] as List<ArchiveStream>;
          _bgLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Background pre-fetch error: $e');
      if (mounted) {
        setState(() {
          _bgLoading = false;
        });
      }
    }
  }

  Future<void> _switchStreamSource(String url, {String? referer, String? subjectId, String? detailPath, int? resolution}) async {
    if (kIsWeb) {
      final position = _webVideoPlayerController?.value.position ?? Duration.zero;
      if (mounted) setState(() { _loading = true; _statusMessage = 'Switching server...'; });
      
      final oldVc = _webVideoPlayerController;
      final oldCc = _chewieController;
      _webVideoPlayerController = null;
      _chewieController = null;
      
      if (oldVc != null) await oldVc.dispose();
      if (oldCc != null) oldCc.dispose();
      
      await _initNetworkPlayer(url);
      
      if (_webVideoPlayerController != null) {
        await _webVideoPlayerController!.seekTo(position);
        await _webVideoPlayerController!.play();
      }
      return;
    }

    if (_mediaKitPlayer == null) return;
    
    // Save position before disposing
    final position = _mediaKitPlayer!.state.position;
    
    if (mounted) setState(() { _loading = true; _statusMessage = 'Switching server...'; });
    
    // 1. Clear old controller references and rebuild UI first
    final oldPlayer = _mediaKitPlayer!;
    if (mounted) {
      setState(() {
        _mediaKitPlayer = null;
        _mediaKitVideoController = null;
      });
    } else {
      _mediaKitPlayer = null;
      _mediaKitVideoController = null;
    }
    
    // 2. Wait for UI thread to finish frame rendering so mkv.Video is unmounted
    await Future.delayed(const Duration(milliseconds: 150));
    
    // 3. Safely dispose the old native player in the background
    oldPlayer.dispose().catchError((_) {});
    
    // Handle magnet link
    if (_isMagnetLink(url)) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        _startWindowsTorrentStream(url);
        return;
      }
    }
    
    // Create new player + controller
    final player = mk.Player();
    player.stream.error.listen((error) {
      debugPrint('[PlayerScreen] Stream error: $error');
      _setError('Direct stream playback failed. Please try another server.');
    });
    
    player.stream.width.listen((width) {
      if (width != null && width > 0 && _loading) {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    });
    
    // Apply identical buffer properties on the new player instance
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final dynamic native = player.platform;
        await native.setProperty('demuxer-max-bytes', '4MiB');
        await native.setProperty('demuxer-readahead-secs', '5');
        await native.setProperty('cache-secs', '5');
        await native.setProperty('network-timeout', '30');
      } catch (_) {}
    }

    final controller = mkv.VideoController(player);
    
    if (mounted) {
      setState(() {
        _mediaKitPlayer = player;
        _mediaKitVideoController = controller;
      });
    } else {
      _mediaKitPlayer = player;
      _mediaKitVideoController = controller;
    }
    
    final proxyPort = LocalStreamingProxy.instance.port;
    String rawUrl = url;
    
    final bool isMovieBoxCdn = rawUrl.contains('hakunaymatata.com') || rawUrl.contains('aoneroom.com');
    String refVal = referer ?? (widget.referer ?? (isMovieBoxCdn ? 'https://h5.aoneroom.com/' : ''));
    
    if (rawUrl.contains('|referer=')) {
      final parts = rawUrl.split('|referer=');
      rawUrl = parts[0];
      if (parts.length > 1) refVal = parts[1];
    }
    
    final authParam = (isMovieBoxCdn && MovieBoxService.token != null)
        ? '&auth=${Uri.encodeComponent('Bearer ${MovieBoxService.token}')}' 
        : '';
        
    final bool isArchive = rawUrl.contains('archive.org');
    if (isArchive) {
      const cfWorker = 'https://long-wind-ad98.avinashbiradar722.workers.dev/';
      rawUrl = '$cfWorker?url=${Uri.encodeComponent(rawUrl)}';
    }
    
    final refParam = refVal.isNotEmpty ? '&referer=${Uri.encodeComponent(refVal)}' : '';
    final playUrl = 'http://127.0.0.1:$proxyPort/play?url=${Uri.encodeComponent(rawUrl)}$refParam$authParam';
    
    if (mounted) {
      setState(() {
        _statusMessage = 'Buffering video segment... (Starting in 5-6s)';
      });
    }
    await player.open(mk.Media(playUrl), play: true);
    if (position > Duration.zero) {
      await player.seek(position);
    }
  }

  void _showAlternativeServersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        if (_bgLoading) {
          return const SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.accent),
                    SizedBox(height: 16),
                    Text('Loading other links...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Select Other Link',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: AppColors.border),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final List<Widget> listChildren = [];

                    // MovieBox
                    if (_bgMovieBox.isNotEmpty) {
                      listChildren.add(
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text(
                            'MovieBox Server',
                            style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                      listChildren.addAll(_bgMovieBox.map((s) {
                        final langSuffix = s.language.isNotEmpty ? ' [${s.language}]' : '';
                        return ListTile(
                          leading: const Icon(Icons.play_circle_filled, color: AppColors.accent),
                          title: Text('MovieBox ${s.resolution}p$langSuffix', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: Text('Direct stream - ${s.size}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          onTap: () async {
                            Navigator.pop(context);
                            MovieBoxStream freshStream = s;
                            try {
                              freshStream = await MovieBoxService.refreshUrl(s);
                            } catch (_) {}
                            _switchStreamSource(
                              freshStream.url,
                              referer: freshStream.referer,
                              subjectId: freshStream.subjectId,
                              detailPath: freshStream.detailPath,
                              resolution: freshStream.resolution,
                            );
                          },
                        );
                      }));
                    }

                    // Archive
                    if (_bgArchives.isNotEmpty) {
                      listChildren.add(
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text(
                            'Archive.org Server',
                            style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                      listChildren.addAll(_bgArchives.map((a) {
                        final langSuffix = a.language.isNotEmpty ? ' [${a.language}]' : '';
                        return ListTile(
                          leading: const Icon(Icons.play_circle_filled, color: Colors.blueAccent),
                          title: Text('${a.label}$langSuffix', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Direct CDN stream', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          onTap: () {
                            Navigator.pop(context);
                            _switchStreamSource(a.url);
                          },
                        );
                      }));
                    }

                    // Torrents
                    if (_bgTorrents.isNotEmpty) {
                      listChildren.add(
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text(
                            'Torrent Streams (Copy Link)',
                            style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                      listChildren.addAll(_bgTorrents.map((t) {
                        final titleLine = t.title.split('\n').first;
                        return ListTile(
                          leading: const Icon(Icons.copy_rounded, color: AppColors.accent),
                          title: Text(t.quality, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: Text('$titleLine (${t.size})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(context);
                            await Clipboard.setData(ClipboardData(text: t.magnetUri));
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Magnet link copied to clipboard!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          },
                        );
                      }));
                      listChildren.add(
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          child: Text(
                            '💡 To play or download: Copy link and paste it into WebTorrent, qBittorrent, or VLC Player.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                      );
                    }

                    if (listChildren.isEmpty) {
                      return const Center(child: Text('No alternative servers available.', style: TextStyle(color: Colors.white70)));
                    }

                    return ListView(children: listChildren);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQualityBar() {
    return Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.only(left: 6, right: 4),
            child: Text('Quality:',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
          ),
          ..._streams.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final active = i == _activeIndex;
            return GestureDetector(
              onTap: () => _initPlayer(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.greenAccent.withValues(alpha: 0.85)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active
                          ? Colors.greenAccent
                          : Colors.green.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${s.quality} [${s.size.isNotEmpty ? s.size : "?"}]',
                  style: TextStyle(
                    color: active ? Colors.black : Colors.greenAccent,
                    fontSize: 10, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }),
        ]),
      ),
    ));
  }
}
