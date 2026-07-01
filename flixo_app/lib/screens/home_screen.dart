import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../services/home_cache_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/movie_row_section.dart';
import '../services/history_service.dart';
import '../utils/globals.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategory = 0;
  final _categories = ['Home', 'Movies', 'Shows', 'Anime', 'Shorts'];

  String _selectedGenre    = 'All Genres';
  String _selectedLanguage = 'All Languages';
  String _selectedYear     = 'Release Year';
  String _selectedSort     = 'Sort By';
  

  List<Movie> _trending   = [];
  List<Movie> _newRelease = [];
  List<Movie> _topRated   = [];
  List<Movie> _popular    = [];
  List<Movie> _hindi      = [];
  List<Movie> _telugu     = [];
  List<Movie> _tamil      = [];
  List<Movie> _kannada    = [];
  List<Movie> _anime      = [];
  List<Movie> _horror     = [];
  List<Movie> _comedy     = [];
  List<Movie> _sciFi      = [];
  List<Movie> _romance    = [];
  List<Movie> _tvShows    = [];

  List<Movie> _filteredPool = [];
  bool _loadingFirst = true;
  bool _loadingRest  = false;
  bool _loadingTv    = false;
  bool _loadingFiltered = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    homeCategoryNotifier.addListener(_onCategoryNotifierChanged);
    mainNavTabNotifier.addListener(_onMainNavTabChanged);
    if (kIsWeb) {
      SystemChrome.setApplicationSwitcherDescription(
        const ApplicationSwitcherDescription(label: 'MovieNest - Home & Streaming Catalog'),
      );
    }
  }

  @override
  void dispose() {
    homeCategoryNotifier.removeListener(_onCategoryNotifierChanged);
    mainNavTabNotifier.removeListener(_onMainNavTabChanged);
    super.dispose();
  }

  void _onCategoryNotifierChanged() {
    if (mounted) {
      setState(() {
        _selectedCategory = homeCategoryNotifier.value;
        _selectedGenre    = 'All Genres';
        _selectedLanguage = 'All Languages';
        _selectedYear     = 'Release Year';
        _selectedSort     = 'Sort By';
      });
      if (homeCategoryNotifier.value == 2) {
        _loadTvShows();
      }
    }
  }

  void _onMainNavTabChanged() {
    if (mainNavTabNotifier.value == 0 && _trending.isEmpty && !_loadingFirst) {
      setState(() => _loadingFirst = true);
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    // If the initial URL is a deep link, do not fetch any home screen data at all.
    // This allows the deep-link movie search to complete instantly without any network queue blocking.
    if (kIsWeb) {
      final uri = Uri.base;
      final hasDeepLink = uri.path.contains('/movie/') || uri.fragment.contains('/movie/');
      if (hasDeepLink) {
        setState(() => _loadingFirst = false);
        return;
      }
    }

    final cached = await HomeCacheService.load();
    if (cached != null && mounted) {
      setState(() {
        _trending   = cached['trending']   ?? [];
        _newRelease = cached['newRelease'] ?? [];
        _topRated   = cached['topRated']   ?? [];
        _popular    = cached['popular']    ?? [];
        _hindi      = cached['hindi']      ?? [];
        _telugu     = cached['telugu']     ?? [];
        _tamil      = cached['tamil']      ?? [];
        _kannada    = cached['kannada']    ?? [];
        _anime      = cached['anime']      ?? [];
        _horror     = cached['horror']     ?? [];
        _comedy     = cached['comedy']     ?? [];
        _sciFi      = cached['sciFi']      ?? [];
        _romance    = cached['romance']    ?? [];
        _loadingFirst = false;
      });
      _refreshInBackground();
    } else {
      await _loadFirst5();
      _loadRemaining9();
    }
  }

  Future<void> _loadFirst5() async {
    try {
      final results = await Future.wait([
        TmdbService.getTrending(),
        TmdbService.getNowPlaying(),
        TmdbService.getTopRated(),
        TmdbService.getPopular(),
        TmdbService.getByLanguage('hi'),
      ]);
      if (mounted) {
        setState(() {
          _trending   = results[0];
          _newRelease = results[1];
          _topRated   = results[2];
          _popular    = results[3];
          _hindi      = results[4];
          _loadingFirst = false;
          _loadingRest  = true;
        });
      }
    } catch (e) {
      debugPrint('Home first5 error: $e');
      if (mounted) setState(() => _loadingFirst = false);
    }
  }

  Future<void> _loadRemaining9() async {
    try {
      // Delay slightly before loading the next batch to prevent network congestion
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      final results = await Future.wait([
        TmdbService.getTelugu(),
        TmdbService.getTamil(),
        TmdbService.getKannada(),
        TmdbService.getAnime(),
        TmdbService.getHorror(),
        TmdbService.getComedy(),
        TmdbService.getSciFi(),
        TmdbService.getRomance(),
      ]);
      if (mounted) {
        setState(() {
          _telugu  = results[0];
          _tamil   = results[1];
          _kannada = results[2];
          _anime   = results[3];
          _horror  = results[4];
          _comedy  = results[5];
          _sciFi   = results[6];
          _romance = results[7];
          _loadingRest = false;
        });
        _saveCache();
      }
    } catch (e) {
      debugPrint('Home rest error: $e');
      if (mounted) setState(() => _loadingRest = false);
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      // Refresh primary rows first
      final r1 = await Future.wait([
        TmdbService.getTrending(),
        TmdbService.getNowPlaying(),
        TmdbService.getTopRated(),
        TmdbService.getPopular(),
        TmdbService.getByLanguage('hi'),
      ]);
      if (!mounted) return;
      setState(() {
        _trending   = r1[0];
        _newRelease = r1[1];
        _topRated   = r1[2];
        _popular    = r1[3];
        _hindi      = r1[4];
      });

      // Delay loading secondary rows to keep proxy connections free
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      final r2 = await Future.wait([
        TmdbService.getTelugu(),
        TmdbService.getTamil(),
        TmdbService.getKannada(),
        TmdbService.getAnime(),
        TmdbService.getHorror(),
        TmdbService.getComedy(),
        TmdbService.getSciFi(),
        TmdbService.getRomance(),
      ]);
      if (!mounted) return;
      setState(() {
        _telugu  = r2[0];
        _tamil   = r2[1];
        _kannada = r2[2];
        _anime   = r2[3];
        _horror  = r2[4];
        _comedy  = r2[5];
        _sciFi   = r2[6];
        _romance = r2[7];
      });
      _saveCache();
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    await HomeCacheService.save({
      'trending':   _trending,
      'newRelease': _newRelease,
      'topRated':   _topRated,
      'popular':    _popular,
      'hindi':      _hindi,
      'telugu':     _telugu,
      'tamil':      _tamil,
      'kannada':    _kannada,
      'anime':      _anime,
      'horror':     _horror,
      'comedy':     _comedy,
      'sciFi':      _sciFi,
      'romance':    _romance,
    });
  }

  Future<void> _onRefresh() async {
    await HomeCacheService.clear();
    setState(() { _loadingFirst = true; _loadingRest = false; });
    await _loadFirst5();
    _loadRemaining9();
  }

  Future<void> _loadTvShows() async {
    if (_tvShows.isNotEmpty) return;
    setState(() => _loadingTv = true);
    try {
      final shows = await TmdbService.getTvShows();
      if (mounted) {
        setState(() {
          _tvShows = shows;
          _loadingTv = false;
        });
      }
    } catch (e) {
      debugPrint('Tv shows load error: $e');
      if (mounted) setState(() => _loadingTv = false);
    }
  }

  List<Movie> _f(List<Movie> src) {
    List<Movie> list = List.from(src);
    if (_selectedGenre != 'All Genres') {
      final id = _getGenreId(_selectedGenre);
      if (id != null) list = list.where((m) => m.genreIds.contains(id)).toList();
    }
    if (_selectedLanguage != 'All Languages') {
      final code = _getLanguageCode(_selectedLanguage);
      list = list.where((m) => m.language.toLowerCase() == code.toLowerCase()).toList();
    }
    if (_selectedYear != 'Release Year') {
      list = list.where((m) => m.year == _selectedYear).toList();
    }
    if (_selectedSort == 'Rating') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_selectedSort == 'Release Date') {
      list.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    }
    return list;
  }

  // Filter applying genre/year/sort but NOT language.
  // Used for generic rows (Trending, Horror etc.) so they always show content
  // even when a language filter is selected.
  List<Movie> _fNoLang(List<Movie> src) {
    List<Movie> list = List.from(src);
    if (_selectedGenre != 'All Genres') {
      final id = _getGenreId(_selectedGenre);
      if (id != null) list = list.where((m) => m.genreIds.contains(id)).toList();
    }
    if (_selectedYear != 'Release Year') {
      list = list.where((m) => m.year == _selectedYear).toList();
    }
    if (_selectedSort == 'Rating') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_selectedSort == 'Release Date') {
      list.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    }
    return list;
  }

  // Returns true if a language-specific row should be visible.
  // Language rows are always visible when 'All Languages' is selected,
  // or only when their own language is selected.
  bool _showLangRow(String langCode) {
    if (_selectedLanguage == 'All Languages') return true;
    return _getLanguageCode(_selectedLanguage) == langCode;
  }

  int? _getGenreId(String g) {
    switch (g.toLowerCase()) {
      case 'action':    return 28;
      case 'comedy':    return 35;
      case 'drama':     return 18;
      case 'horror':    return 27;
      case 'sci-fi':    return 878;
      case 'romance':   return 10749;
      case 'thriller':  return 53;
      case 'animation': return 16;
      default: return null;
    }
  }

  String _getLanguageCode(String lang) {
    switch (lang.toLowerCase()) {
      case 'hindi':    return 'hi';
      case 'tamil':    return 'ta';
      case 'telugu':   return 'te';
      case 'kannada':  return 'kn';
      case 'english':  return 'en';
      case 'spanish':  return 'es';
      case 'french':   return 'fr';
      case 'japanese': return 'ja';
      case 'korean':   return 'ko';
      default: return 'en';
    }
  }

  bool get _isFilterActive =>
      _selectedGenre != 'All Genres' ||
      _selectedLanguage != 'All Languages' ||
      _selectedYear != 'Release Year' ||
      _selectedSort != 'Sort By';

  void _resetFilters() {
    setState(() {
      _selectedGenre    = 'All Genres';
      _selectedLanguage = 'All Languages';
      _selectedYear     = 'Release Year';
      _selectedSort     = 'Sort By';
      _filteredPool     = [];
      _loadingFiltered  = false;
    });
  }

  String _getSortQuery(String sort) {
    switch (sort) {
      case 'Popularity': return 'popularity.desc';
      case 'Rating': return 'vote_average.desc';
      case 'Release Date': return 'primary_release_date.desc';
      default: return 'popularity.desc';
    }
  }

  Future<void> _applyFilters() async {
    if (!_isFilterActive) {
      setState(() {
        _filteredPool = [];
      });
      return;
    }

    setState(() {
      _loadingFiltered = true;
    });

    try {
      final langCode = _selectedLanguage != 'All Languages' ? _getLanguageCode(_selectedLanguage) : null;
      final genreId = _selectedGenre != 'All Genres' ? _getGenreId(_selectedGenre) : null;
      final year = _selectedYear != 'Release Year' ? _selectedYear : null;
      final sort = _selectedSort != 'Sort By' ? _getSortQuery(_selectedSort) : 'popularity.desc';

      final movies = await TmdbService.discoverMultiPage(
        lang: langCode,
        genreId: genreId,
        year: year,
        sortBy: sort,
      );

      if (mounted) {
        setState(() {
          _filteredPool = movies;
          _loadingFiltered = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading filtered pool: $e');
      if (mounted) {
        setState(() {
          _loadingFiltered = false;
        });
      }
    }
  }


  Widget _buildLoadingView() {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
    );
  }

  Widget _buildNoResultsView() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.movie_filter_outlined, color: AppColors.textMuted, size: 64),
              const SizedBox(height: 16),
              const Text(
                'No Content Found',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try adjusting or resetting your filters to find what you are looking for.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh, color: Colors.black, size: 18),
                label: const Text('Reset Filters', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryRows() {
    List<Widget> rows = [];

    if (_selectedCategory == 0 || _selectedCategory == 1) {
      final List<Movie> newReleases;
      final List<Movie> trendingMovies;
      final List<Movie> topRatedMovies;
      final List<Movie> popularMovies;
      final List<Movie> animeMovies;
      final List<Movie> horrorMovies;
      final List<Movie> comedyMovies;
      final List<Movie> sciFiMovies;
      final List<Movie> romanceMovies;

      final List<Movie> hindiMovies;
      final List<Movie> teluguMovies;
      final List<Movie> tamilMovies;
      final List<Movie> kannadaMovies;

      if (_isFilterActive) {
        trendingMovies = List.from(_filteredPool);
        newReleases    = List.from(_filteredPool)..sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
        topRatedMovies = List.from(_filteredPool)..sort((a, b) => b.rating.compareTo(a.rating));
        popularMovies  = List.from(_filteredPool)..sort((a, b) => b.rating.compareTo(a.rating));
        
        animeMovies   = _filteredPool.where((m) => m.genreIds.contains(16) || m.language == 'ja').toList();
        horrorMovies  = _filteredPool.where((m) => m.genreIds.contains(27)).toList();
        comedyMovies  = _filteredPool.where((m) => m.genreIds.contains(35)).toList();
        sciFiMovies   = _filteredPool.where((m) => m.genreIds.contains(878)).toList();
        romanceMovies = _filteredPool.where((m) => m.genreIds.contains(10749)).toList();

        hindiMovies   = _showLangRow('hi') ? _filteredPool.where((m) => m.language == 'hi').toList() : <Movie>[];
        teluguMovies  = _showLangRow('te') ? _filteredPool.where((m) => m.language == 'te').toList() : <Movie>[];
        tamilMovies   = _showLangRow('ta') ? _filteredPool.where((m) => m.language == 'ta').toList() : <Movie>[];
        kannadaMovies = _showLangRow('kn') ? _filteredPool.where((m) => m.language == 'kn').toList() : <Movie>[];
      } else {
        newReleases    = _f(_newRelease);
        trendingMovies = _f(_trending);
        topRatedMovies = _f(_topRated);
        popularMovies  = _f(_popular);
        animeMovies    = _f(_anime);
        horrorMovies   = _f(_horror);
        comedyMovies   = _f(_comedy);
        sciFiMovies    = _f(_sciFi);
        romanceMovies  = _f(_romance);

        hindiMovies   = _showLangRow('hi') ? _fNoLang(_hindi)   : <Movie>[];
        teluguMovies  = _showLangRow('te') ? _fNoLang(_telugu)  : <Movie>[];
        tamilMovies   = _showLangRow('ta') ? _fNoLang(_tamil)   : <Movie>[];
        kannadaMovies = _showLangRow('kn') ? _fNoLang(_kannada) : <Movie>[];
      }

      if (newReleases.isNotEmpty) {
        rows.add(SliverToBoxAdapter(
          child: MovieRowSection(
            title: '🆕 New Releases',
            movies: newReleases,
            cardWidth: 115,
            cardHeight: 165,
            onSeeAll: () => mainNavTabNotifier.value = 1,
          ),
        ));
      }
      if (trendingMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(
          child: MovieRowSection(
            title: '🔥 Trending Worldwide',
            movies: trendingMovies,
            cardWidth: 115,
            cardHeight: 165,
            onSeeAll: () => mainNavTabNotifier.value = 1,
          ),
        ));
      }
      if (topRatedMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(
          child: MovieRowSection(
            title: '🏆 Top Rated Movies',
            movies: topRatedMovies,
            cardWidth: 110,
            cardHeight: 160,
            onSeeAll: () => mainNavTabNotifier.value = 1,
          ),
        ));
      }
      if (popularMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(
          child: MovieRowSection(
            title: '🍿 Most Popular',
            movies: popularMovies,
            cardWidth: 120,
            cardHeight: 175,
            show4K: true,
            onSeeAll: () => mainNavTabNotifier.value = 1,
          ),
        ));
      }
      if (hindiMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(
          child: MovieRowSection(
            title: '🇮🇳 Bollywood Blockbusters',
            movies: hindiMovies,
            cardWidth: 110,
            cardHeight: 160,
            onSeeAll: () => mainNavTabNotifier.value = 1,
          ),
        ));
      }

      if (_loadingRest) {
        rows.add(
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Loading more content...',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      if (teluguMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🎬 Telugu Hits', movies: teluguMovies, cardWidth: 110, cardHeight: 160)));
      }
      if (tamilMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🎭 Tamil Favorites', movies: tamilMovies, cardWidth: 110, cardHeight: 160)));
      }
      if (kannadaMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🎥 Kannada Films', movies: kannadaMovies, cardWidth: 110, cardHeight: 160)));
      }
      if (animeMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🎌 Anime Picks', movies: animeMovies, cardWidth: 110, cardHeight: 160)));
      }
      if (horrorMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '😱 Horror Nights', movies: horrorMovies, cardWidth: 110, cardHeight: 160)));
      }
      if (comedyMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '😂 Comedy Specials', movies: comedyMovies, cardWidth: 110, cardHeight: 160)));
      }
      if (sciFiMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🚀 Sci-Fi Universe', movies: sciFiMovies, cardWidth: 110, cardHeight: 160)));
      }
      if (romanceMovies.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '❤️ Romantic Movies', movies: romanceMovies, cardWidth: 110, cardHeight: 160)));
      }
    } else if (_selectedCategory == 2) {
      // Shows — _f() filters inside each show row
      final allShows      = _f(_tvShows);
      final popularShows  = _f(_tvShows.reversed.toList());
      final comedyShows   = _f(_tvShows.where((m) => m.genreIds.contains(35)).toList());
      final sciFiShows    = _f(_tvShows.where((m) => m.genreIds.contains(878) || m.genreIds.contains(10765)).toList());
      final dramaShows    = _f(_tvShows.where((m) => m.genreIds.contains(18)).toList());

      if (allShows.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🔥 Trending Shows', movies: allShows, cardWidth: 115, cardHeight: 165)));
      }
      if (popularShows.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🍿 Popular Shows', movies: popularShows, cardWidth: 115, cardHeight: 165)));
      }
      if (comedyShows.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '😂 Comedy Shows', movies: comedyShows, cardWidth: 110, cardHeight: 160)));
      }
      if (sciFiShows.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🚀 Sci-Fi & Fantasy Shows', movies: sciFiShows, cardWidth: 110, cardHeight: 160)));
      }
      if (dramaShows.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🎭 Drama Shows', movies: dramaShows, cardWidth: 110, cardHeight: 160)));
      }
    } else if (_selectedCategory == 3) {
      // Anime — _f() filters inside each anime row
      final animePicks   = _f(_anime);
      final actionAnime  = _f(_anime.where((m) => m.genreIds.contains(28)).toList());
      final sciFiAnime   = _f(_anime.where((m) => m.genreIds.contains(878)).toList());
      final comedyAnime  = _f(_anime.where((m) => m.genreIds.contains(35)).toList());
      final romanceAnime = _f(_anime.where((m) => m.genreIds.contains(10749)).toList());

      if (animePicks.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🎌 Anime Picks', movies: animePicks, cardWidth: 115, cardHeight: 165)));
      }
      if (actionAnime.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🎬 Action Anime', movies: actionAnime, cardWidth: 110, cardHeight: 160)));
      }
      if (sciFiAnime.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🚀 Sci-Fi Anime', movies: sciFiAnime, cardWidth: 110, cardHeight: 160)));
      }
      if (comedyAnime.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '😂 Comedy Anime', movies: comedyAnime, cardWidth: 110, cardHeight: 160)));
      }
      if (romanceAnime.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '❤️ Romantic Anime', movies: romanceAnime, cardWidth: 110, cardHeight: 160)));
      }
    } else if (_selectedCategory == 4) {
      // Shorts — _f() filters inside each shorts row
      final quickWatches  = _f(_trending.take(10).toList());
      final shortReleases = _f(_newRelease.take(10).toList());
      final popularShorts = _f(_popular.take(10).toList());

      if (quickWatches.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '⏱️ Quick Watches', movies: quickWatches, cardWidth: 115, cardHeight: 165)));
      }
      if (shortReleases.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🆕 Short Releases', movies: shortReleases, cardWidth: 115, cardHeight: 165)));
      }
      if (popularShorts.isNotEmpty) {
        rows.add(SliverToBoxAdapter(child: MovieRowSection(title: '🍿 Popular Shorts', movies: popularShorts, cardWidth: 115, cardHeight: 165)));
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final categoryRows = _buildCategoryRows();
    final hasMovies = categoryRows.any((w) => w is SliverToBoxAdapter && w.child is MovieRowSection);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildTopBar()),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildCategoryPills()),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),

              // Hero Carousel + Continue Watching sit above the filters
              if (!_loadingFirst && _selectedCategory == 0 && _trending.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: HeroCarousel(movies: _trending.take(6).toList()),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<List<Movie>>(
                    valueListenable: HistoryService.instance.historyNotifier,
                    builder: (context, historyList, _) {
                      if (historyList.isEmpty) return const SizedBox.shrink();
                      return MovieRowSection(
                        title: '🔥 Continue Watching',
                        movies: historyList,
                        isContinueWatching: true,
                      );
                    },
                  ),
                ),
              ],

              // Filters row — now below the banner
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverToBoxAdapter(child: _buildFiltersRow()),
              if (_isFilterActive)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, color: AppColors.accent, size: 13),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Filters active — showing matching results',
                            style: TextStyle(color: AppColors.accent, fontSize: 11),
                          ),
                        ),
                        GestureDetector(
                          onTap: _resetFilters,
                          child: const Text(
                            'Clear ✕',
                            style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              if (_loadingFirst || (_selectedCategory == 2 && _loadingTv) || _loadingFiltered)
                _buildLoadingView()
              else if (!hasMovies)
                _buildNoResultsView()
              else
                // Category Rows (filtered in _buildCategoryRows)
                ...categoryRows,

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width > 768;
    if (isDesktop) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Image.asset(
            'assets/header_logo.png',
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => RichText(
              text: const TextSpan(
                text: 'MOVIENEST',
                style: TextStyle(color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
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
          const SizedBox(width: 10),
          Stack(
            children: [
              const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 22),
              Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle),
                  child: const Center(
                    child: Text('3', style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width > 768;
    if (isDesktop) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(26)),
        child: const Row(
          children: [
            Icon(Icons.search, color: AppColors.textMuted, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Search movies, shows and more...', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
            Icon(Icons.tune, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPills() {
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width > 768;
    if (isDesktop) return const SizedBox.shrink();
    final icons = [Icons.home, Icons.movie_outlined, Icons.tv, Icons.animation, Icons.video_library_outlined];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final selected = i == _selectedCategory;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = i;
                _selectedGenre    = 'All Genres';
                _selectedLanguage = 'All Languages';
                _selectedYear     = 'Release Year';
                _selectedSort     = 'Sort By';
              });
              if (i == 2) {
                _loadTvShows();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : AppColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icons[i], size: 13, color: selected ? Colors.black : AppColors.textSecondary),
                  if (i > 0) const SizedBox(width: 4),
                  Text(_categories[i], style: TextStyle(color: selected ? Colors.black : AppColors.textSecondary, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _chip(_selectedGenre, Icons.grid_view, _selectedGenre != 'All Genres',
              () => _sheet('Genre', ['All Genres','Action','Comedy','Drama','Horror','Sci-Fi','Romance','Thriller','Animation'])),
          const SizedBox(width: 8),
          _chip(_selectedLanguage, Icons.translate, _selectedLanguage != 'All Languages',
              () => _sheet('Language', ['All Languages','Hindi','Tamil','Telugu','Kannada','English','Spanish','French','Japanese','Korean'])),
          const SizedBox(width: 8),
          _chip(_selectedYear, Icons.calendar_month, _selectedYear != 'Release Year',
              () => _sheet('Year', ['Release Year','2026','2025','2024','2023','2022','2021','2020'])),
          const SizedBox(width: 8),
          _chip(_selectedSort, Icons.swap_vert, _selectedSort != 'Sort By',
              () => _sheet('Sort', ['Sort By','Popularity','Rating','Release Date'])),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon, bool isActive, VoidCallback onTap) {
    final color = isActive ? AppColors.accent : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.accent : AppColors.border, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
            const SizedBox(width: 6),
            Icon(isActive ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  void _sheet(String type, List<String> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Select $type', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: AppColors.border, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final opt = options[i];
                  final sel = (type == 'Genre' && _selectedGenre == opt) ||
                      (type == 'Language' && _selectedLanguage == opt) ||
                      (type == 'Year' && _selectedYear == opt) ||
                      (type == 'Sort' && _selectedSort == opt);
                  return ListTile(
                    title: Text(opt, style: TextStyle(
                        color: sel ? AppColors.accent : AppColors.textPrimary,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                    trailing: sel ? const Icon(Icons.check, color: AppColors.accent) : null,
                    onTap: () {
                      setState(() {
                        if (type == 'Genre') _selectedGenre = opt;
                        if (type == 'Language') _selectedLanguage = opt;
                        if (type == 'Year') _selectedYear = opt;
                        if (type == 'Sort') _selectedSort = opt;
                      });
                      Navigator.pop(ctx);
                      _applyFilters();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
