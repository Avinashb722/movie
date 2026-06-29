import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import 'movie_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Movie> _results = [];
  bool _loading = false;
  String _selectedFilter = 'All';
  final _filters = ['All', 'Movies', 'Shows', 'People'];

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final res = await TmdbService.searchMovies(q.trim());
    if (mounted) {
      setState(() {
        _results = res;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        autofocus: false,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search movies, shows and more...',
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: AppColors.textMuted, size: 18),
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() {});
                          _search(val);
                        },
                      ),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        _search('');
                      },
                      child: const Text('Cancel', style: TextStyle(color: AppColors.accent, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),

            // ── Filter pills ──────────────────────────────
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _filters.length,
                itemBuilder: (_, i) {
                  final sel = _filters[i] == _selectedFilter;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = _filters[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.accent : AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _filters[i],
                        style: TextStyle(
                          color: sel ? Colors.black : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // ── Results ───────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search, color: AppColors.textMuted, size: 60),
                              const SizedBox(height: 12),
                              Text(
                                _ctrl.text.isEmpty ? 'Search for movies...' : 'No results found',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _results.length,
                          itemBuilder: (_, i) => _SearchResultTile(movie: _results[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Movie movie;
  const _SearchResultTile({required this.movie});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => MovieDetailScreen(movie: movie),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: movie.posterUrl.isNotEmpty
                  ? Image.network(movie.posterUrl, width: 50, height: 70, fit: BoxFit.cover)
                  : Container(
                      width: 50,
                      height: 70,
                      color: AppColors.surface,
                      child: const Icon(Icons.movie, color: AppColors.textMuted),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${movie.year} • Action, Drama',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.accent, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        movie.rating.toStringAsFixed(1),
                        style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
