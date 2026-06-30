import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path_provider/path_provider.dart';
import 'torrent_service.dart';
import 'moviebox_service.dart';



class DownloadItem {
  final String title;
  final String duration;
  final String quality;
  double progress;
  bool done;
  bool failed;
  final int color;
  final String imageUrl;
  String? localPath;
  String? magnetUri;
  String? downloadUrl;
  // MovieBox re-fetch info (so we can refresh CDN-signed URLs before download)
  String movieBoxSubjectId;
  String movieBoxDetailPath;
  String status; // 'queued', 'connecting', 'downloading', 'saving', 'completed', 'failed'
  String speed;
  int peers;
  int downloadedSize;
  int totalSize;
  CancelToken? cancelToken;

  DownloadItem({
    required this.title,
    required this.duration,
    required this.quality,
    required this.progress,
    required this.done,
    required this.color,
    required this.imageUrl,
    this.failed = false,
    this.localPath,
    this.magnetUri,
    this.downloadUrl,
    this.movieBoxSubjectId = '',
    this.movieBoxDetailPath = '',
    this.status = 'queued',
    this.speed = '',
    this.peers = 0,
    this.downloadedSize = 0,
    this.totalSize = 0,
    this.cancelToken,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'duration': duration,
        'quality': quality,
        'progress': progress,
        'done': done,
        'failed': failed,
        'color': color,
        'imageUrl': imageUrl,
        'localPath': localPath,
        'magnetUri': magnetUri,
        'downloadUrl': downloadUrl,
        'status': status,
        'downloadedSize': downloadedSize,
        'totalSize': totalSize,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        title: json['title'] ?? '',
        duration: json['duration'] ?? '',
        quality: json['quality'] ?? '',
        progress: (json['progress'] ?? 0.0).toDouble(),
        done: json['done'] ?? false,
        failed: json['failed'] ?? false,
        color: json['color'] ?? 0xFF005599,
        imageUrl: json['imageUrl'] ?? '',
        localPath: json['localPath'],
        magnetUri: json['magnetUri'],
        downloadUrl: json['downloadUrl'],
        status: json['status'] ?? 'completed',
        downloadedSize: json['downloadedSize'] ?? 0,
        totalSize: json['totalSize'] ?? 0,
      );
}

class ActiveTorrentDownload {
  final DownloadItem item;
  final String magnetUri;
  File? fileHandle;

  ActiveTorrentDownload({
    required this.item,
    required this.magnetUri,
  });
}

enum DownloadNotificationType { started, completed, failed }

class DownloadNotification {
  final String title;
  final DownloadNotificationType type;
  final String message;

  DownloadNotification({
    required this.title,
    required this.type,
    required this.message,
  });
}

class DownloadService {
  static final DownloadService instance = DownloadService._internal();
  DownloadService._internal() {
    _loadDownloads();
    _initNotifications();
  }

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final Map<String, int> _lastNotificationTimes = {};

  Future<void> _initNotifications() async {
    if (kIsWeb) return;
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      await _localNotifications.initialize(initializationSettings);
    } catch (e) {
      debugPrint('[DownloadService] Notifications init error: $e');
    }
  }

