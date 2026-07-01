import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../utils/seo_helper.dart'
    if (dart.library.js) '../utils/seo_helper_web.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/live_tv_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/watchlist_screen.dart';
import '../screens/history_screen.dart';
import '../screens/blog_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/flixo_download_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/login_screen.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/download_manager.dart';
import '../utils/globals.dart';
import '../services/two_embed_service.dart';
import '../screens/player_screen.dart';
import '../models/movie.dart';

import '../widgets/web_download_popup.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _idx = 0;
  bool _isCollapsed = false;
  bool _isDeepLinkLoading = false;

  final _mobileScreens = const [
    HomeScreen(),
    DiscoverScreen(),
    LiveTvScreen(),
    DownloadsScreen(),
    ProfileScreen(),
  ];

  final _desktopScreens = const [
    HomeScreen(),
    DiscoverScreen(),
    LiveTvScreen(),
    DownloadsScreen(),
    WatchlistScreen(),
    HistoryScreen(),
    BlogScreen(),
    ProfileScreen(),
    SettingsScreen(),
    FlixoDownloadScreen(),
  ];

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

  int _pathToIndex(String path) {
    final p = path.toLowerCase().replaceAll(RegExp(r'^/#'), '').replaceAll(RegExp(r'^/'), '').trim();
    if (p == 'home' || p.isEmpty) return 0;
    if (p == 'discover') return 1;
    if (p == 'live-tv' || p == 'livetv') return 2;
    if (p == 'downloads') return 3;
    if (p == 'watchlist') return 4;
    if (p == 'history') return 5;
    if (p == 'blog') return 6;
    if (p == 'profile') return 7;
    if (p == 'settings') return 8;
    if (p == 'download-app' || p == 'download_app') return 9;
    return 0;
  }

  int _parseInitialIndex() {
    try {
      final fragment = Uri.base.fragment;
      if (fragment.isNotEmpty) {
        return _pathToIndex(fragment);
      }
      final path = Uri.base.path;
      return _pathToIndex(path);
    } catch (_) {
      return 0;
    }
  }

  void _updateBrowserUrl(int index) {
    try {
      final path = _indexToPath(index);
      SystemNavigator.routeInformationUpdated(
        location: path,
      );
    } catch (e) {
      debugPrint('Error updating browser URL: $e');
    }
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0: return 'MovieNest - Home & Streaming Catalog';
      case 1: return 'Discover Movies & Shows | MovieNest';
      case 2: return 'Watch Live TV Channels Free | MovieNest';
      case 3: return 'Downloads & Offline Sync | MovieNest';
      case 4: return 'My Watchlist | MovieNest';
      case 5: return 'Streaming History | MovieNest';
      case 6: return 'MovieNest Blog & Movie News';
      case 7: return 'User Profile | MovieNest';
      case 8: return 'Account Settings | MovieNest';
      case 9: return 'Download MovieNest Native Apps';
      default: return 'MovieNest - Stream Movies & Live TV';
    }
  }

  String _getTabDesc(int index) {
    switch (index) {
      case 0: return 'Watch and stream the latest popular movies, TV series, anime, and live TV channels completely free.';
      case 1: return 'Explore and discover new release movie catalogs, categories, filters, and similar title recommendations.';
      case 2: return 'Watch active live TV channels, streaming events, and live broadcast lists in real-time.';
      default: return 'MovieNest is a premium streaming catalog viewer and application powered by the TMDB database.';
    }
  }

  void _updateWebTabSeo(int index) {
    if (!kIsWeb) return;
    try {
      final path = _indexToPath(index);
      final canonicalUrl = 'https://www.movienest.app$path';
      final title = _getTabTitle(index);
      final desc = _getTabDesc(index);

      final globalSchema = {
        "@context": "https://schema.org",
        "@graph": [
          {
            "@type": "Organization",
            "@id": "https://www.movienest.app/#organization",
            "name": "MovieNest",
            "url": "https://www.movienest.app",
            "logo": "https://www.movienest.app/icons/Icon-512.png"
          },
          {
            "@type": "WebSite",
            "@id": "https://www.movienest.app/#website",
            "url": "https://www.movienest.app",
            "name": "MovieNest",
            "potentialAction": {
              "@type": "SearchAction",
              "target": "https://www.movienest.app/search?q={search_term_string}",
              "query-input": "required name=search_term_string"
            }
          }
        ]
      };

      updateWebSeo(
        title,
        desc,
        canonicalUrl,
        'https://www.movienest.app/icons/Icon-512.png',
        jsonEncode(globalSchema),
      );
    } catch (_) {}
  }

  Future<void> _checkAppUpdates() async {
    try {
      final res = await http.get(Uri.parse('https://www.movienest.app/version.json')).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final serverData = json.decode(res.body);

      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;

      if (localVersion != serverData['latest_version']) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: !(serverData['force_update'] as bool? ?? false),
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Update Available', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(
              'A new version (${serverData['latest_version']}) of MovieNest is available. Would you like to update now?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              if (!(serverData['force_update'] as bool? ?? false))
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later', style: TextStyle(color: Colors.white54)),
                ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  try {
                    launchUrl(Uri.parse(serverData['download_url'] as String? ?? 'https://www.movienest.app'), mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Update Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  void _handleInitialUrlRoute() {
    try {
      final uri = Uri.base;
      String path = uri.path;

      final fragment = uri.fragment;
      if (fragment.isNotEmpty) {
        final fragmentUri = Uri.parse(fragment);
        if (fragmentUri.path.contains('/movie/')) {
          path = fragmentUri.path;
        }
      }

      if (path.contains('/movie/')) {
        final segments = path.split('/movie/');
        if (segments.length > 1) {
          final slug = segments[1].trim();
          if (slug.isNotEmpty) {
            final query = slug.replaceAll('-', ' ');
            _searchAndPushMovie(query);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _searchAndPushMovie(String query) async {
    try {
      final results = await TmdbService.searchMovies(query);
      if (results.isNotEmpty && mounted) {
        final movie = results.first;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
        );
      }
    } catch (e) {
      debugPrint('Error searching and pushing movie: $e');
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _isDeepLinkLoading = false;
            });
          }
        });
      }
    }
  }

  int getSafeIndex(bool isDesktop) {
    if (isDesktop) {
      if (_idx >= 10) return 0;
      return _idx;
    } else {
      if (_idx == 7 || _idx == 9) return 4; // Map Profile and Download App to mobile profile index
      if (_idx >= 5) return 0; // Map non-existent desktop indices back to Home
      return _idx;
    }
  }

  Future<void> _checkAndShowWebDownloadPopup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month}-${now.day}";
      final lastShowDate = prefs.getString('last_popup_show_date') ?? '';
      int showCount = prefs.getInt('popup_show_count') ?? 0;

      if (lastShowDate != todayStr) {
        showCount = 0;
      }

      if (showCount < 2) {
        showCount++;
        await prefs.setString('last_popup_show_date', todayStr);
        await prefs.setInt('popup_show_count', showCount);
        _showWebDownloadPopup();
      }
    } catch (e) {
      debugPrint('Error checking web download popup limit: $e');
      _showWebDownloadPopup();
    }
  }

  void _showWebDownloadPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: WebDownloadPopup(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _idx = mainNavTabNotifier.value;
    mainNavTabNotifier.addListener(_onTabChanged);

    if (kIsWeb) {
      // Capture the original browser URL synchronously on creation before Flutter router resets it to root (/)
      final String initPath = Uri.base.path;
      final String initFragment = Uri.base.fragment;

      if (initPath.contains('/movie/') || initFragment.contains('/movie/')) {
        _isDeepLinkLoading = true;
      }

      int initialIdx = 0;
      try {
        if (initFragment.isNotEmpty) {
          initialIdx = _pathToIndex(initFragment);
        } else {
          initialIdx = _pathToIndex(initPath);
        }
      } catch (_) {}

      _idx = initialIdx;
      mainNavTabNotifier.value = initialIdx;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        final bool isMovieLink = initPath.contains('/movie/') || initFragment.contains('/movie/');
        if (!isMovieLink) {
          _updateBrowserUrl(initialIdx);
        }
        _updateWebTabSeo(initialIdx);
        
        // Execute deep-linking for direct movie links
        try {
          String targetPath = initPath;
          if (initFragment.isNotEmpty) {
            final fragmentUri = Uri.parse(initFragment);
            if (fragmentUri.path.contains('/movie/')) {
              targetPath = fragmentUri.path;
            }
          }
          if (targetPath.contains('/movie/')) {
            final segments = targetPath.split('/movie/');
            if (segments.length > 1) {
              String slug = segments[1].trim();
              // Strip query parameters
              if (slug.contains('?')) {
                slug = slug.split('?')[0];
              }
              // Strip fragment hashes
              if (slug.contains('#')) {
                slug = slug.split('#')[0];
              }
              // Strip trailing slash
              if (slug.endsWith('/')) {
                slug = slug.substring(0, slug.length - 1);
              }
              slug = slug.trim();
              if (slug.isNotEmpty) {
                final query = slug.replaceAll('-', ' ');
                _searchAndPushMovie(query);
              }
            }
          }
        } catch (_) {}

        if (!isMovieLink) {
          _checkAndShowWebDownloadPopup();
        }
      });
    }
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAppUpdates();
      });
    }
  }

  @override
  void dispose() {
    mainNavTabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {
        _idx = mainNavTabNotifier.value;
      });
      if (kIsWeb) {
        _updateBrowserUrl(_idx);
        _updateWebTabSeo(_idx);
      }
    }
  }

  Widget _buildSidebarItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _idx == index;
    return InkWell(
      onTap: () async {
        if (index == 99) {
          final mockMovie = Movie(
            id: 1057265,
            title: 'Dhurandhar',
            posterPath: '',
            backdropPath: '',
            rating: 8.5,
            overview: 'Test movie details description',
            releaseDate: '2023',
            language: 'en',
          );
          
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              backgroundColor: AppColors.card,
              content: Row(
                children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(width: 20),
                  Text('Resolving Test stream...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          );
          
          String? resolvedUrl;
          try {
            resolvedUrl = await TwoEmbedService.instance
                .resolveStreamUrl('tt23865918', '1057265')
                .timeout(const Duration(seconds: 35));
          } catch (e) {
            print('[MainNavTest] Error resolving test stream: $e');
          }
          
          if (context.mounted) {
            Navigator.pop(context); // Dismiss dialog
            if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(
                    movie: mockMovie,
                    directUrl: resolvedUrl,
                    imdbId: 'tt23865918',
                    year: 2023,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to resolve test stream.')),
              );
            }
          }
          return;
        }
        mainNavTabNotifier.value = index;
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        margin: EdgeInsets.symmetric(
          horizontal: _isCollapsed ? 8 : 16,
          vertical: 3,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: _isCollapsed ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (isSelected)
              Container(
                width: 3,
                height: 18,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              )
            else if (!_isCollapsed)
              const SizedBox(width: 15), // Placeholder for left spacing
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: 20,
            ),
            if (!_isCollapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? AppColors.accent : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWebSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _isCollapsed ? 74 : 270,
      color: AppColors.navBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                    _buildSidebarItem(0, Icons.home_outlined, Icons.home, 'Home'),
                    _buildSidebarItem(1, Icons.explore_outlined, Icons.explore, 'Discover'),
                    _buildSidebarItem(2, Icons.live_tv_outlined, Icons.live_tv, 'Live TV'),
                    _buildSidebarItem(3, Icons.download_outlined, Icons.download, 'Downloads'),
                    _buildSidebarItem(4, Icons.bookmark_outline_rounded, Icons.bookmark_rounded, 'Watchlist'),
                    _buildSidebarItem(5, Icons.history_rounded, Icons.history_rounded, 'History'),
                    _buildSidebarItem(6, Icons.article_outlined, Icons.article, 'Blog'),
                    _buildSidebarItem(7, Icons.person_outline, Icons.person, 'Profile'),
                    _buildSidebarItem(8, Icons.settings_outlined, Icons.settings, 'Settings'),
                    _buildSidebarItem(9, Icons.install_mobile_rounded, Icons.install_mobile_rounded, 'Download App'),
                    if (kIsWeb)
                      _buildSidebarItem(99, Icons.bug_report, Icons.bug_report, 'Test 2Embed'),
                    if (!_isCollapsed) ...[
                      const Spacer(),
                      // Go Premium Promo Card
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.workspace_premium, color: AppColors.accent, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Go Premium',
                                  style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Unlimited access to all movies, shows & more.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 25,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () {
                                  mainNavTabNotifier.value = 7;
                                },
                                child: const Text(
                                  'Upgrade Now >',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Social Media Row
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.photo_camera_outlined, size: 16, color: AppColors.textSecondary),
                            Icon(Icons.alternate_email, size: 16, color: AppColors.textSecondary),
                            Icon(Icons.play_circle_outline, size: 16, color: AppColors.textSecondary),
                            Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ] else
                      const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          _isCollapsed ? 'v1.0' : 'MovieNest Web v1.0.0\n© 2026 MovieNest Inc.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeepLinkLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width > 768;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Full Width Top Header Bar!
            _buildWebTopHeader(context),
            Container(height: 0.5, color: AppColors.border),
            // Split Area: Sidebar + Scrollable Page
            Expanded(
              child: Row(
                children: [
                  _buildWebSidebar(),
                  Container(width: 0.5, color: AppColors.border),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1300),
                        child: IndexedStack(
                          index: getSafeIndex(true),
                          children: _desktopScreens,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: getSafeIndex(false),
            children: _mobileScreens,
          ),
          const DownloadManager(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1F1F1F), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: getSafeIndex(false),
          onTap: (i) => mainNavTabNotifier.value = i,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined),       activeIcon: Icon(Icons.home),        label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.explore_outlined),    activeIcon: Icon(Icons.explore),     label: 'Discover'),
            BottomNavigationBarItem(icon: Icon(Icons.live_tv_outlined),    activeIcon: Icon(Icons.live_tv),     label: 'Live TV'),
            BottomNavigationBarItem(icon: Icon(Icons.download_outlined),   activeIcon: Icon(Icons.download),    label: 'Downloads'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline),      activeIcon: Icon(Icons.person),      label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildWebTopHeader(BuildContext context) {
    final categories = ['Home', 'Movies', 'Shows', 'Anime', 'Shorts'];
    final sidebarWidth = _isCollapsed ? 74.0 : 270.0;
    return Container(
      height: 64,
      color: AppColors.background,
      child: Row(
        children: [
          // Left side matching sidebar width exactly
          Container(
            width: sidebarWidth,
            height: 64,
            child: _isCollapsed
                ? Center(
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                      onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                          onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Image.asset(
                            'assets/header_logo.png',
                            height: 38,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            errorBuilder: (_, __, ___) => const Text(
                              'MOVIENEST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          // Vertical divider line in the header aligning with sidebar border
          Container(width: 0.5, color: AppColors.border),

          // Categories Pills / Screen Title area padded cleanly
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  if (_idx == 0)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ValueListenableBuilder<int>(
                          valueListenable: homeCategoryNotifier,
                          builder: (context, activeCategory, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(categories.length, (i) {
                                final selected = i == activeCategory;
                                final icons = [Icons.home, Icons.movie_outlined, Icons.tv, Icons.animation, Icons.video_library_outlined];
                                return GestureDetector(
                                  onTap: () {
                                    homeCategoryNotifier.value = i;
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: selected ? AppColors.accent : const Color(0xFF161616),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icons[i], size: 14, color: selected ? Colors.black : AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          categories[i],
                                          style: TextStyle(
                                            color: selected ? Colors.black : AppColors.textSecondary,
                                            fontSize: 13,
                                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      _idx == 1 
                          ? 'DISCOVER' 
                          : (_idx == 2 
                              ? 'LIVE TV' 
                              : (_idx == 3 
                                  ? 'DOWNLOADS' 
                                  : (_idx == 4 
                                      ? 'WATCHLIST' 
                                      : (_idx == 5 
                                          ? 'WATCH HISTORY' 
                                          : (_idx == 6 
                                              ? 'EDITORIAL BLOG' 
                                              : (_idx == 7 
                                                  ? 'MY PROFILE' 
                                                  : (_idx == 8 
                                                      ? 'SETTINGS' 
                                                      : 'DOWNLOAD APP'))))))),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                  ],
                  // Compact Search Bar on the Right
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                    child: Container(
                      width: 300,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: AppColors.textSecondary, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Search movies, shows...',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                          Icon(Icons.tune, color: AppColors.textSecondary, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Premium Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, color: AppColors.accent, size: 13),
                        SizedBox(width: 4),
                        Text('Premium', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Notification icon
                  Stack(
                    children: [
                      const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 22),
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // User Avatar / Login Button
                  _buildUserAvatarOrLoginButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatarOrLoginButton(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          final photoUrl = user.photoURL;
          return GestureDetector(
            onTap: () {
              mainNavTabNotifier.value = 7; // Go to profile screen
            },
            child: CircleAvatar(
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : const NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=80') as ImageProvider,
              radius: 16,
            ),
          );
        } else {
          return TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen(isModalMode: true)),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Login', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          );
        }
      },
    );
  }
}
