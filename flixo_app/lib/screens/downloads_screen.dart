import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../services/download_service.dart';
import '../models/movie.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Movies', 'Shows'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              const Text('Downloads', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
              const Spacer(),
              const Text('Swipe to Delete', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 12),
          // Filter pills
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final sel = _filters[i] == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = _filters[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.accent : AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(_filters[i],
                      style: TextStyle(color: sel ? Colors.black : AppColors.textSecondary,
                        fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Download list
          Expanded(
            child: ValueListenableBuilder<List<DownloadItem>>(
              valueListenable: DownloadService.instance.downloadsNotifier,
              builder: (context, downloads, child) {
                final filteredDownloads = downloads.where((d) {
                  if (_filter == 'Movies') {
                    return !d.title.contains(RegExp(r'S\d+ E\d+'));
                  } else if (_filter == 'Shows') {
                    return d.title.contains(RegExp(r'S\d+ E\d+'));
                  }
                  return true;
                }).toList();

                if (filteredDownloads.isEmpty) {
                  return const Center(
                    child: Text(
                      'No downloads here',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredDownloads.length,
                  itemBuilder: (_, i) {
                    final d = filteredDownloads[i];
                    final progress = d.progress;
                    final done = d.done;
                    return Dismissible(
                      key: Key(d.title),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        DownloadService.instance.removeDownload(d.title);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('"${d.title}" deleted')),
                        );
                      },
                      child: GestureDetector(
                        onTap: () {
                          if (done && d.localPath != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  movie: Movie(
                                    id: 0,
                                    title: d.title,
                                    posterPath: '',
                                    backdropPath: '',
                                    rating: 0.0,
                                    overview: '',
                                    releaseDate: '',
                                    language: '',
                                  ),
                                  localFilePath: d.localPath,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            // Poster image or placeholder
                            ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Container(
                                width: 55, height: 75,
                                color: Color(d.color),
                                child: d.imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: d.imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                        ),
                                        errorWidget: (_, __, ___) => const Icon(Icons.movie, color: Colors.white54, size: 24),
                                      )
                                    : const Icon(Icons.movie, color: Colors.white54, size: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d.title,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text('${d.duration} • ${d.quality}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              const SizedBox(height: 6),
                              if (!done && !d.failed) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: AppColors.surface,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                                    minHeight: 4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      d.status == 'queued' ? 'Queued' :
                                      d.status == 'connecting' ? 'Connecting...' :
                                      d.status == 'saving' ? 'Saving file...' :
                                      d.status == 'paused' ? 'Paused' :
                                      '${(progress * 100).toInt()}% downloaded',
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                    ),
                                    if (d.speed.isNotEmpty)
                                      Text(
                                        d.speed,
                                        style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600),
                                      ),
                                  ],
                                ),
                              ] else if (d.failed)
                                const Text('Failed — swipe left to delete', style: TextStyle(color: Colors.redAccent, fontSize: 11))
                              else
                                const Text('Completed', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                            ])),
                            const SizedBox(width: 8),
                            if (done)
                              const Icon(Icons.play_circle_fill, color: AppColors.accent, size: 26)
                            else if (d.failed)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.replay, color: AppColors.accent, size: 22),
                                onPressed: () => DownloadService.instance.resumeDownload(d.title),
                              )
                            else if (d.status == 'paused')
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 24),
                                onPressed: () => DownloadService.instance.resumeDownload(d.title),
                              )
                            else if (d.status == 'downloading' || d.status == 'connecting' || d.status == 'saving')
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.pause_rounded, color: Colors.white70, size: 22),
                                onPressed: () => DownloadService.instance.pauseDownload(d.title),
                              )
                            else
                              const Icon(Icons.schedule, color: Colors.white30, size: 22),
                          ]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Storage bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Storage', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('46.8 GB / 128 GB Used', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.365,
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  minHeight: 6,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