  Future<void> _showSystemNotification(int id, String title, String body, {int? progress, int? maxProgress}) async {
    if (kIsWeb || (!kIsWeb && Platform.isWindows)) return;
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'flixo_downloads',
        'Downloads',
        channelDescription: 'Download status and progress notifications',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: progress != null,
        maxProgress: maxProgress ?? 100,
        progress: progress ?? 0,
        indeterminate: false,
      );
      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      await _localNotifications.show(
        id,
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('[DownloadService] Show notification error: $e');
    }
  }

  Future<void> _cancelSystemNotification(int id) async {
    if (kIsWeb) return;
    try {
      await _localNotifications.cancel(id);
    } catch (e) {
      debugPrint('[DownloadService] Cancel notification error: $e');
    }
  }

  final ValueNotifier<DownloadNotification?> notificationNotifier =
      ValueNotifier<DownloadNotification?>(null);



  final Dio _dio = Dio()
    ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.maxConnectionsPerHost = 30;
        return client;
      },
    );
  StreamSubscription<TorrentStatus>? _torrentSubscription;
  final Map<String, Isolate> _activeIsolates = {};
  
  Future<String> _getDownloadDir() async {
    if (kIsWeb) return '';
    if (!kIsWeb && Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/Flixo');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } else {
      final dir = await getDownloadsDirectory();
      return dir?.path ?? (await getApplicationDocumentsDirectory()).path;
    }
  }

  final ValueNotifier<List<DownloadItem>> downloadsNotifier =
      ValueNotifier<List<DownloadItem>>([]);

  final ValueNotifier<ActiveTorrentDownload?> activeTorrentDownload =
      ValueNotifier<ActiveTorrentDownload?>(null);

  final ValueNotifier<String?> triggerDownloadCommand =
      ValueNotifier<String?>(null);

  Future<void> _loadDownloads() async {
    try {
      List<DownloadItem> loaded = [];
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString('downloads');
        if (content != null) {
          final list = jsonDecode(content) as List;
          loaded = list.map((e) => DownloadItem.fromJson(e)).toList();
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/downloads.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          final list = jsonDecode(content) as List;
          loaded = list.map((e) => DownloadItem.fromJson(e)).toList();
        }
      }

      if (loaded.isNotEmpty) {
        // Sanitize status on startup
        for (var item in loaded) {
          if (item.status == 'downloading' ||
              item.status == 'connecting' ||
              item.status == 'saving') {
            item.status = 'failed';
            item.failed = true;
          }
        }
        downloadsNotifier.value = loaded;
        _processNextQueue();
      }
    } catch (e) {
      debugPrint('[DownloadService] Error loading downloads: $e');
    }
  }

  Future<void> _saveDownloads() async {
    try {
      final data = downloadsNotifier.value.map((e) => e.toJson()).toList();
      final content = jsonEncode(data);
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('downloads', content);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/downloads.json');
        await file.writeAsString(content);
      }
    } catch (e) {
      debugPrint('[DownloadService] Error saving downloads: $e');
    }
  }

  Future<void> addDownload(
    String title,
    String duration,
    String quality,
    String imageUrl, {
    String? downloadUrl,
    String? magnetUri,
    String movieBoxSubjectId = '',
    String movieBoxDetailPath = '',
  }) async {
    final exists = downloadsNotifier.value.any((e) => e.title == title);
    if (exists) return;

    try {
      if (!kIsWeb && await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('[DownloadService] Permission request error: $e');
    }

    final cancelToken = CancelToken();

    final item = DownloadItem(
      title: title,
      duration: duration.isNotEmpty ? duration : '2h 00m',
      quality: quality,
      progress: 0.0,
      done: false,
      color: 0xFF005599,
      imageUrl: imageUrl,
      cancelToken: cancelToken,
      magnetUri: magnetUri,
      downloadUrl: downloadUrl,
      movieBoxSubjectId: movieBoxSubjectId,
      movieBoxDetailPath: movieBoxDetailPath,
      status: 'queued',
    );

    downloadsNotifier.value = [...downloadsNotifier.value, item];
    await _saveDownloads();
    _processNextQueue();
  }

  void _processNextQueue() {
    final activeHttpCount = downloadsNotifier.value.where((e) => e.status == 'downloading' && e.downloadUrl != null).length;
    final maxConcurrentHttp = 10;

    final queued = downloadsNotifier.value.where((e) => e.status == 'queued').toList();
    if (queued.isEmpty) return;

    int startedHttp = 0;

    for (var item in queued) {
      if (item.magnetUri != null && item.magnetUri!.isNotEmpty) {
        if (activeTorrentDownload.value == null) {
          item.status = 'connecting';
          item.failed = false;
          _updateItemInList(item);
          activeTorrentDownload.value = ActiveTorrentDownload(
            item: item,
            magnetUri: item.magnetUri!,
          );
          _startNativeTorrentDownload(item, item.magnetUri!);
        }
      } else if (item.downloadUrl != null && item.downloadUrl!.isNotEmpty) {
        if ((activeHttpCount + startedHttp) < maxConcurrentHttp) {
          item.status = 'downloading';
          item.failed = false;
          _updateItemInList(item);
          _realDownload(item, item.downloadUrl!);
          startedHttp++;
        }
      }
    }
  }

  void pauseDownload(String title) {
    final idx = downloadsNotifier.value.indexWhere((e) => e.title == title);
    if (idx == -1) return;
    final item = downloadsNotifier.value[idx];
    if (item.status == 'downloading' || item.status == 'connecting') {
      item.status = 'paused';
      item.speed = '';
      item.cancelToken?.cancel('paused');
      _updateItemInList(item);

      // Kill background download isolate if active
      final isolate = _activeIsolates.remove(title);
      if (isolate != null) {
        isolate.kill(priority: Isolate.beforeNextEvent);
      }

      final active = activeTorrentDownload.value;
      if (active != null && active.item.title == title) {
        _torrentSubscription?.cancel();
        TorrentService.stopTorrent();
        activeTorrentDownload.value = null;
      }
      _saveDownloads();
    }
    _processNextQueue();
  }

  void resumeDownload(String title) {
    final idx = downloadsNotifier.value.indexWhere((e) => e.title == title);
    if (idx == -1) return;
    final item = downloadsNotifier.value[idx];
    if (item.status == 'paused' || item.status == 'failed') {
      item.status = 'queued';
      item.failed = false;
      _updateItemInList(item);
      _saveDownloads();
    }
    _processNextQueue();
  }

  Future<void> _realDownload(DownloadItem item, String url) async {
    if (kIsWeb) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        item.status = 'completed';
        item.done = true;
        item.failed = false;
        item.progress = 1.0;
        _updateItemInList(item);

        notificationNotifier.value = DownloadNotification(
          title: item.title,
          type: DownloadNotificationType.completed,
          message: 'Download completed: "${item.title}" is ready!',
        );
      } catch (e) {
        item.status = 'failed';
        item.failed = true;
        _updateItemInList(item);
      }
      await _saveDownloads();
      _processNextQueue();
      return;
    }

    try {
      final dirPath = await _getDownloadDir();
      final safeTitle = item.title.replaceAll(RegExp(r'[^\w\s]'), '').trim();

      String cleanUrl = url;
      final headers = <String, String>{};

      if (cleanUrl.contains('||')) {
        cleanUrl = cleanUrl.split('||').first;
      }
      if (cleanUrl.contains('|')) {
        final parts = cleanUrl.split('|');
        cleanUrl = parts.first;
        for (int i = 1; i < parts.length; i++) {
          final p = parts[i];
          if (p.startsWith('referer=')) {
            headers['Referer'] = p.substring('referer='.length);
          } else if (p.startsWith('user-agent=')) {
            headers['User-Agent'] = p.substring('user-agent='.length);
          }
        }
      }
      
      // Decode and extract the target URL if it is routed through the local proxy
      if (cleanUrl.contains('/play?url=')) {
        final match = RegExp(r'/play\?url=([^&]+)').firstMatch(cleanUrl);
        if (match != null) {
          cleanUrl = Uri.decodeComponent(match.group(1)!);
        }
      } else if (cleanUrl.contains('/play.ts?url=')) {
        final match = RegExp(r'/play\.ts\?url=([^&]+)').firstMatch(cleanUrl);
        if (match != null) {
          cleanUrl = Uri.decodeComponent(match.group(1)!);
        }
      }
      
      if (item.quality.toLowerCase().contains('2embed') || cleanUrl.contains('lookmovie') || cleanUrl.contains('tiktokcdn.com') || cleanUrl.contains('korso420dim.com')) {
        headers['Referer'] = 'https://gemma416okl.com';
        headers['Origin'] = 'https://gemma416okl.com';
        headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      }

      final bool isHls = cleanUrl.split('?').first.toLowerCase().endsWith('.m3u8');
      final String fileExt = isHls ? 'mp4' : (() {
        final ext = cleanUrl.split('?').first.split('.').last;
        return ext.length > 4 || ext.isEmpty ? 'mp4' : ext;
      })();
      final filePath = '$dirPath/$safeTitle.$fileExt';

      final cancelToken = CancelToken();
      item.cancelToken = cancelToken;

      notificationNotifier.value = DownloadNotification(
        title: item.title,
        type: DownloadNotificationType.started,
        message: 'Downloading "${item.title}" started...',
      );
      _showSystemNotification(
        item.title.hashCode,
        'Downloading ${item.title}',
        'Connecting...',
        progress: 0,
      );

      final bool isMovieBox = cleanUrl.contains('hakunaymatata.com') || cleanUrl.contains('aoneroom.com');
      final bool isArchive = cleanUrl.contains('archive.org');

      String downloadUrl = cleanUrl;

      if (isMovieBox) {
        // Refresh the CDN-signed URL right before download starts (URLs expire in ~5 min)
        if (item.movieBoxSubjectId.isNotEmpty) {
          debugPrint('[DownloadService] Refreshing MovieBox URL before download...');
          try {
            final freshStream = await MovieBoxService.refreshUrl(MovieBoxStream(
              url: url,
              resolution: int.tryParse(item.quality.replaceAll(RegExp(r'[^0-9]'), '')) ?? 720,
              size: '',
              subjectId: item.movieBoxSubjectId,
              detailPath: item.movieBoxDetailPath,
            ));
            downloadUrl = freshStream.url;
            debugPrint('[DownloadService] Fresh MovieBox URL obtained: ${downloadUrl.substring(0, 50)}...');
          } catch (e) {
            debugPrint('[DownloadService] URL refresh failed, using cached URL: $e');
          }
        }
        headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
        headers['Referer'] = 'https://fmoviesunblocked.net/';
        headers['Origin'] = 'https://h5.aoneroom.com';
      } else if (isArchive) {
        downloadUrl = 'https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(cleanUrl)}';
        headers['User-Agent'] = 'Mozilla/5.0 (Android; Mobile) AppleWebKit/537.36 Chrome/120';
      } else {
        headers['User-Agent'] = 'Mozilla/5.0 (Android; Mobile) AppleWebKit/537.36 Chrome/120';
      }

      // Step 1: Detect if HLS (.m3u8) stream and parse segments if applicable
      List<String>? segmentUrls;

      if (isHls) {
        debugPrint('[DownloadService] HLS Stream detected. Parsing segments...');
        final m3u8Response = await _dio.get<String>(
          downloadUrl,
          options: Options(headers: headers),
          cancelToken: cancelToken,
        );
        final m3u8Content = m3u8Response.data ?? '';
        final lines = LineSplitter.split(m3u8Content).toList();
        final basePath = downloadUrl.substring(0, downloadUrl.lastIndexOf('/') + 1);

        bool isMasterPlaylist = m3u8Content.contains('#EXT-X-STREAM-INF');
        String activeM3u8Content = m3u8Content;
        List<String> activeLines = lines;
        String activeBasePath = basePath;

        if (isMasterPlaylist) {
          debugPrint('[DownloadService] HLS Master playlist detected. Choosing best variant...');
          String? bestVariantUrl;
          int maxBandwidth = 0;
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.startsWith('#EXT-X-STREAM-INF')) {
              final match = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
              if (match != null) {
                final bandwidth = int.tryParse(match.group(1) ?? '0') ?? 0;
                if (bandwidth > maxBandwidth && i + 1 < lines.length) {
                  maxBandwidth = bandwidth;
                  bestVariantUrl = lines[i + 1].trim();
                }
              }
            }
          }

          if (bestVariantUrl != null) {
            final nextUrl = bestVariantUrl.startsWith('http') ? bestVariantUrl : basePath + bestVariantUrl;
            debugPrint('[DownloadService] Fetching variant playlist: $nextUrl');
            final variantResponse = await _dio.get<String>(
              nextUrl,
              options: Options(headers: headers),
              cancelToken: cancelToken,
            );
            activeM3u8Content = variantResponse.data ?? '';
            debugPrint('[DownloadService] Variant playlist content length: ${activeM3u8Content.length}');
            if (activeM3u8Content.isNotEmpty) {
              final previewLen = activeM3u8Content.length > 300 ? 300 : activeM3u8Content.length;
              debugPrint('[DownloadService] Sample content: ${activeM3u8Content.substring(0, previewLen)}');
            }
            activeLines = LineSplitter.split(activeM3u8Content).toList();
            activeBasePath = nextUrl.substring(0, nextUrl.lastIndexOf('/') + 1);
          }
        }

        segmentUrls = [];
        for (var line in activeLines) {
          line = line.trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          
          final String segmentUrl;
          if (line.startsWith('http://') || line.startsWith('https://')) {
            segmentUrl = line;
          } else {
            segmentUrl = activeBasePath + line;
          }
          
          // Skip known ad/tracking domains that could fail or cause timeouts
          if (segmentUrl.contains('doubleclick') ||
              segmentUrl.contains('adsystem') ||
              segmentUrl.contains('googleads') ||
              segmentUrl.contains('analytics')) {
            continue;
          }
          segmentUrls.add(segmentUrl);
        }
        debugPrint('[DownloadService] Parsed ${segmentUrls.length} HLS segments.');
      }

      // Step 2: Pre-flight check (only for direct non-HLS streams)
      int serverResponseTimeMs = 0;
      int totalSize = 0;
      bool rangeSupported = false;

      if (!isHls) {
        try {
          final stopwatch = Stopwatch()..start();
          final response = await _dio.get(
            downloadUrl,
            options: Options(
              headers: {...headers, 'Range': 'bytes=0-0'},
            ),
          );
          stopwatch.stop();
          serverResponseTimeMs = stopwatch.elapsedMilliseconds;
          debugPrint('[DownloadService] Server latency: $serverResponseTimeMs ms');

          final acceptRanges = response.headers.value('accept-ranges');
          final contentRange = response.headers.value('content-range');
          rangeSupported = acceptRanges == 'bytes' || contentRange != null;

          if (contentRange != null) {
            final parts = contentRange.split('/');
            if (parts.length > 1) {
              totalSize = int.tryParse(parts[1]) ?? 0;
            }
          }
          if (totalSize <= 0) {
            totalSize = int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
          }
        } catch (e) {
          debugPrint('[DownloadService] Pre-flight failed: $e. Falling back to single stream.');
        }
      }

      item.totalSize = totalSize;
      _updateItemInList(item);

      final int numChunks = 8;
      if (isHls || (rangeSupported && totalSize > 10 * 1024 * 1024)) {
        debugPrint('[DownloadService] Spawning background Isolate for download');

        final receivePort = ReceivePort();
        final bgParams = _BgDownloadParams(
          sendPort: receivePort.sendPort,
          downloadUrl: downloadUrl,
          filePath: filePath,
          headers: headers,
          totalSize: totalSize,
          numChunks: numChunks,
          segmentUrls: segmentUrls,
          is2Embed: item.quality.toLowerCase().contains('2embed') || 
                    cleanUrl.contains('lookmovie') || 
                    cleanUrl.contains('korso420dim.com') || 
                    cleanUrl.contains('tiktokcdn.com') ||
                    item.movieBoxSubjectId == '2embed',
        );

        final isolate = await Isolate.spawn(_backgroundDownloadEntry, bgParams);
        _activeIsolates[item.title] = isolate;

        dynamic finalResult;
        final completer = Completer<dynamic>();

        receivePort.listen((message) async {
          if (message is Map) {
            final type = message['type'];
            if (type == 'progress') {
              final downloaded = message['downloaded'] as int;
              item.downloadedSize = downloaded;

              if (message.containsKey('completed') && isHls) {
                final completed = message['completed'] as int;
                final total = message['total'] as int;
                item.progress = (completed / total).clamp(0.0, 1.0);
              } else {
                item.progress = (downloaded / totalSize).clamp(0.0, 1.0);
              }
              _updateItemInList(item);
            } else if (type == 'telemetry') {
              final telemetry = message['telemetry'] as String;
              final match = RegExp(r'Speed: (.+)').firstMatch(telemetry);
              if (match != null) {
                item.speed = match.group(1)!;
              }
              _showSystemNotification(
                item.title.hashCode,
                'Downloading ${item.title}',
                telemetry.replaceAll('\n', ' • '),
                progress: (item.progress * 100).toInt(),
              );
            } else if (type == 'success') {
              receivePort.close();
              _activeIsolates.remove(item.title);
              completer.complete(message);
            } else if (type == 'error') {
              receivePort.close();
              _activeIsolates.remove(item.title);
              completer.completeError(Exception(message['message']));
            }
          }
        });

        finalResult = await completer.future;

        if (item.status != 'paused') {
          item.status = 'saving';
          _updateItemInList(item);

          final avgSpeed = finalResult['avgSpeed'] as double;
          final peakSpeed = finalResult['peakSpeed'] as int;
          final failures = finalResult['failures'] as int;
          final avgSpeedText = avgSpeed >= 1048576 ? '${(avgSpeed / 1048576).toStringAsFixed(1)} MB/s' : '${(avgSpeed / 1024).toStringAsFixed(0)} KB/s';
          final peakSpeedText = peakSpeed >= 1048576 ? '${(peakSpeed / 1048576).toStringAsFixed(1)} MB/s' : '${(peakSpeed / 1024).toStringAsFixed(0)} KB/s';

          debugPrint('====================================');
          debugPrint('       DOWNLOAD BENCHMARK REPORT     ');
          debugPrint('====================================');
          debugPrint('Average Speed: $avgSpeedText');
          debugPrint('Peak Speed: $peakSpeedText');
          debugPrint('Server Latency: $serverResponseTimeMs ms');
          debugPrint('Chunk Failures: $failures');
          debugPrint('====================================');

          final isFinishedHls = finalResult['isHls'] == true;
          final totalSegments = finalResult.containsKey('totalSegments') ? finalResult['totalSegments'] as int : 0;

          if (isFinishedHls) {
            // Merge HLS segments sequentially
            final finalFile = File(filePath);
            if (await finalFile.exists()) {
              await finalFile.delete();
            }
            final finalSink = finalFile.openWrite();
            for (int i = 0; i < totalSegments; i++) {
              final partFile = File('$filePath.part_$i');
              if (await partFile.exists()) {
                await finalSink.addStream(partFile.openRead());
                await partFile.delete();
              }
            }
            await finalSink.close();
          } else {
            // Merge chunks sequentially
            final finalFile = File(filePath);
            if (await finalFile.exists()) {
              await finalFile.delete();
            }
            final finalSink = finalFile.openWrite();
            for (int i = 0; i < numChunks; i++) {
              final chunkFile = File('$filePath.chunk_$i');
              if (await chunkFile.exists()) {
                await finalSink.addStream(chunkFile.openRead());
                await chunkFile.delete();
              }
            }
            await finalSink.close();
          }

          item.status = 'completed';
          item.done = true;
          item.failed = false;
          item.localPath = filePath;
          item.speed = '';
          _updateItemInList(item);

          notificationNotifier.value = DownloadNotification(
            title: item.title,
            type: DownloadNotificationType.completed,
            message: 'Download completed: "${item.title}" is ready to play!',
          );
          _showSystemNotification(
            item.title.hashCode,
            item.title,
            'Download completed! Ready to play.',
          );

          await _saveDownloads();
          _processNextQueue();
        }
      } else {
        // Fallback: Single stream download
        final file = File(filePath);
        int downloadedBytes = 0;
        if (await file.exists()) {
          downloadedBytes = await file.length();
        }

        final singleHeaders = Map<String, String>.from(headers);
        if (downloadedBytes > 0) {
          singleHeaders['Range'] = 'bytes=$downloadedBytes-';
        }

        final response = await _dio.get<ResponseBody>(
          downloadUrl,
          options: Options(
            headers: singleHeaders,
            responseType: ResponseType.stream,
          ),
        );

        final fileMode = downloadedBytes > 0 ? FileMode.append : FileMode.write;
        final fileSink = file.openWrite(mode: fileMode);

        if (totalSize <= 0) {
          totalSize = (int.tryParse(response.headers.value('content-length') ?? '0') ?? 0) + downloadedBytes;
          item.totalSize = totalSize;
        }

        int received = downloadedBytes;
        DateTime lastUpdate = DateTime.now();
        int lastBytes = downloadedBytes;

        await for (final chunk in response.data!.stream) {
          if (item.status == 'paused') {
            break;
          }
          fileSink.add(chunk);
          received += chunk.length;

          final now = DateTime.now();
          final elapsedMs = now.difference(lastUpdate).inMilliseconds;
          if (elapsedMs > 800) {
            final bytesSec = (received - lastBytes) / (elapsedMs / 1000);
            if (bytesSec >= 1048576) {
              item.speed = '${(bytesSec / 1048576).toStringAsFixed(1)} MB/s';
            } else {
              item.speed = '${(bytesSec / 1024).toStringAsFixed(0)} KB/s';
            }
            lastUpdate = now;
            lastBytes = received;

            _showSystemNotification(
              item.title.hashCode,
              'Downloading ${item.title}',
              '${item.speed} • ${(item.progress * 100).toStringAsFixed(0)}% (Latency: ${serverResponseTimeMs}ms, Conns: 1)',
              progress: (item.progress * 100).toInt(),
            );
            debugPrint('[DownloadService] Speed: ${item.speed} | Latency: ${serverResponseTimeMs}ms | Active Conns: 1');
          }

          item.progress = (received / totalSize).clamp(0.0, 1.0);
          item.downloadedSize = received;
          _updateItemInList(item);
        }

        await fileSink.close();

        if (item.status != 'paused') {
          item.status = 'completed';
          item.done = true;
          item.failed = false;
          item.localPath = filePath;
          item.speed = '';
          _updateItemInList(item);

          notificationNotifier.value = DownloadNotification(
            title: item.title,
            type: DownloadNotificationType.completed,
            message: 'Download completed: "${item.title}" is ready to play!',
          );
          _showSystemNotification(
            item.title.hashCode,
            item.title,
            'Download completed! Ready to play.',
          );

          await _saveDownloads();
          _processNextQueue();
        }
      }

    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || e.message == 'paused') {
        return;
      }
      debugPrint('[Download] Error: $e');
      notificationNotifier.value = DownloadNotification(
        title: item.title,
        type: DownloadNotificationType.failed,
        message: 'Download failed: "${item.title}"',
      );
      _showSystemNotification(
        item.title.hashCode,
        item.title,
        'Download failed.',
      );

      _markFailed(item);
      await _saveDownloads();
      _processNextQueue();
    } catch (e) {
      debugPrint('[Download] Unexpected error: $e');
      notificationNotifier.value = DownloadNotification(
        title: item.title,
        type: DownloadNotificationType.failed,
        message: 'Download failed: "${item.title}"',
      );
      _showSystemNotification(
        item.title.hashCode,
        item.title,
        'Download failed.',
      );

      _markFailed(item);
      await _saveDownloads();
      _processNextQueue();
    }
  }

  void handleWebViewMessage(String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      final active = activeTorrentDownload.value;
      if (active == null) return;

      switch (type) {
        case 'phase':
          final phase = data['phase'];
          if (phase == 'saving') {
            active.item.status = 'saving';
          } else if (phase == 'connecting') {
            active.item.status = 'connecting';
          }
          _updateItemInList(active.item);
          break;

        case 'download_started':
          final size = data['size'] ?? 0;
          active.item.totalSize = size;
          active.item.status = 'downloading';
          _updateItemInList(active.item);
          notificationNotifier.value = DownloadNotification(
            title: active.item.title,
            type: DownloadNotificationType.started,
            message: 'Downloading "${active.item.title}" started...',
          );
          _showSystemNotification(
            active.item.title.hashCode,
            'Downloading ${active.item.title}',
            'Connecting...',
            progress: 0,
          );
          break;

        case 'progress':
          final pct = (data['progress'] ?? 0.0).toDouble();
          final speed = data['speed'] ?? 0;
          final peers = data['peers'] ?? 0;
          final downloaded = data['downloaded'] ?? 0;
          final total = data['total'] ?? active.item.totalSize;

          active.item.progress = (pct / 100).clamp(0.0, 1.0);
          active.item.peers = peers;
          active.item.downloadedSize = downloaded;
          active.item.totalSize = total;

          if (speed >= 1048576) {
            active.item.speed = '${(speed / 1048576).toStringAsFixed(1)} MB/s';
          } else {
            active.item.speed = '${(speed / 1024).toStringAsFixed(0)} KB/s';
          }
          _updateItemInList(active.item);

          final now = DateTime.now().millisecondsSinceEpoch;
          final lastTime = _lastNotificationTimes[active.item.title] ?? 0;
          if (now - lastTime > 1000) {
            _lastNotificationTimes[active.item.title] = now;
            _showSystemNotification(
              active.item.title.hashCode,
              'Downloading ${active.item.title}',
              '${active.item.speed} • ${(active.item.progress * 100).toStringAsFixed(0)}%',
              progress: (active.item.progress * 100).toInt(),
            );
          }
          break;

        case 'save_start':
          final name = data['name'];
          final size = data['size'] ?? active.item.totalSize;
          active.item.status = 'saving';
          active.item.totalSize = size;
          _updateItemInList(active.item);
          _initFileForWriting(active, name);
          break;

        case 'save_chunk':
          final b64 = data['data'];
          final bytes = base64Decode(b64);
          if (active.fileHandle != null) {
            active.fileHandle!.writeAsBytesSync(bytes, mode: FileMode.append);
          }
          break;

        case 'save_done':
          active.item.status = 'completed';
          active.item.done = true;
          active.item.failed = false;
          active.item.progress = 1.0;
          active.item.speed = '';
          active.item.peers = 0;
          _updateItemInList(active.item);

          notificationNotifier.value = DownloadNotification(
            title: active.item.title,
            type: DownloadNotificationType.completed,
            message: 'Download completed: "${active.item.title}" is ready to play!',
          );
          _showSystemNotification(
            active.item.title.hashCode,
            active.item.title,
            'Download completed! Ready to play.',
          );

          activeTorrentDownload.value = null;
          _saveDownloads();
          _processNextQueue();
          break;

        case 'error':
          final errMsg = data['message'] ?? 'WebTorrent error';
          debugPrint('[DownloadService] Torrent error: $errMsg');
          notificationNotifier.value = DownloadNotification(
            title: active.item.title,
            type: DownloadNotificationType.failed,
            message: 'Download failed: "${active.item.title}"',
          );
          _showSystemNotification(
            active.item.title.hashCode,
            active.item.title,
            'Download failed.',
          );
          _markFailed(active.item);
          activeTorrentDownload.value = null;
          _saveDownloads();
          _processNextQueue();
          break;

      }
    } catch (e) {
      debugPrint('[DownloadService] Parse error: $e');
    }
  }

  Future<void> _initFileForWriting(ActiveTorrentDownload active, String torrentFileName) async {
    try {
      final dirPath = await _getDownloadDir();
      final safeTitle = active.item.title.replaceAll(RegExp(r'[^\w\s]'), '').trim();
      final ext = torrentFileName.split('.').last;
      final fileExt = ext.length > 4 || ext.isEmpty ? 'mp4' : ext;
      final filePath = '$dirPath/$safeTitle.$fileExt';

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      await file.create(recursive: true);
      active.fileHandle = file;
      active.item.localPath = filePath;
      _updateItemInList(active.item);
    } catch (e) {
      debugPrint('[DownloadService] File init error: $e');
    }
  }

  void _updateItemInList(DownloadItem item) {
    final idx = downloadsNotifier.value.indexWhere((e) => e.title == item.title);
    if (idx == -1) return;
    final list = List<DownloadItem>.from(downloadsNotifier.value);
    list[idx] = item;
    downloadsNotifier.value = list;
  }

  void _markFailed(DownloadItem item) {
    item.failed = true;
    item.status = 'failed';
    item.speed = '';
    item.peers = 0;
    _updateItemInList(item);
  }

  Future<void> _startNativeTorrentDownload(DownloadItem item, String magnetUri) async {
    final bool isDesktop = defaultTargetPlatform == TargetPlatform.windows || 
        defaultTargetPlatform == TargetPlatform.macOS || 
        defaultTargetPlatform == TargetPlatform.linux;

    if (kIsWeb || isDesktop) {
      try {
        await launchUrl(Uri.parse(magnetUri), mode: LaunchMode.externalApplication);
        item.status = 'completed';
        item.done = true;
        item.failed = false;
        item.progress = 1.0;
        _updateItemInList(item);
      } catch (e) {
        item.status = 'failed';
        item.failed = true;
        _updateItemInList(item);
      }
      activeTorrentDownload.value = null;
      await _saveDownloads();
      _processNextQueue();
      return;
    }
    try {
      final dirPath = await _getDownloadDir();
      await TorrentService.startTorrent(magnetUri, savePath: dirPath);

      item.status = 'connecting';
      _updateItemInList(item);

      notificationNotifier.value = DownloadNotification(
        title: item.title,
        type: DownloadNotificationType.started,
        message: 'Downloading "${item.title}" started...',
      );
      _showSystemNotification(
        item.title.hashCode,
        'Downloading ${item.title}',
        'Connecting...',
        progress: 0,
      );

      int lastNotificationTime = 0;

      _torrentSubscription?.cancel();
      _torrentSubscription = TorrentService.statusStream.listen((status) async {
        if (activeTorrentDownload.value?.item.title != item.title) {
          _torrentSubscription?.cancel();
          return;
        }

        if (status.isValid) {
          item.status = status.progress >= 1.0 ? 'completed' : 'downloading';
          item.progress = status.progress;
          item.peers = status.peers;
          
          item.speed = status.downloadSpeed >= 1048576 
              ? '${(status.downloadSpeed / 1048576).toStringAsFixed(1)} MB/s'
              : '${(status.downloadSpeed / 1024).toStringAsFixed(0)} KB/s';
          
          if (status.filePath != null) {
            item.localPath = status.filePath;
          }

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastNotificationTime > 1000) {
            lastNotificationTime = now;
            _showSystemNotification(
              item.title.hashCode,
              'Downloading ${item.title}',
              '${item.speed} • ${(item.progress * 100).toStringAsFixed(0)}%',
              progress: (item.progress * 100).toInt(),
            );
          }

          if (status.progress >= 1.0 || status.state == 'FINISHED' || status.state == 'SEEDING') {
            item.status = 'completed';
            item.done = true;
            item.progress = 1.0;
            item.speed = '';
            item.peers = 0;
            _updateItemInList(item);
            
            notificationNotifier.value = DownloadNotification(
              title: item.title,
              type: DownloadNotificationType.completed,
              message: 'Download completed: "${item.title}" is ready to play!',
            );
            _showSystemNotification(
              item.title.hashCode,
              item.title,
              'Download completed! Ready to play.',
            );

            _torrentSubscription?.cancel();
            activeTorrentDownload.value = null;
            await _saveDownloads();
            _processNextQueue();
          } else {
            _updateItemInList(item);
          }
        }
      }, onError: (err) {
        debugPrint('[DownloadService] Native download error: $err');
        notificationNotifier.value = DownloadNotification(
          title: item.title,
          type: DownloadNotificationType.failed,
          message: 'Download failed: "${item.title}"',
        );
        _showSystemNotification(
          item.title.hashCode,
          item.title,
          'Download failed.',
        );
        _markFailed(item);
        activeTorrentDownload.value = null;
        _torrentSubscription?.cancel();
        _saveDownloads();
        _processNextQueue();
      });
    } catch (e) {
      debugPrint('[DownloadService] Native start error: $e');
      notificationNotifier.value = DownloadNotification(
        title: item.title,
        type: DownloadNotificationType.failed,
        message: 'Download failed: "${item.title}"',
      );
      _showSystemNotification(
        item.title.hashCode,
        item.title,
        'Download failed.',
      );
      _markFailed(item);
      activeTorrentDownload.value = null;
      _saveDownloads();
      _processNextQueue();
    }

  }

  void cancelDownload(String title) {
    final idx = downloadsNotifier.value.indexWhere((e) => e.title == title);
    if (idx == -1) return;

    final item = downloadsNotifier.value[idx];
    item.cancelToken?.cancel();

    // Kill background download isolate if active
    final isolate = _activeIsolates.remove(title);
    if (isolate != null) {
      isolate.kill(priority: Isolate.beforeNextEvent);
    }

    final active = activeTorrentDownload.value;
    if (active != null && active.item.title == title) {
      _torrentSubscription?.cancel();
      TorrentService.stopTorrent();
      activeTorrentDownload.value = null;
    }

    removeDownload(title);
  }

  Future<void> removeDownload(String title) async {
    final idx = downloadsNotifier.value.indexWhere((e) => e.title == title);
    if (idx == -1) return;

    final item = downloadsNotifier.value[idx];
    if (!kIsWeb && item.localPath != null) {
      try {
        final file = File(item.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
        // Cleanup chunk files if download was interrupted
        for (int i = 0; i < 8; i++) {
          final chunkFile = File('${item.localPath!}.chunk_$i');
          if (await chunkFile.exists()) {
            await chunkFile.delete();
          }
        }
      } catch (e) {
        debugPrint('[DownloadService] Error deleting local file: $e');
      }
    }

    downloadsNotifier.value = downloadsNotifier.value.where((e) => e.title != title).toList();
    await _saveDownloads();
    _processNextQueue();
  }
}

