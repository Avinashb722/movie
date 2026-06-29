import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/history_service.dart';
import '../widgets/movie_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Watch History',
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Keep track of movies and shows you have recently watched.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ValueListenableBuilder(
                  valueListenable: HistoryService.instance.historyNotifier,
                  builder: (context, history, _) {
                    if (history.isEmpty) return const SizedBox.shrink();
                    return OutlinedButton.icon(
                      icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.accent, size: 16),
                      label: const Text('Clear All', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accent),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            title: const Text('Clear Watch History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            content: const Text('Are you sure you want to clear your entire watch history? This cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                              ),
                              TextButton(
                                onPressed: () {
                                  HistoryService.instance.clearHistory();
                                  Navigator.pop(context);
                                },
                                child: const Text('Clear', style: TextStyle(color: AppColors.live)),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 28),

            ValueListenableBuilder(
              valueListenable: HistoryService.instance.historyNotifier,
              builder: (context, history, _) {
                if (history.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 100),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            'Your History is empty',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Movies you watch will show up here so you can easily resume them.',
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
                  itemCount: history.length,
                  itemBuilder: (context, i) {
                    final movie = history[i];
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
