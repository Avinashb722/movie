import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';
import '../screens/movie_detail_screen.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final double width;
  final double height;
  final bool showTitle;
  final bool show4K;

  const MovieCard({
    super.key,
    required this.movie,
    this.width  = 110,
    this.height = 160,
    this.showTitle = true,
    this.show4K = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
      ),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Poster ──────────────────────────────────────
            height == double.infinity
                ? Expanded(child: _buildPoster())
                : _buildPoster(),
            // ── Title ────────────────────────────────────────
            if (showTitle) ...[
              const SizedBox(height: 5),
              Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (movie.year.isNotEmpty)
                Text(
                  movie.year,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPoster() {
    final posterHeight = height == double.infinity ? null : height;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: movie.posterUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: movie.posterUrl,
                  width: width,
                  height: posterHeight,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _shimmerBox(width, posterHeight ?? 160),
                  errorWidget: (_, __, ___) => _placeholder(width, posterHeight ?? 160),
                )
              : _placeholder(width, posterHeight ?? 160),
        ),
        // Rating badge top-left
        Positioned(
          top: 6, left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: AppColors.accent, size: 9),
                const SizedBox(width: 2),
                Text(
                  movie.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 4K badge top-right
        if (show4K)
          Positioned(
            top: 6, right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                '4K',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _shimmerBox(double w, double h) => Shimmer.fromColors(
    baseColor: AppColors.surface,
    highlightColor: const Color(0xFF2A2A2A),
    child: Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );

  Widget _placeholder(double w, double h) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.movie, color: AppColors.textMuted, size: 32),
  );
}

// ── Continue-Watching card with progress bar ──────────────────
class ContinueWatchingCard extends StatelessWidget {
  final Movie movie;
  const ContinueWatchingCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
      ),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: movie.posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: movie.posterUrl,
                          width: 130, height: 150,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 130, height: 150,
                          color: AppColors.card,
                        ),
                ),
                // Play icon center
                const Positioned.fill(
                  child: Center(
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 18,
                      child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                // Progress bar at bottom
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      color: AppColors.textMuted,
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.45,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              '2h 49m left',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
