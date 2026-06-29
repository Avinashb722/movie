import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/watchlist_service.dart';
import '../widgets/movie_card.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Watchlist',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your saved movies, shows, and animations that you plan to watch later.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 28),

            ValueListenableBuilder(
              valueListenable: WatchlistService.instance.watchlistNotifier,
              builder: (context, watchlist, _) {
                if (watchlist.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 100),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_outline_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            'Your Watchlist is empty',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the bookmark icon on any movie detail page to save it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 5 : (MediaQuery.of(context).size.width > 800 ? 4 : 2),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: watchlist.length,
                  itemBuilder: (context, i) {
                    final movie = watchlist[i];
                    return MovieCard(movie: movie);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
