import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';
import 'movie_card.dart';

class MovieRowSection extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final double cardWidth;
  final double cardHeight;
  final bool show4K;
  final bool isContinueWatching;

  final VoidCallback? onSeeAll;

  const MovieRowSection({
    super.key,
    required this.title,
    required this.movies,
    this.cardWidth  = 110,
    this.cardHeight = 160,
    this.show4K = false,
    this.isContinueWatching = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Horizontal scroll
        SizedBox(
          height: isContinueWatching ? 200 : cardHeight + 45,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: movies.length,
            itemBuilder: (_, i) => isContinueWatching
                ? ContinueWatchingCard(movie: movies[i])
                : MovieCard(
                    movie: movies[i],
                    width: cardWidth,
                    height: cardHeight,
                    show4K: show4K,
                  ),
          ),
        ),
      ],
    );
  }
}
