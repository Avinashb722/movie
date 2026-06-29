import 'dart:async';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
//  TorrentStatus — immutable snapshot of native engine state
// ---------------------------------------------------------------------------
class TorrentStatus {
  final String name;
  final double progress;         // 0.0 – 1.0
  final double downloadSpeed;    // bytes/sec
  final double uploadSpeed;      // bytes/sec
  final int peers;
  final String? filePath;
  final String? fileName;
  final String state;
  final bool isValid;
  final int totalDone;           // bytes downloaded so far
  final int videoFileSize;       // total size of the target video file
  final bool selectedVideoIsMP4; // true = MP4/M4V/WebM (fast start), false = MKV (needs more buffer)

  const TorrentStatus({
    required this.name,
    required this.progress,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.peers,
    this.filePath,
    this.fileName,
    required this.state,
    required this.isValid,
    required this.totalDone,
    required this.videoFileSize,
    this.selectedVideoIsMP4 = false,
  });

  factory TorrentStatus.fromMap(Map<dynamic, dynamic> map) {
    return TorrentStatus(
      name:               map['name'] as String? ?? '',
      progress:           (map['progress'] as num?)?.toDouble() ?? 0.0,
      downloadSpeed:      (map['downloadSpeed'] as num?)?.toDouble() ?? 0.0,
      uploadSpeed:        (map['uploadSpeed'] as num?)?.toDouble() ?? 0.0,
      peers:              map['peers'] as int? ?? 0,
      filePath:           map['filePath'] as String?,
      fileName:           map['fileName'] as String?,
      state:              map['state'] as String? ?? 'UNKNOWN',
      isValid:            map['isValid'] as bool? ?? false,
      totalDone:          (map['totalDone'] as num?)?.toInt() ?? 0,
      videoFileSize:      (map['videoFileSize'] as num?)?.toInt() ?? 0,
      selectedVideoIsMP4: map['selectedVideoIsMP4'] as bool? ?? false,
    );
  }

  /// Safe "nothing happening" status
  static const TorrentStatus idle = TorrentStatus(
    name: '', progress: 0.0, downloadSpeed: 0.0, uploadSpeed: 0.0,
    peers: 0, state: 'idle', isValid: false,
    totalDone: 0, videoFileSize: 0,
  );

  static const TorrentStatus pending = TorrentStatus(
    name: '', progress: 0.0, downloadSpeed: 0.0, uploadSpeed: 0.0,
    peers: 0, state: 'metadata_pending', isValid: false,
    totalDone: 0, videoFileSize: 0,
  );

  /// Returns true when basic download thresholds are met for the format:
  ///   • MP4/M4V/WebM : first 20 MB downloaded
  ///   • MKV           : first 100 MB downloaded
  ///   Also requires state = DOWNLOADING / FINISHED / SEEDING.
  bool get isPlaybackThresholdMet {
    if (!isValid) return false;
    if (filePath == null) return false;
    final upperState = state.toUpperCase();
    if (upperState != 'DOWNLOADING' &&
        upperState != 'FINISHED' &&
        upperState != 'SEEDING') {
      return false;
    }
    if (totalDone <= 0) return false;

    final isMkv = filePath!.toLowerCase().endsWith('.mkv');
    // Per-format minimum bytes before attempting readiness check
    final minBytes = isMkv ? 100 * 1024 * 1024 : 20 * 1024 * 1024;
    return totalDone >= minBytes;
  }

  bool get isMetadataPending =>
      state == 'metadata_pending' || state == 'idle' || state == 'UNKNOWN';
}

// ---------------------------------------------------------------------------
//  TorrentService — singleton wrapper around the native MethodChannel
// ---------------------------------------------------------------------------
class TorrentService {
  static const MethodChannel _channel =
      MethodChannel('com.example.flixo_app/torrent');

  static Timer? _pollTimer;
  static Timer? _metadataWaitTimer;

  static final StreamController<TorrentStatus> _statusController =
      StreamController<TorrentStatus>.broadcast();

  /// Whether a torrent is currently active — used to hard-stop all timers.
  static bool _isActive = false;

  static Stream<TorrentStatus> get statusStream => _statusController.stream;

  // -------------------------------------------------------------------------
  //  Public API
  // -------------------------------------------------------------------------

  static Future<void> startTorrent(String magnetUri, {String? savePath}) async {
    _cancelTimers();
    _isActive = true;

    await _channel.invokeMethod('startTorrent', {
      'magnetUri': magnetUri,
      if (savePath != null) 'savePath': savePath,
    });

    // Emit pending immediately so UI shows the loading overlay
    if (!_statusController.isClosed) {
      _statusController.add(TorrentStatus.pending);
    }

    _waitForMetadataThenPoll();
  }

  static Future<void> stopTorrent() async {
    // Set flag FIRST so all in-flight async callbacks see it
    _isActive = false;
    _cancelTimers();
    try {
      await _channel.invokeMethod('stopTorrent');
    } catch (_) {}
  }

  /// Direct one-shot query — used internally; callers should prefer statusStream.
  static Future<TorrentStatus> getStatus() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('getStatus');
      if (result == null) return TorrentStatus.idle;
      return TorrentStatus.fromMap(result);
    } catch (_) {
      return TorrentStatus.idle;
    }
  }

  /// Verification call to check if the file size on disk is ready (>= 200MB / 400MB)
  static Future<String> verifyFileReady(String filePath) async {
    try {
      final String? result = await _channel.invokeMethod('verifyFileReady', {
        'filePath': filePath,
      });
      return result ?? 'NOT_READY';
    } catch (_) {
      return 'NOT_READY';
    }
  }

  // -------------------------------------------------------------------------
  //  Internal
  // -------------------------------------------------------------------------

  static void _cancelTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _metadataWaitTimer?.cancel();
    _metadataWaitTimer = null;
  }

  /// Polls `isMetadataReceived` every 500 ms until native engine confirms
  /// metadata is ready, then switches to the 1-second status polling loop.
  /// This prevents getStatus() being called while the native handle is unsafe.
  static void _waitForMetadataThenPoll() {
    _metadataWaitTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isActive) {
        timer.cancel();
        return;
      }
      try {
        final bool ready =
            await _channel.invokeMethod('isMetadataReceived') as bool? ?? false;
        if (ready) {
          timer.cancel();
          _metadataWaitTimer = null;
          if (_isActive) _startPolling();
        }
      } catch (_) {
        // Keep retrying until metadata arrives or we are stopped
      }
    });
  }

  static void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      // Hard stop: _isActive was set to false by stopTorrent()
      if (!_isActive) {
        timer.cancel();
        return;
      }
      try {
        final status = await getStatus();
        if (!_isActive) return; // re-check after the async gap
        if (!_statusController.isClosed) {
          _statusController.add(status);
        }
      } catch (_) {
        // Ignore transient channel errors
      }
    });
  }
}
