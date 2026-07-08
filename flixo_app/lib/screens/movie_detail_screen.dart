import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../utils/seo_helper.dart'
    if (dart.library.js) '../utils/seo_helper_web.dart';
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
import 'downloads_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../utils/globals.dart';

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
  int _selectedSeasonNumber = 1;
  int _selectedEpisodeNumber = 1;


  // Cache variables for fetched streams to speed up "Other Links" bottom sheet
  List<TorrentStream>? _cachedTorrents;
  List<MovieBoxStream>? _cachedMovieBoxStreams;
  List<ArchiveStream>? _cachedArchives;
  List<MovieBoxStream>? _cachedTwoEmbedStreams;
  DateTime? _cacheTime;

  @override
  void initState() {
    super.initState();
    _load();
    if (kIsWeb) {
      final titleSlug = widget.movie.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-');
      final pathPrefix = widget.movie.isTvShow ? 'tv' : 'movie';
      SystemNavigator.routeInformationUpdated(
        location: '/$pathPrefix/$titleSlug',
      );
      _updateMovieSeo(widget.movie, null);
    }
  }

  void _updateMovieSeo(Movie m, MovieDetail? d) {
    if (!kIsWeb) return;
    try {
      final titleSlug = m.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-');
          
      final pathPrefix = m.isTvShow ? 'tv' : 'movie';
      final canonicalUrl = 'https://www.movienest.app/$pathPrefix/$titleSlug';
      final year = m.releaseDate.isNotEmpty ? ' (${m.releaseDate.split("-").first})' : '';
      final title = '${m.title}$year - Watch Details | MovieNest';
      final description = 'Watch ${m.title}, cast, rating, overview, trailers and recommendations on MovieNest.';
      
      final genresList = d?.genres ?? [];

      final movieSchema = {
        "@context": "https://schema.org",
        "@type": m.isTvShow ? "TVSeries" : "Movie",
        "name": m.title,
        "image": m.backdropUrl.isNotEmpty ? m.backdropUrl : 'https://www.movienest.app/icons/Icon-512.png',
        "description": m.overview,
        "datePublished": m.releaseDate,
        "genre": genresList,
        "aggregateRating": {
          "@type": "AggregateRating",
          "ratingValue": m.rating.toStringAsFixed(1),
          "bestRating": "10",
          "ratingCount": "100"
        }
      };

      updateWebSeo(
        title,
        description,
        canonicalUrl,
        m.backdropUrl.isNotEmpty ? m.backdropUrl : 'https://www.movienest.app/icons/Icon-512.png',
        jsonEncode(movieSchema),
      );
    } catch (_) {}
  }

  Future<void> _load() async {
    final results = await Future.wait([
      TmdbService.getDetail(widget.movie.id, isTv: widget.movie.isTvShow),
      TmdbService.getSimilar(widget.movie.id, isTv: widget.movie.isTvShow),
    ]);
    if (mounted) {
      final detail = results[0] as MovieDetail?;
      setState(() {
        _detail  = detail;
        _similar = results[1] as List<Movie>;
        _loading = false;
      });
      if (kIsWeb) {
        _updateMovieSeo(widget.movie, detail);
      }
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

  String _indexToPath(int index) {
    switch (index) {
      case 0: return '/';
      case 1: return '/discover';
      case 2: return '/live-tv';
      case 3: return '/downloads';
      case 4: return '/watchlist';
      case 5: return '/history';
      case 6: return '/blog';
      case 7: return '/profile';
      case 8: return '/settings';
      case 9: return '/download-app';
      default: return '/';
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final currentTab = mainNavTabNotifier.value;
          SystemNavigator.routeInformationUpdated(location: _indexToPath(currentTab));
        } catch (_) {}
      });
    }
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
                onPressed: () {
                  final String yearText = m.year.isNotEmpty ? ' (${m.year})' : '';
                  final String genreText = (_detail != null && _detail!.genres.isNotEmpty)
                      ? '\n🎬 Genre: ${_detail!.genres.join(", ")}'
                      : '';
                  final String ratingText = m.rating > 0
                      ? '\n⭐️ Rating: ${m.rating.toStringAsFixed(1)}/10'
                      : '';
                  final String durationText = (_detail != null && _detail!.runtimeStr.isNotEmpty)
                      ? '\n⏱️ Duration: ${_detail!.runtimeStr}'
                      : '';
                  final String overviewText = m.overview.isNotEmpty
                      ? '\n\n📝 Storyline:\n${m.overview}'
                      : '';

                  final String shareContent = 
                      'Check out "${m.title}"$yearText on MovieNest!$genreText$ratingText$durationText\n\n'
                      '🔗 Watch & Download here: https://www.movienest.app/movie?id=${m.id}$overviewText';

                  Share.share(
                    shareContent,
                    subject: 'Share "${m.title}"',
                  );
                },
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
                  ValueListenableBuilder<bool>(
                    valueListenable: enableStreaming,
                    builder: (context, streamingEnabled, _) {
                      if (defaultTargetPlatform == TargetPlatform.android) {
                        if (streamingEnabled) {
                          return Column(
                            children: [
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
                                  Expanded(child: _watchlistButton(m)),
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
                            ],
                          );
                        } else {
                          // App Store Mode: Show ONLY Watchlist (My List) button
                          return Row(
                            children: [
                              Expanded(child: _watchlistButton(m)),
                            ],
                          );
                        }
                      } else {
                        // Desktop & Web Layout
                        if (streamingEnabled) {
                          return Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _ActionButton(
                                  icon: Icons.play_arrow_rounded,
                                  label: 'Play Direct',
                                  filled: true,
                                  onTap: _startDirect2EmbedFlow,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.alt_route_rounded,
                                  label: 'Other Links',
                                  filled: false,
                                  onTap: _startAlternativeServersFlow,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: _watchlistButton(m)),
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
                          );
                        } else {
                          // App Store Mode: Show ONLY Watchlist (My List) button
                          return Row(
                            children: [
                              Expanded(child: _watchlistButton(m)),
                            ],
                          );
                        }
                      }
                    },
                  ),
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

                  // ── Season & Episode Selectors (TV Series only) ──
                  if (_detail != null && _detail!.isTvShow && _detail!.seasons.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Seasons', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    
                    // Seasons Horizontal List
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _detail!.seasons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final s = _detail!.seasons[idx];
                          final isSelected = s.seasonNumber == _selectedSeasonNumber;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSeasonNumber = s.seasonNumber;
                                _selectedEpisodeNumber = 1; // Reset episode
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent : AppColors.card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
                              ),
                              child: Center(
                                child: Text(
                                  s.name.isNotEmpty ? s.name : 'Season ${s.seasonNumber}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    const Text('Episodes', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    
                    // Episodes Vertical List / Grid
                    (() {
                      final currentSeason = _detail!.seasons.firstWhere(
                        (s) => s.seasonNumber == _selectedSeasonNumber,
                        orElse: () => _detail!.seasons.first,
                      );
                      
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: currentSeason.episodeCount,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final epNum = idx + 1;
                          final isSelected = epNum == _selectedEpisodeNumber;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedEpisodeNumber = epNum;
                              });
                              _startTvDirect2EmbedFlow(currentSeason.seasonNumber, epNum);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.card.withOpacity(0.8) : AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isSelected ? AppColors.accent : AppColors.surface,
                                    radius: 14,
                                    child: Text(
                                      '$epNum',
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : AppColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Episode $epNum',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: isSelected ? AppColors.accent : AppColors.textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    })(),
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

                  // ── Help & Guide ────────────────────────
                  _buildUserGuideSection(),
                  const SizedBox(height: 12),

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
      if (m.isTvShow) {
        if (mounted) Navigator.pop(context);
        _startTvDirect2EmbedFlow(_selectedSeasonNumber, _selectedEpisodeNumber);
        return;
      }
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

  Future<void> _startTvDirect2EmbedFlow(int season, int episode) async {
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
                  'Loading 2Embed Direct TV Player...',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final streamUrl = await TwoEmbedService.instance.resolveTvStreamUrl(imdb, m.id.toString(), season, episode);
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
              content: Text('2Embed TV stream unavailable. Trying alternative servers...'),
              backgroundColor: Colors.amber,
            ),
          );
          _startTvAlternativeServersFlow(season, episode);
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) _startTvAlternativeServersFlow(season, episode);
    }
  }

  Future<void> _startTvAlternativeServersFlow(int season, int episode) async {
    await _startPlayFlow(isDownloadFlow: false, isTv: true, season: season, episode: episode);
  }

  Future<void> _startAlternativeServersFlow() async {
    final m = _detail ?? widget.movie;
    if (m.isTvShow) {
      await _startPlayFlow(isDownloadFlow: false, isTv: true, season: _selectedSeasonNumber, episode: _selectedEpisodeNumber);
    } else {
      await _startPlayFlow(isDownloadFlow: false);
    }
  }

  Future<void> _startPlayFlow({bool isDownloadFlow = false, bool isTv = false, int season = 1, int episode = 1}) async {
    final m = _detail ?? widget.movie;
    final title = m.title;
    final yearVal = int.tryParse(m.year);
    final imdb = _detail?.imdbId ?? '';

    debugPrint('[MovieDetail] Starting play flow (isDownload=$isDownloadFlow, isTv=$isTv, S=$season, E=$episode) for: $title (IMDB: $imdb)');

    List<TorrentStream> torrents = [];
    List<MovieBoxStream> movieBoxStreams = [];
    List<ArchiveStream> archives = [];
    List<MovieBoxStream> twoEmbedStreams = [];

    final bool hasValidCache = _cachedTorrents != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < const Duration(minutes: 10) &&
        !isTv;

    if (hasValidCache) {
      torrents = _cachedTorrents!;
      movieBoxStreams = _cachedMovieBoxStreams!;
      archives = _cachedArchives!;
      twoEmbedStreams = _cachedTwoEmbedStreams!;
      debugPrint('[MovieDetail] Using cached streams (age: ${DateTime.now().difference(_cacheTime!)}).');
    } else {
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

      try {
        // Run all stream resolution concurrently
        final results = await Future.wait([
          imdb.startsWith('tt')
              ? TorrentioService.getStreams(imdb, isTv: isTv, season: season, episode: episode)
              : Future.value(<TorrentStream>[]),
          !isTv
              ? MovieBoxService.resolveStreams(
                  title,
                  tmdbId: m.id,
                  imdbId: imdb.isNotEmpty ? imdb : null,
                )
              : Future.value(<MovieBoxStream>[]),
          !isTv
              ? ArchiveService.resolveStreams(title, year: yearVal, imdbId: imdb.isNotEmpty ? imdb : null)
              : Future.value(<ArchiveStream>[]),
          isTv
              ? TwoEmbedService.instance.resolveTvStreamUrl(imdb, m.id.toString(), season, episode)
              : TwoEmbedService.instance.resolveStreamUrl(imdb, m.id.toString()),
        ]);
        torrents = results[0] as List<TorrentStream>;
        movieBoxStreams = results[1] as List<MovieBoxStream>;
        archives = results[2] as List<ArchiveStream>;
        final twoEmbedStream = results[3] as String?;

        if (twoEmbedStream != null && twoEmbedStream.isNotEmpty) {
          final configs = twoEmbedStream.split('||');
          for (final cfg in configs) {
            if (cfg.trim().isEmpty) continue;
            final parts = cfg.split('|');
            final url = parts[0].trim();
            if (url.isNotEmpty) {
              String lang = 'Multi/English';
              int resVal = 720;
              String parsedReferer = 'https://lookmovie2.skin/';
              for (int i = 1; i < parts.length; i++) {
                final p = parts[i].trim();
                if (p.startsWith('language=')) {
                  lang = p.substring(9);
                  if (lang.contains('(1080p)')) {
                    resVal = 1080;
                  } else if (lang.contains('(720p)')) {
                    resVal = 720;
                  } else if (lang.contains('(480p)')) {
                    resVal = 480;
                  } else if (lang.contains('(360p)')) {
                    resVal = 360;
                  }
                } else if (p.startsWith('referer=')) {
                  parsedReferer = p.substring(8);
                }
              }

              final Map<String, String> languageNames = {
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
              final String origLangCode = m.language.toLowerCase();
              final String actualOrigLang = languageNames[origLangCode] ?? m.language;

              final bool isMb = url.contains('hakunaymatata.com') || url.contains('aoneroom.com');
              
              // Correct incorrect provider labeling (e.g. labeling Tamil as English)
              if (lang.startsWith('English') && origLangCode != 'en' && isMb) {
                lang = lang.replaceFirst('English', actualOrigLang);
              }
              // Strip duplicate resolution suffixes like (360p) from language label
              lang = lang.replaceAll(RegExp(r'\s*\(\d+p?\)'), '').trim();

              if (isMb) {
                movieBoxStreams.add(MovieBoxStream(
                  url: url,
                  resolution: resVal,
                  size: 'Direct Stream',
                  language: lang,
                  referer: 'https://h5.aoneroom.com/',
                  subjectId: '2embed', // Marks it for proper proxy headers
                  detailPath: '',
                ));
              } else {
                twoEmbedStreams.add(MovieBoxStream(
                  url: url,
                  resolution: resVal,
                  size: 'Fast Stream',
                  language: lang,
                  referer: parsedReferer,
                  subjectId: '2embed',
                  detailPath: '',
                ));
              }
            }
          }
        }

        if (!isTv) {
          // Cache the parsed streams
          _cachedTorrents = torrents;
          _cachedMovieBoxStreams = movieBoxStreams;
          _cachedArchives = archives;
          _cachedTwoEmbedStreams = twoEmbedStreams;
          _cacheTime = DateTime.now();
        }
      } catch (e) {
        debugPrint('[MovieDetailScreen] Stream resolution error: $e');
      } finally {
        if (mounted) Navigator.pop(context); // Dismiss loading dialog
      }
    }

    if (!mounted) return;

    debugPrint('[MovieDetail] Found: ${twoEmbedStreams.length} 2Embed, ${movieBoxStreams.length} MovieBox, ${archives.length} Archive, ${torrents.length} Torrent streams');

    if (torrents.isEmpty && archives.isEmpty && movieBoxStreams.isEmpty && twoEmbedStreams.isEmpty) {
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
                    if (twoEmbedStreams.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Direct Web Streaming (2Embed)',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            if (kIsWeb && isDownloadFlow)
                              const Text(
                                '⚠️ These links are for streaming only — not recommended for download',
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ...twoEmbedStreams.map((s) {
                        final langSuffix = s.language.isNotEmpty ? ' [${s.language}]' : '';
                        return ListTile(
                          leading: const Icon(Icons.play_circle_filled, color: AppColors.accent),
                          title: Text(
                            '2Embed ${s.resolution}p$langSuffix',
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Direct HLS/CDN Stream',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          onTap: () {
                            if (isDownloadFlow) {
                              Navigator.pop(context);
                            }
                            final url = s.url;
                            debugPrint('[MovieDetail] Selected stream: 2Embed ${s.resolution}p');
                            debugPrint('[MovieDetail] URL: $url');
                            if (url.trim().isEmpty) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Stream unavailable'), backgroundColor: Colors.redAccent),
                              );
                              return;
                            }
                            if (isDownloadFlow) {
                              if (kIsWeb) {
                                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                return;
                              }
                              DownloadService.instance.addDownload(
                                m.title,
                                '2h 00m',
                                '${s.resolution}p',
                                m.posterUrl,
                                downloadUrl: url,
                                movieBoxSubjectId: s.subjectId,
                                movieBoxDetailPath: s.detailPath,
                              );
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('"${m.title}" added to downloads queue!'),
                                  backgroundColor: AppColors.surface,
                                  action: SnackBarAction(
                                    label: 'View',
                                    textColor: AppColors.accent,
                                    onPressed: () {
                                      Navigator.push(
                                        this.context,
                                        MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                                      );
                                    },
                                  ),
                                ),
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
                                  referer: s.referer,
                                  resolution: s.resolution,
                                  subjectId: s.subjectId,
                                  detailPath: s.detailPath,
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ],
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
                            if (isDownloadFlow) {
                              Navigator.pop(context);
                            }
                            final url = s.url;
                            debugPrint('[MovieDetail] Selected stream: MovieBox ${s.resolution}p');
                            debugPrint('[MovieDetail] URL: $url');
                            if (url.trim().isEmpty) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Stream unavailable'), backgroundColor: Colors.redAccent),
                              );
                              return;
                            }
                            if (isDownloadFlow) {
                              if (kIsWeb) {
                                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                return;
                              }
                              DownloadService.instance.addDownload(
                                m.title,
                                '2h 00m',
                                '${s.resolution}p',
                                m.posterUrl,
                                downloadUrl: url,
                                movieBoxSubjectId: s.subjectId,
                                movieBoxDetailPath: s.detailPath,
                              );
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('"${m.title}" added to downloads queue!'),
                                  backgroundColor: AppColors.surface,
                                  action: SnackBarAction(
                                    label: 'View',
                                    textColor: AppColors.accent,
                                    onPressed: () {
                                      Navigator.push(
                                        this.context,
                                        MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                                      );
                                    },
                                  ),
                                ),
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
                                  referer: s.referer,
                                  resolution: s.resolution,
                                  subjectId: s.subjectId,
                                  detailPath: s.detailPath,
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
                            if (isDownloadFlow) {
                              Navigator.pop(context);
                            }
                            final url = a.url;
                            debugPrint('[MovieDetail] Selected stream: ${a.label}');
                            debugPrint('[MovieDetail] URL: $url');
                            if (url.trim().isEmpty) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Stream unavailable'), backgroundColor: Colors.redAccent),
                              );
                              return;
                            }
                            if (isDownloadFlow) {
                              if (kIsWeb) {
                                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                return;
                              }
                              DownloadService.instance.addDownload(
                                m.title,
                                '2h 00m',
                                'Archive Stream',
                                m.posterUrl,
                                downloadUrl: url,
                              );
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('"${m.title}" added to downloads queue!'),
                                  backgroundColor: AppColors.surface,
                                  action: SnackBarAction(
                                    label: 'View',
                                    textColor: AppColors.accent,
                                    onPressed: () {
                                      Navigator.push(
                                        this.context,
                                        MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                                      );
                                    },
                                  ),
                                ),
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
                          trailing: const Icon(Icons.copy_rounded, color: AppColors.accent, size: 18),
                          onTap: () {
                            final bool isMobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
                            if (isDownloadFlow || isMobile) {
                              Navigator.pop(context);
                            }
                            if (isMobile) {
                              Clipboard.setData(ClipboardData(text: t.magnetUri));
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Magnet link copied! Paste it in external torrent apps (like uTorrent, Flud, 1DM, LibreTorrent) to stream or download.'),
                                  duration: Duration(seconds: 5),
                                  backgroundColor: AppColors.surface,
                                ),
                              );
                              return;
                            }
                            if (isDownloadFlow) {
                              if (kIsWeb) {
                                launchUrl(Uri.parse(t.magnetUri), mode: LaunchMode.externalApplication);
                                return;
                              }
                              if (t.magnetUri.isEmpty) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(content: Text('Magnet link unavailable for download.'), backgroundColor: Colors.redAccent),
                                );
                                return;
                              }
                              DownloadService.instance.addDownload(
                                m.title,
                                '2h 00m',
                                t.quality,
                                m.posterUrl,
                                magnetUri: t.magnetUri,
                              );
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('"${m.title}" (${t.quality}) added to downloads queue!'),
                                  backgroundColor: AppColors.surface,
                                  action: SnackBarAction(
                                    label: 'View',
                                    textColor: AppColors.accent,
                                    onPressed: () {
                                      Navigator.push(
                                        this.context,
                                        MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                                      );
                                    },
                                  ),
                                ),
                              );
                              return;
                            }
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
    final m = _detail ?? widget.movie;
    if (m.isTvShow) {
      _startPlayFlow(isDownloadFlow: true, isTv: true, season: _selectedSeasonNumber, episode: _selectedEpisodeNumber);
    } else {
      _startPlayFlow(isDownloadFlow: true);
    }
  }

  Widget _buildUserGuideSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Help & Guide',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ExpansionTile(
              leading: const Icon(Icons.play_circle_fill, color: AppColors.accent, size: 20),
              title: const Text('How to Play', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Simply click the large orange Play button on the cover poster, or scroll down to the "Streaming Links" section below and tap any available link to start playing.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.link, color: AppColors.accent, size: 20),
              title: const Text('Other Links (Alternative Servers)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Click the "Other Links" button on this page to scan and fetch all alternative streaming servers available for this title. You can view file sizes, resolutions, and select your preferred source to play or download.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.settings, color: AppColors.accent, size: 20),
              title: const Text('How to Choose (Audio / Quality)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'While the video is playing, tap the screen to reveal the controls. Click the gear icon ⚙️ in the top right corner to change the audio track (language), adjust the video resolution, or switch servers from the alternative link list (server icon 🗄️).',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.download_for_offline, color: AppColors.accent, size: 20),
              title: const Text('How to Download', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Click the download icon 📥 in the top right corner of the player to launch the download manager and save the media directly to your device for offline viewing.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _watchlistButton(Movie m) {
    return ValueListenableBuilder<List<Movie>>(
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
    );
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
