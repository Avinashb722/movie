import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import 'search_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final ScrollController _scrollController = ScrollController();
  
  String _selectedCat = 'All';
  String _selectedGenre = 'All';
  List<Movie> _movies = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;

  final _cats = ['All', 'Movies', 'Shows', 'Anime', 'Shorts'];
  final _genres = ['All', 'Action', 'Comedy', 'Drama', 'Horror', 'More'];
  final _platforms = ['Netflix', 'Prime', 'Disney+', 'HBO', 'More'];

  @override
  void initState() { 
    super.initState(); 
    _load(); 
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && !_loadingMore && _hasMore) {
        _loadNextPage();
      }
    }
  }

  void _showMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _currentPage = 1;
      _hasMore = true;
      _movies = [];
    });
    
    int? genreId;
    if (_selectedGenre == 'Action') genreId = 28;
    else if (_selectedGenre == 'Comedy') genreId = 35;
    else if (_selectedGenre == 'Drama') genreId = 18;
    else if (_selectedGenre == 'Horror') genreId = 27;

    List<Movie> m;
    try {
      if (_selectedCat == 'All' && _selectedGenre == 'All') {
        m = await TmdbService.discoverMovies(page: _currentPage);
      } else {
        m = await TmdbService.discoverMovies(
          genreId: genreId,
          sortBy: 'popularity.desc',
          page: _currentPage,
        );
      }
    } catch (_) {
      m = [];
    }
    
    if (mounted) {
      setState(() { 
        _movies = m; 
        _loading = false; 
        if (m.isEmpty) _hasMore = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _loadingMore = true);
    _currentPage++;

    int? genreId;
    if (_selectedGenre == 'Action') genreId = 28;
    else if (_selectedGenre == 'Comedy') genreId = 35;
    else if (_selectedGenre == 'Drama') genreId = 18;
    else if (_selectedGenre == 'Horror') genreId = 27;

    List<Movie> nextItems;
    try {
      if (_selectedCat == 'All' && _selectedGenre == 'All') {
        nextItems = await TmdbService.discoverMovies(page: _currentPage);
      } else {
        nextItems = await TmdbService.discoverMovies(
          genreId: genreId,
          sortBy: 'popularity.desc',
          page: _currentPage,
        );
      }
    } catch (_) {
      nextItems = [];
    }

    if (mounted) {
      setState(() {
        _loadingMore = false;
        if (nextItems.isEmpty) {
          _hasMore = false;
        } else {
          _movies.addAll(nextItems);
        }
      });
    }
  }

  Widget _buildShimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.card,
                          AppColors.border.withValues(alpha: 0.3),
                          AppColors.card,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          childCount: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Discover', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SearchScreen()),
                      );
                    },
                    child: AbsorbPointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
                        child: const TextField(
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search movies, shows and more...',
                            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            border: InputBorder.none,
                            icon: Icon(Icons.search, color: AppColors.textMuted, size: 18),
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                            suffixIcon: Icon(Icons.tune, color: AppColors.textMuted, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PillRow(
                    items: _cats,
                    selected: _selectedCat,
                    onSelect: (v) {
                      setState(() => _selectedCat = v);
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Genres', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _PillRow(
                    items: _genres,
                    selected: _selectedGenre,
                    onSelect: (v) {
                      setState(() => _selectedGenre = v);
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Platforms', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemCount: _platforms.length,
                      itemBuilder: (context, i) {
                        final platform = _platforms[i];
                        return GestureDetector(
                          onTap: () {
                            _showMessage('Platform Selected', 'Showing movies streaming on $platform.');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(platform, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Recommended For You', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
            if (_loading)
              _buildShimmerGrid()
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => MovieCard(movie: _movies[i], width: double.infinity, height: double.infinity),
                    childCount: _movies.length,
                  ),
                ),
              ),
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

class _PillRow extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;
  const _PillRow({required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final sel = items[i] == selected;
          return GestureDetector(
            onTap: () => onSelect(items[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? AppColors.accent : AppColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(items[i],
                style: TextStyle(color: sel ? Colors.black : AppColors.textSecondary,
                  fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
            ),
          );
        },
      ),
    );
  }
}
