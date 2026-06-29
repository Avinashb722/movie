import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';


import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../services/download_service.dart';
import '../services/torrentio_service.dart';
import '../services/archive_service.dart';
import '../services/moviebox_service.dart';
import '../services/watchlist_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'player_screen.dart';
import '../services/two_embed_service.dart';
import '../widgets/web_iframe.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;
  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  MovieDetail? _detail;
  List<Movie>  _similar = [];
  bool _loading = true;
  bool _expandPlot = false;
  WebViewController? _webViewController;
  bool _playTrailer = false;
  bool _loadingTrailer = false;


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      TmdbService.getDetail(widget.movie.id),
      TmdbService.getSimilar(widget.movie.id),
    ]);
    if (mounted) {
      setState(() {
        _detail  = results[0] as MovieDetail?;
        _similar = results[1] as List<Movie>;
        _loading = false;
      });
    }
  }

  Future<void> _startTrailerPlayback() async {
    if (_detail == null || _detail!.trailerYoutubeKey.isEmpty) return;
    if (kIsWeb) {
      setState(() {
        _playTrailer = true;
      });
      return;
    }

    setState(() {
      _loadingTrailer = true;
    });

    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')
        ..setBackgroundColor(Colors.black);

      if (controller.platform is AndroidWebViewController) {
        (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }

      final String hiderJs = '''
        (function() {
          function injectStyle(root) {
            if (!root) return;
            var id = 'yt-custom-style-clean';
            if (root.getElementById && root.getElementById(id)) return;
            var style = document.createElement('style');
            style.id = id;
            style.innerHTML = `
              .ytp-youtube-button,
              .ytp-watermark,
              .ytp-chrome-top,
              .ytp-impression-link,
              .ytp-contextmenu,
              .ytp-large-play-button-red,
              .ytp-chrome-top-buttons,
              .ytp-show-share-title,
              .ytp-share-button,
              .ytp-watch-later-button,
              .ytp-pause-overlay,
              .ytp-title,
              .ytp-header,
              .ytp-title-channel-logo,
              .ytp-logo,
              .ytp-chrome-bottom .ytp-youtube-button,
              .ytp-chrome-controls .ytp-youtube-button,
              a[href*="youtube.com"],
              a[href*="youtu.be"],
              .ytp-small-mode .ytp-chrome-top,
              .ytp-chrome-top.ytp-share-button-visible {
                display: none !important;
                visibility: hidden !important;
                opacity: 0 !important;
                pointer-events: none !important;
              }
            `;
            if (root.appendChild) {
              root.appendChild(style);
            }
          }

          function cleanRecursive(root) {
            if (!root) return;
            injectStyle(root);
            
            var sel = [
              '.ytp-youtube-button', 
              '.ytp-watermark', 
              '.ytp-chrome-top', 
              '.ytp-impression-link', 
              '.ytp-contextmenu', 
              '.ytp-large-play-button-red',
              '.ytp-chrome-top-buttons',
              '.ytp-show-share-title',
              '.ytp-share-button',
              '.ytp-watch-later-button',
              '.ytp-pause-overlay',
              '.ytp-title',
              '.ytp-header',
              '.ytp-title-channel-logo',
              '.ytp-logo',
              'a[href*="youtube.com"]',
              'a[href*="youtu.be"]'
            ].join(',');
            
            if (root.querySelectorAll) {
              var elements = root.querySelectorAll(sel);
              for (var i = 0; i < elements.length; i++) {
                elements[i].style.setProperty('display', 'none', 'important');
                elements[i].style.setProperty('visibility', 'hidden', 'important');
                elements[i].style.setProperty('opacity', '0', 'important');
                elements[i].style.setProperty('pointer-events', 'none', 'important');
              }
            }
            
            var children = root.querySelectorAll ? root.querySelectorAll('*') : [];
            for (var i = 0; i < children.length; i++) {
              if (children[i].shadowRoot) {
                cleanRecursive(children[i].shadowRoot);
              }
            }
          }

          cleanRecursive(document.head || document.documentElement);
          cleanRecursive(document.body);

          if (!window.hasYtCleanerStarted) {
            window.hasYtCleanerStarted = true;
            setInterval(function() {
              cleanRecursive(document.head || document.documentElement);
              cleanRecursive(document.body);
            }, 100);
          }
        })();
      ''';

      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            controller.runJavaScript(hiderJs);
          },
          onPageFinished: (String url) {
            controller.runJavaScript(hiderJs);
          },
          onNavigationRequest: (NavigationRequest request) async {
            if (request.url.contains('youtube.com/watch') || request.url.contains('youtu.be/')) {
              try {
                await launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
              } catch (_) {}
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

      controller.loadRequest(
        Uri.parse('https://www.youtube.com/embed/${_detail!.trailerYoutubeKey}?autoplay=1&mute=0&controls=0&rel=0&showinfo=0&modestbranding=1&playsinline=1&enablejsapi=1&iv_load_policy=3&fs=0&origin=https://www.themoviedb.org'),
        headers: {
          'Referer': 'https://www.themoviedb.org/',
        },
      );





      if (mounted) {
        setState(() {
          _webViewController = controller;
          _playTrailer = true;
          _loadingTrailer = false;
        });
      }
    } catch (e) {
      debugPrint('[MovieDetail] Play trailer error: $e');
      if (mounted) {
        setState(() {
          _loadingTrailer = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final m = _detail ?? widget.movie;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading && _detail == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : CustomScrollView(
        slivers: [
          // ── Backdrop Hero ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Backdrop image / Trailer Player
                  _playTrailer
                      ? (kIsWeb 
                          ? IgnorePointer(
                              child: ClipRect(
                                child: OverflowBox(
                                  minHeight: 440,
                                  maxHeight: 440,
                                  child: createWebIframe(_detail!.trailerYoutubeKey),
                                ),
                              ),
                            )
                          : (_webViewController != null 
                              ? WebViewWidget(controller: _webViewController!)
                              : const Center(child: CircularProgressIndicator(color: AppColors.accent))))
                      : (m.backdropUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: m.backdropUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(color: AppColors.card)),
                  
                  // Play button / Spinner Overlay
                  if (!_playTrailer && _detail != null && _detail!.trailerYoutubeKey.isNotEmpty)
                    Center(
                      child: _loadingTrailer
                          ? const CircularProgressIndicator(color: AppColors.accent)
                          : Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                iconSize: 56,
                                icon: const Icon(Icons.play_arrow_rounded, color: AppColors.accent),
                                onPressed: _startTrailerPlayback,
                              ),
                            ),
                    ),

                  // Gradient bottom
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                          stops: [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Movie Info ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    m.title.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Meta row: year • genre • runtime • quality
                  Wrap(
                    spacing: 0,
                    children: [
                      _metaText(m.year),
                      if (_detail != null && _detail!.genres.isNotEmpty)
                        _metaText(' • ${_detail!.genres.first}'),
                      if (_detail != null && _detail!.runtimeStr.isNotEmpty)
                        _metaText(' • ${_detail!.runtimeStr}'),
                      _metaText(' • 4K • Dolby Vision'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.accent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${m.rating.toStringAsFixed(1)}/10',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textMuted),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('IMDb', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Action Buttons Section ─────────────────────────────────────
                  if (defaultTargetPlatform == TargetPlatform.android) ...[
                    // Android Layout: 2 Rows of 2 Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.play_arrow_rounded,
                            label: 'Play Direct',
                            filled: true,
                            onTap: _startDirect2EmbedFlow,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.alt_route_rounded,
                            label: 'Other Links',
                            filled: false,
                            onTap: _startAlternativeServersFlow,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<List<Movie>>(
                            valueListenable: WatchlistService.instance.watchlistNotifier,
                            builder: (context, watchlist, _) {
                              final inWatchlist = WatchlistService.instance.isInWatchlist(m.id);
                              return _ActionButton(
                                icon: inWatchlist ? Icons.check : Icons.add,
                                label: inWatchlist ? 'Added' : 'My List',
                                filled: inWatchlist,
                                onTap: () async {
                                  await WatchlistService.instance.toggleWatchlist(m);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        inWatchlist
                                            ? 'Removed from Watchlist!'
                                            : 'Added to Watchlist!',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: AppColors.surface,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.download_outlined,
                            label: 'Download',
                            filled: false,
                            onTap: _startDownloadFlow,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Desktop & Web Layout: 1 Row with Play, My List, Download
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _ActionButton(
                            icon: Icons.play_arrow,
                            label: 'Play',
                            filled: true,
                            onTap: _startPlayFlow,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ValueListenableBuilder<List<Movie>>(
                            valueListenable: WatchlistService.instance.watchlistNotifier,
                            builder: (context, watchlist, _) {
                              final inWatchlist = WatchlistService.instance.isInWatchlist(m.id);
                              return _ActionButton(
                                icon: inWatchlist ? Icons.check : Icons.add,
                                label: inWatchlist ? 'Added' : 'My List',
                                filled: inWatchlist,
                                onTap: () async {
                                  await WatchlistService.instance.toggleWatchlist(m);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        inWatchlist
                                            ? 'Removed from Watchlist!'
                                            : 'Added to Watchlist!',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: AppColors.surface,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.download_outlined,
                            label: 'Download',
                            filled: false,
                            onTap: _startDownloadFlow,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Plot ──────────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _expandPlot = !_expandPlot),
                    child: Text(
                      m.overview,
                      maxLines: _expandPlot ? 100 : 3,
                      overflow: _expandPlot ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13, height: 1.5),
                    ),
                  ),
                  if (!_expandPlot)
                    GestureDetector(
                      onTap: () => setState(() => _expandPlot = true),
                      child: const Text('Read More', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                    ),

                  // ── Genre chips ───────────────────────────
                  if (_detail != null && _detail!.genres.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _detail!.genres.map((g) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(g, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      )).toList(),
                    ),
                  ],

                  // ── Cast ──────────────────────────────────
                  if (_detail != null && _detail!.cast.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cast & Crew', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                        const Text('View All', style: TextStyle(color: AppColors.accent, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 115,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemCount: _detail!.cast.length,
                        itemBuilder: (_, i) {
                          final c = _detail!.cast[i];
                          return SizedBox(
                            width: 72,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: AppColors.card,
                                  backgroundImage: c.photoUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(c.photoUrl)
                                      : null,
                                  child: c.photoUrl.isEmpty
                                      ? const Icon(Icons.person, color: AppColors.textMuted)
                                      : null,
                                ),
                                const SizedBox(height: 4),
                                Text(c.name, maxLines: 2, textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
                                Text(c.character, maxLines: 1, textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // ── More Like This ────────────────────────
                  if (_similar.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('More Like This', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 175,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemCount: _similar.length,
                        itemBuilder: (_, i) {
                          final mv = _similar[i];
                          return GestureDetector(
                            onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: mv))),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: mv.posterUrl.isNotEmpty
                                      ? CachedNetworkImage(imageUrl: mv.posterUrl, width: 115, height: 165, fit: BoxFit.cover)
                                      : Container(width: 115, height: 165, color: AppColors.card),
                                ),
                                Positioned(
                                  bottom: 8, left: 8,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star, color: AppColors.accent, size: 11),
                                      const SizedBox(width: 2),
                                      Text(mv.rating.toStringAsFixed(1),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaText(String text) => Text(
    text,
    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
  );

  Future<void> _startDirect2EmbedFlow() async {
    final m = _detail ?? widget.movie;
    final imdb = _detail?.imdbId ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          backgroundColor: AppColors.card,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Loading 2Embed Direct Player...',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final streamUrl = await TwoEmbedService.instance.resolveStreamUrl(imdb, m.id.toString());
      if (mounted) Navigator.pop(context);
      if (streamUrl != null && streamUrl.isNotEmpty) {
        HistoryService.instance.addToHistory(m);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                movie: m,
                directUrl: streamUrl,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('2Embed stream unavailable. Trying all alternative servers...'),
              backgroundColor: Colors.amber,
            ),
          );
          _startAlternativeServersFlow();
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) _startAlternativeServersFlow();
    }
  }

  Future<void> _startAlternativeServersFlow() async {
    await _startPlayFlow();
  }

  Future<void> _startPlayFlow() async {
    final m = _detail ?? widget.movie;
    final title = m.title;
    final yearVal = int.tryParse(m.year);
    final imdb = _detail?.imdbId ?? '';

    debugPrint('[MovieDetail] Starting play flow for: $title (IMDB: $imdb)');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          backgroundColor: AppColors.card,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Searching streaming sources...',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );

    List<TorrentStream> torrents = [];
    List<MovieBoxStream> movieBoxStreams = [];
    List<ArchiveStream> archives = [];

    try {
      // Run all stream resolution concurrently
      final results = await Future.wait([
        imdb.startsWith('tt')
            ? TorrentioService.getStreams(imdb)
            : Future.value(<TorrentStream>[]),
        MovieBoxService.resolveStreams(
          title,
          tmdbId: m.id,
          imdbId: imdb.isNotEmpty ? imdb : null,
        ),
        ArchiveService.resolveStreams(title, year: yearVal, imdbId: imdb.isNotEmpty ? imdb : null),
      ]);
      torrents = results[0] as List<TorrentStream>;
      movieBoxStreams = results[1] as List<MovieBoxStream>;
      archives = results[2] as List<ArchiveStream>;
    } catch (e) {
      debugPrint('[MovieDetailScreen] Stream resolution error: $e');
    }

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

    debugPrint('[MovieDetail] Found: ${movieBoxStreams.length} MovieBox, ${archives.length} Archive, ${torrents.length} Torrent streams');

    if (torrents.isEmpty && archives.isEmpty && movieBoxStreams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No streaming sources found for this movie.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Select Streaming Option',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: AppColors.border),
              Expanded(
                child: ListView(
                  children: [
                    if (movieBoxStreams.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          'Direct Web Streaming (Recommended)',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      ...movieBoxStreams.map((s) {
                        final langSuffix = s.language.isNotEmpty ? ' [${s.language}]' : '';
                        return ListTile(
                          leading: const Icon(Icons.play_circle_filled, color: AppColors.accent),
                          title: Text(
                            'MovieBox ${s.resolution}p$langSuffix',
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Direct HTTP Stream - ${s.size.isNotEmpty ? s.size : "Unknown size"}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            final url = s.url;
                            debugPrint('[MovieDetail] Selected stream: MovieBox ${s.resolution}p');
                            debugPrint('[MovieDetail] URL: $url');
                            if (url.trim().isEmpty) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Stream unavailable'), backgroundColor: Colors.redAccent),
                              );
                              return;
                            }
                            HistoryService.instance.addToHistory(m);
                            Navigator.push(
                              this.context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  movie: m,
                                  directUrl: url,
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                    if (archives.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          'Direct Web Streaming (Archive)',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      ...archives.map((a) {
                        final langSuffix = a.language.isNotEmpty ? ' [${a.language}]' : '';
                        return ListTile(
                          leading: const Icon(Icons.play_circle_filled, color: Colors.blueAccent),
                          title: Text(
                            '${a.label}$langSuffix',
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Direct HLS/MP4 CDN Link',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            final url = a.url;
                            debugPrint('[MovieDetail] Selected stream: ${a.label}');
                            debugPrint('[MovieDetail] URL: $url');
                            if (url.trim().isEmpty) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Stream unavailable'), backgroundColor: Colors.redAccent),
                              );
                              return;
                            }
                            HistoryService.instance.addToHistory(m);
                            Navigator.push(
                              this.context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  movie: m,
                                  directUrl: url,
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                    if (torrents.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          'P2P Torrent Streaming (WebRTC)',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      ...torrents.map((t) {
                        final titleLine = t.title.split('\n').first;
                        return ListTile(
                          leading: const Icon(Icons.bolt, color: Colors.greenAccent),
                          title: Text(
                            t.quality,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '$titleLine (${t.size})',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            HistoryService.instance.addToHistory(m);
                            Navigator.push(
                              this.context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  movie: m,
                                  directUrl: t.magnetUri,
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startDownloadFlow() {
    _startPlayFlow();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: filled ? AppColors.accent : AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: filled ? null : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: filled ? Colors.black : AppColors.textPrimary, size: 18),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: filled ? Colors.black : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