class _BgDownloadParams {
  final SendPort sendPort;
  final String downloadUrl;
  final String filePath;
  final Map<String, String> headers;
  final int totalSize;
  final int numChunks;
  final List<String>? segmentUrls;
  final bool is2Embed;

  _BgDownloadParams({
    required this.sendPort,
    required this.downloadUrl,
    required this.filePath,
    required this.headers,
    required this.totalSize,
    required this.numChunks,
    this.segmentUrls,
    required this.is2Embed,
  });
}

class ChunkTask {
  final int id;
  int start;
  int end;
  int downloaded;
  int lastDownloaded;
  int speedBytesSec;
  int consecutiveSlowSeconds;
  int retries;
  bool isFinished;
  CancelToken? cancelToken;

  ChunkTask({
    required this.id,
    required this.start,
    required this.end,
  })  : downloaded = 0,
        lastDownloaded = 0,
        speedBytesSec = 0,
        consecutiveSlowSeconds = 0,
        retries = 0,
        isFinished = false;
}

void _backgroundDownloadEntry(_BgDownloadParams params) async {
  final dio = Dio();
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.maxConnectionsPerHost = 64;
      return client;
    },
  );

  if (params.segmentUrls != null) {
    final segmentUrls = params.segmentUrls!;
    if (segmentUrls.isEmpty) {
      params.sendPort.send({
        'type': 'error',
        'message': 'No HLS segments found in stream playlist.',
      });
      return;
    }
    final int totalSegments = segmentUrls.length;
    int nextSegmentIndex = 0;
    int completedSegments = 0;

    final stopwatch = Stopwatch()..start();
    int peakSpeedBytesSec = 0;
    int chunkFailures = 0;

    final List<int> segmentDownloadedBytes = List.filled(totalSegments, 0);
    final List<int> segmentLastDownloaded = List.filled(totalSegments, 0);

    Timer? monitorTimer;
    monitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int totalSpeed = 0;
      for (int i = 0; i < totalSegments; i++) {
        final diff = segmentDownloadedBytes[i] - segmentLastDownloaded[i];
        segmentLastDownloaded[i] = segmentDownloadedBytes[i];
        totalSpeed += diff;
      }
      if (totalSpeed > peakSpeedBytesSec) {
        peakSpeedBytesSec = totalSpeed;
      }

      final speedText = totalSpeed >= 1048576
          ? '${(totalSpeed / 1048576).toStringAsFixed(1)} MB/s'
          : '${(totalSpeed / 1024).toStringAsFixed(0)} KB/s';

      params.sendPort.send({
        'type': 'telemetry',
        'telemetry': 'HLS Download: $completedSegments / $totalSegments segments done\nSpeed: $speedText',
      });
    });

    Future<void> downloadSegment(int index) async {
      final url = segmentUrls[index];
      final partPath = '${params.filePath}.part_$index';
      final partFile = File(partPath);

      var targetUrl = url;
      if (params.is2Embed) {
        final bool isTikTok = url.contains('tiktokcdn.com');
        if (isTikTok) {
          targetUrl = 'https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(url)}';
        }
      }

      final Map<String, String> requestHeaders = Map<String, String>.from(params.headers);
      if (params.is2Embed || 
          url.contains('tiktokcdn.com') || 
          url.contains('lookmovie') || 
          url.contains('korso420dim.com') ||
          params.downloadUrl.contains('lookmovie') ||
          params.downloadUrl.contains('korso420dim.com') ||
          params.downloadUrl.contains('2embed')) {
        requestHeaders['Referer'] = 'https://gemma416okl.com';
        requestHeaders['Origin'] = 'https://gemma416okl.com';
        requestHeaders['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      }

      int retries = 0;
      while (retries < 3) {
        try {
          final response = await dio.get<ResponseBody>(
            targetUrl,
            options: Options(
              headers: requestHeaders,
              responseType: ResponseType.stream,
            ),
          );

          final sink = partFile.openWrite();
          int segmentBytes = 0;
          await for (final block in response.data!.stream) {
            sink.add(block);
            segmentBytes += block.length;
            segmentDownloadedBytes[index] = segmentBytes;

            int totalDownloaded = segmentDownloadedBytes.isEmpty ? 0 : segmentDownloadedBytes.reduce((v, e) => v + e);
            params.sendPort.send({
              'type': 'progress',
              'downloaded': totalDownloaded,
              'completed': completedSegments,
              'total': totalSegments,
            });
          }
          await sink.close();
          completedSegments++;
          break;
        } catch (e) {
          chunkFailures++;
          retries++;
          if (retries >= 3) {
            // Log the failure and proceed with other segments rather than failing the entire download
            print('[DownloadService] Warning: Segment $index failed after 3 retries, skipping it. Error: $e');
            completedSegments++;
            break;
          }
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    final List<Future<void>> workers = [];
    final int maxConcurrentWorkers = 32;
    for (int i = 0; i < maxConcurrentWorkers; i++) {
      final w = () async {
        while (nextSegmentIndex < totalSegments) {
          final idx = nextSegmentIndex++;
          await downloadSegment(idx);
        }
      }();
      workers.add(w);
    }

    try {
      await Future.wait(workers);
      monitorTimer.cancel();
      stopwatch.stop();

      final elapsedSecs = stopwatch.elapsedMilliseconds / 1000;
      final totalSize = segmentDownloadedBytes.isEmpty ? 0 : segmentDownloadedBytes.reduce((v, e) => v + e);
      final avgSpeed = totalSize / (elapsedSecs > 0 ? elapsedSecs : 1);

      params.sendPort.send({
        'type': 'success',
        'avgSpeed': avgSpeed,
        'peakSpeed': peakSpeedBytesSec,
        'failures': chunkFailures,
        'isHls': true,
        'totalSegments': totalSegments,
      });
    } catch (e) {
      monitorTimer.cancel();
      params.sendPort.send({
        'type': 'error',
        'message': e.toString(),
      });
    }
    return;
  }

  final int numChunks = params.numChunks;
  final int chunkSize = (params.totalSize / numChunks).floor();

  final List<ChunkTask> tasks = List.generate(numChunks, (i) {
    final start = i * chunkSize;
    final end = (i == numChunks - 1) ? params.totalSize - 1 : (start + chunkSize - 1);
    return ChunkTask(id: i, start: start, end: end);
  });

  final stopwatch = Stopwatch()..start();
  int peakSpeedBytesSec = 0;
  int chunkFailures = 0;
  int timerTicks = 0; // track elapsed seconds for warmup

  Timer? monitorTimer;
  monitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    timerTicks++;
    int totalSpeed = 0;
    final List<String> telemetryStrings = [];


    for (var task in tasks) {
      if (task.isFinished) {
        task.speedBytesSec = 0;
        telemetryStrings.add('Chunk #${task.id + 1} = Finished');
        continue;
      }

      final diff = task.downloaded - task.lastDownloaded;
      task.lastDownloaded = task.downloaded;
      task.speedBytesSec = diff;
      totalSpeed += diff;

      final speedText = task.speedBytesSec >= 1048576
          ? '${(task.speedBytesSec / 1048576).toStringAsFixed(1)} MB/s'
          : '${(task.speedBytesSec / 1024).toStringAsFixed(0)} KB/s';
      telemetryStrings.add('Chunk #${task.id + 1} = $speedText');

      // Only flag as stalled after 30s warmup (allow server time to ramp up)
      // and only when chunk has downloaded some data but speed dropped to near zero
      final bool warmupDone = timerTicks > 30;
      if (warmupDone && task.downloaded > 0 && task.speedBytesSec < 100 * 1024) {
        task.consecutiveSlowSeconds++;
        if (task.consecutiveSlowSeconds >= 60) {
          task.consecutiveSlowSeconds = 0;
          debugPrint('[DownloadService] Stalled chunk #${task.id + 1} detected (>60s below 100KB/s). Restarting...');
          task.cancelToken?.cancel('slow');
        }
      } else {
        task.consecutiveSlowSeconds = 0;
      }
    }

    if (totalSpeed > peakSpeedBytesSec) {
      peakSpeedBytesSec = totalSpeed;
    }

    params.sendPort.send({
      'type': 'telemetry',
      'telemetry': telemetryStrings.join('\n'),
    });
  });

  Future<void> downloadChunk(ChunkTask task) async {
    while (task.start + task.downloaded < task.end) {
      task.cancelToken = CancelToken();
      final chunkPath = '${params.filePath}.chunk_${task.id}';
      final chunkFile = File(chunkPath);

      int chunkExistingBytes = 0;
      if (await chunkFile.exists()) {
        chunkExistingBytes = await chunkFile.length();
      }
      task.downloaded = chunkExistingBytes;
      task.lastDownloaded = chunkExistingBytes;

      final currentStart = task.start + chunkExistingBytes;
      if (currentStart >= task.end) {
        task.isFinished = true;
        break;
      }

      final headers = Map<String, String>.from(params.headers);
      headers['Range'] = 'bytes=$currentStart-${task.end}';

      try {
        final response = await dio.get<ResponseBody>(
          params.downloadUrl,
          options: Options(
            headers: headers,
            responseType: ResponseType.stream,
          ),
          cancelToken: task.cancelToken,
        );

        final mode = chunkExistingBytes > 0 ? FileMode.append : FileMode.write;
        final sink = chunkFile.openWrite(mode: mode);

        await for (final block in response.data!.stream) {
          sink.add(block);
          chunkExistingBytes += block.length;
          task.downloaded = chunkExistingBytes;

          int totalDownloaded = tasks.fold(0, (sum, t) => sum + t.downloaded);
          params.sendPort.send({
            'type': 'progress',
            'downloaded': totalDownloaded,
          });
        }
        await sink.close();
        task.isFinished = true;
        break;
      } catch (e) {
        chunkFailures++;
        task.retries++;
        if (task.retries >= 3) {
          throw Exception('Chunk #${task.id + 1} failed after 3 retries. Error: $e');
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    task.isFinished = true;

    // Work stealing
    ChunkTask? busiest;
    int maxRemaining = 0;
    for (var t in tasks) {
      if (!t.isFinished) {
        final remaining = t.end - (t.start + t.downloaded);
        if (remaining > maxRemaining) {
          maxRemaining = remaining;
          busiest = t;
        }
      }
    }

    if (busiest != null && maxRemaining > 5 * 1024 * 1024) {
      final mid = busiest.start + busiest.downloaded + (maxRemaining / 2).floor();
      debugPrint('[DownloadService] Idle chunk #${task.id + 1} stealing range from chunk #${busiest.id + 1}');

      final oldEnd = busiest.end;
      busiest.end = mid;

      task.start = mid + 1;
      task.end = oldEnd;
      task.downloaded = 0;
      task.lastDownloaded = 0;
      task.isFinished = false;
      task.retries = 0;

      downloadChunk(task);
    }
  }

  final List<Future<void>> futures = tasks.map((t) => downloadChunk(t)).toList();

  try {
    await Future.wait(futures);
    monitorTimer.cancel();
    stopwatch.stop();

    final elapsedSecs = stopwatch.elapsedMilliseconds / 1000;
    final avgSpeedBytesSec = params.totalSize / (elapsedSecs > 0 ? elapsedSecs : 1);

    params.sendPort.send({
      'type': 'success',
      'avgSpeed': avgSpeedBytesSec,
      'peakSpeed': peakSpeedBytesSec,
      'failures': chunkFailures,
    });
  } catch (e) {
    monitorTimer.cancel();
    params.sendPort.send({
      'type': 'error',
      'message': e.toString(),
    });
  }
}
