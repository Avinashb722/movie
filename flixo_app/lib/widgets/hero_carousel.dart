import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';
import '../screens/movie_detail_screen.dart';
import '../services/watchlist_service.dart';


class HeroCarousel extends StatefulWidget {
  final List<Movie> movies;
  const HeroCarousel({super.key, required this.movies});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.movies.length + (widget.movies.isNotEmpty ? 1 : 0);
    if (itemCount == 0) return const SizedBox(height: 220);
    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: itemCount,
          itemBuilder: (ctx, i, _) {
            if (i == 0) {
              return const _StaticBannerItem();
            }
            return _HeroItem(movie: widget.movies[i - 1]);
          },
          options: CarouselOptions(
            height: 220,
            viewportFraction: 1.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            onPageChanged: (i, _) => setState(() => _current = i),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSmoothIndicator(
          activeIndex: _current,
          count: itemCount.clamp(0, 8),
          effect: const ExpandingDotsEffect(
            activeDotColor: AppColors.accent,
            dotColor: Color(0xFF444444),
            dotHeight: 5,
            dotWidth: 5,
            expansionFactor: 3,
          ),
        ),
      ],
    );
  }
}

class _StaticBannerItem extends StatelessWidget {
  const _StaticBannerItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/popup_banner.png',
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 220,
            color: AppColors.card,
            child: const Center(
              child: Icon(Icons.movie_creation_outlined, size: 50, color: Colors.white24),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroItem extends StatelessWidget {
  final Movie movie;
  const _HeroItem({required this.movie});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Backdrop image
              if (movie.backdropUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: movie.backdropUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                )
              else
                Container(height: 220, color: AppColors.card),

              // Gradient overlay
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // "NEW RELEASE" badge top-left
              Positioned(
                top: 12, left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.live,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                      SizedBox(width: 4),
                      Text('RELEASE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),

              // Rating badge top-right
              Positioned(
                top: 12, right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: AppColors.accent, size: 11),
                      const SizedBox(width: 3),
                      Text(
                        movie.rating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom info
              Positioned(
                bottom: 12, left: 14, right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title.toUpperCase(),
                      maxLines: 2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      movie.overview.length > 50
                          ? movie.overview.substring(0, 50) + '...'
                          : movie.overview,
                      style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 11),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ActionBtn(
                          icon: Icons.play_arrow,
                          label: 'Play',
                          filled: true,
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie))),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<List<Movie>>(
                          valueListenable: WatchlistService.instance.watchlistNotifier,
                          builder: (context, watchlist, _) {
                            final inWatchlist = WatchlistService.instance.isInWatchlist(movie.id);
                            return _ActionBtn(
                              icon: inWatchlist ? Icons.check : Icons.add,
                              label: inWatchlist ? 'Added' : 'My List',
                              filled: inWatchlist,
                              onTap: () async {
                                await WatchlistService.instance.toggleWatchlist(movie);
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

                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: filled ? null : Border.all(color: Colors.white54),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: filled ? Colors.black : Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
