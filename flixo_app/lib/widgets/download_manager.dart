import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../utils/globals.dart';

class DownloadManager extends StatefulWidget {
  const DownloadManager({super.key});

  @override
  State<DownloadManager> createState() => _DownloadManagerState();
}

class _DownloadManagerState extends State<DownloadManager> with SingleTickerProviderStateMixin {
  DownloadNotification? _activeNotification;
  Timer? _dismissTimer;
  double _notificationY = -150.0; // Start offscreen

  @override
  void initState() {
    super.initState();
    DownloadService.instance.notificationNotifier.addListener(_onNotificationReceived);
  }

  @override
  void dispose() {
    DownloadService.instance.notificationNotifier.removeListener(_onNotificationReceived);
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _onNotificationReceived() {
    final event = DownloadService.instance.notificationNotifier.value;
    if (event == null) return;

    _dismissTimer?.cancel();
    setState(() {
      _activeNotification = event;
      _notificationY = 0.0; // Slide down into view
    });

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _notificationY = -150.0; // Slide back up
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 12.0;

    return Stack(
      children: [
        // ── Top Notification Banner ───────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          top: _notificationY == 0.0 ? topPadding : _notificationY,
          left: 16,
          right: 16,
          child: _activeNotification == null
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: () {
                    // Navigate to Downloads tab
                    mainNavTabNotifier.value = 3;
                    setState(() {
                      _notificationY = -150.0;
                    });
                  },
                  child: RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getNotificationBorderColor(_activeNotification!.type),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              _getNotificationIcon(_activeNotification!.type),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getNotificationTitle(_activeNotification!.type),
                                      style: TextStyle(
                                        color: _getNotificationTextColor(_activeNotification!.type),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _activeNotification!.message,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _notificationY = -150.0;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),

        // ── Floating Active Progress Capsule ──────────────
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: ValueListenableBuilder<List<DownloadItem>>(
            valueListenable: DownloadService.instance.downloadsNotifier,
            builder: (context, downloads, _) {
              final activeDownloads = downloads
                  .where((e) =>
                      e.status == 'downloading' ||
                      e.status == 'connecting' ||
                      e.status == 'saving')
                  .toList();

              if (activeDownloads.isEmpty) {
                return const SizedBox.shrink();
              }

              final item = activeDownloads.first;
              final isConnecting = item.status == 'connecting';
              final isSaving = item.status == 'saving';

              return GestureDetector(
                onTap: () => mainNavTabNotifier.value = 3, // Navigate to Downloads
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.card.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Small movie poster / thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 32,
                              height: 48,
                              child: item.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: item.imageUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppColors.surface,
                                        child: const Icon(Icons.movie, size: 16, color: Colors.white30),
                                      ),
                                    )
                                  : Container(
                                      color: AppColors.surface,
                                      child: const Icon(Icons.movie, size: 16, color: Colors.white30),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Text Info and Progress bar
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isConnecting
                                          ? 'Connecting...'
                                          : isSaving
                                              ? 'Saving...'
                                              : '${(item.progress * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: isConnecting || isSaving
                                            ? AppColors.textSecondary
                                            : AppColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (isConnecting || isSaving)
                                  const ClipRRect(
                                    borderRadius: BorderRadius.all(Radius.circular(2)),
                                    child: LinearProgressIndicator(
                                      minHeight: 3,
                                      backgroundColor: AppColors.surface,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                                    ),
                                  )
                                else ...[
                                  ClipRRect(
                                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                                    child: LinearProgressIndicator(
                                      value: item.progress,
                                      minHeight: 3,
                                      backgroundColor: AppColors.surface,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Downloading at ${item.speed}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (activeDownloads.length > 1)
                                        Text(
                                          '+${activeDownloads.length - 1} more queued',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Pause action button
                          IconButton(
                            icon: const Icon(Icons.pause_circle_outline, color: AppColors.textPrimary, size: 24),
                            onPressed: () => DownloadService.instance.pauseDownload(item.title),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Helper Styling Methods ──────────────────────────────
  Color _getNotificationBorderColor(DownloadNotificationType type) {
    switch (type) {
      case DownloadNotificationType.started:
        return AppColors.accent.withOpacity(0.6);
      case DownloadNotificationType.completed:
        return Colors.green.withOpacity(0.6);
      case DownloadNotificationType.failed:
        return Colors.redAccent.withOpacity(0.6);
    }
  }

  Color _getNotificationTextColor(DownloadNotificationType type) {
    switch (type) {
      case DownloadNotificationType.started:
        return AppColors.accent;
      case DownloadNotificationType.completed:
        return Colors.green;
      case DownloadNotificationType.failed:
        return Colors.redAccent;
    }
  }

  String _getNotificationTitle(DownloadNotificationType type) {
    switch (type) {
      case DownloadNotificationType.started:
        return 'DOWNLOAD STARTED';
      case DownloadNotificationType.completed:
        return 'DOWNLOAD COMPLETED';
      case DownloadNotificationType.failed:
        return 'DOWNLOAD FAILED';
    }
  }

  Widget _getNotificationIcon(DownloadNotificationType type) {
    switch (type) {
      case DownloadNotificationType.started:
        return const Icon(Icons.download, color: AppColors.accent, size: 22);
      case DownloadNotificationType.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 22);
      case DownloadNotificationType.failed:
        return const Icon(Icons.error_outline, color: Colors.redAccent, size: 22);
    }
  }
}
