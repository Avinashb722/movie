import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player_plus/better_player_plus.dart';
import '../services/torrent_service.dart';
import '../theme/app_theme.dart';

class StreamScreen extends StatefulWidget {
  final String magnetLink;
  final String title;

  const StreamScreen({
    super.key,
    required this.magnetLink,
    required this.title,
  });

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  BetterPlayerController? _betterPlayerController;
  StreamSubscription<TorrentStatus>? _statusSubscription;

  bool _loading = true;
  bool _playerInitializing = false; // guard against concurrent init attempts
  bool _playbackAttempted = false;  // ensure ExoPlayer initializes only once
  String _status = 'Connecting to peers…';
  double _progress = 0;
  String _speed = '0 KB/s';
  String _peers = '0';
  String _downloaded = '0 MB';
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _forceLandscape();

    final magnet = widget.magnetLink.trim();
    if (magnet.isEmpty) {
      debugPrint('[StreamScreen] ERROR: empty magnet link');
      setState(() {
        _hasError = true;
        _errorMessage = 'Magnet link unavailable. Cannot start P2P playback.';
        _loading = false;
      });
    } else {
      debugPrint('[StreamScreen] Starting torrent: ${widget.title}');
      _startTorrentStream(magnet);
    }
  }

  // ---------------------------------------------------------------------------
  //  Orientation helpers
  // ---------------------------------------------------------------------------

  void _forceLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  // ---------------------------------------------------------------------------
  //  Torrent stream lifecycle
  // ---------------------------------------------------------------------------

  void _startTorrentStream(String magnet) {
    TorrentService.startTorrent(magnet);

    _statusSubscription = TorrentService.statusStream.listen(
      _onTorrentStatus,
      onError: (error) {
        debugPrint('[StreamScreen] Status stream error: $error');
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = 'Torrent engine error: $error';
          _loading = false;
        });
      },
    );
  }

  void _onTorrentStatus(TorrentStatus status) {
    if (!mounted) return;

    // ---- Update display stats ----
    final speedInMB = status.downloadSpeed / (1024 * 1024);
    final doneInMB = status.totalDone / (1024 * 1024);

    setState(() {
      _progress = status.progress * 100;
      _speed = speedInMB >= 1.0
          ? '${speedInMB.toStringAsFixed(1)} MB/s'
          : '${(status.downloadSpeed / 1024).toStringAsFixed(0)} KB/s';
      _peers = status.peers.toString();
      _downloaded = '${doneInMB.toStringAsFixed(1)} MB';

      if (status.isMetadataPending) {
        _status = status.peers == 0
            ? 'Connecting to peers…'
            : 'Fetching metadata…';
      } else if (_playerInitializing) {
        _status = 'Starting playback…';
      } else {
        _status = 'Buffering… ${_progress.toStringAsFixed(1)}% · $_downloaded';
      }
    });

    // ---- Playback gate ----
    if (_playbackAttempted || _playerInitializing || _betterPlayerController != null) return;
    if (status.filePath == null || status.filePath!.isEmpty) return;
    if (!status.isValid) return; // metadata not received yet

    if (status.isPlaybackThresholdMet) {
      _startReadinessChecking(status.filePath!);
    }
  }

  void _startReadinessChecking(String filePath) {
    if (_playbackAttempted || _playerInitializing) return;
    _playerInitializing = true;
    _checkReadinessAndInitPlayer(filePath);
  }

  Future<void> _checkReadinessAndInitPlayer(String filePath) async {
    if (!mounted) return;
    // Show 'Starting playback...' while we verify
    if (mounted) setState(() => _status = 'Starting playback…');
    try {
      final String result = await TorrentService.verifyFileReady(filePath);
      if (result == 'READY') {
        _playbackAttempted = true;
        _playerInitializing = false;
        await _initVideoPlayer(filePath);
      } else {
        // Not ready yet, retry in 3 seconds
        debugPrint('[StreamScreen] verifyFileReady NOT_READY, retrying in 3s...');
        if (mounted) setState(() => _status = 'Buffering… verifying header');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !_playbackAttempted) {
            _checkReadinessAndInitPlayer(filePath);
          }
        });
      }
    } catch (e) {
      debugPrint('[StreamScreen] Error checking readiness: $e, retrying in 3s...');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_playbackAttempted) {
          _checkReadinessAndInitPlayer(filePath);
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  //  Video player init
  // ---------------------------------------------------------------------------

  Future<void> _initVideoPlayer(String filePath) async {
    if (_betterPlayerController != null) return;
    _playerInitializing = true;
    _playbackAttempted = true;

    debugPrint('[StreamScreen] _initVideoPlayer: $filePath');
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[StreamScreen] File does not exist yet: $filePath');
        _playerInitializing = false;
        _playbackAttempted = false; // reset to allow lookup again if file was temporarily missing
        return;
      }

      final betterPlayerConfiguration = BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        autoPlay: true,
        looping: false,
        allowedScreenSleep: false,
        fit: BoxFit.contain,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          enableAudioTracks: true,
          enableSubtitles: true,
          enableQualities: false,
          controlBarColor: Colors.black45,
        ),
      );

      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.file,
        filePath,
      );

      final controller = BetterPlayerController(betterPlayerConfiguration);
      await controller.setupDataSource(dataSource);

      if (!mounted) {
        controller.dispose();
        _playerInitializing = false;
        return;
      }

      setState(() {
        _betterPlayerController = controller;
        _loading = false;
        _playerInitializing = false;
      });
    } catch (e) {
      debugPrint('[StreamScreen] Player init error: $e');
      _playerInitializing = false;
      _playbackAttempted = false; // allow retry
      if (!mounted) return;
      // Retry once after 5 seconds — file may not be flushed to disk yet
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_playbackAttempted && !_hasError) {
          debugPrint('[StreamScreen] Retrying player init after error...');
          _initVideoPlayer(filePath);
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  //  Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _statusSubscription?.cancel();
    TorrentService.stopTorrent();
    _betterPlayerController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  //  Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Video player ──
          if (!_loading && _betterPlayerController != null && !_hasError)
            Positioned.fill(
              child: BetterPlayer(controller: _betterPlayerController!),
            ),

          // ── Error overlay ──
          if (_hasError) _buildErrorOverlay(),

          // ── Loading / buffering overlay ──
          if (_loading && !_hasError) _buildLoadingOverlay(),

          // ── Top header ──
          _buildTopBar(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  UI pieces
  // ---------------------------------------------------------------------------

  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Progress bar
              Container(
                width: 260,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (_progress / 100).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accent, Colors.orange],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStat('${_progress.toStringAsFixed(1)}%'),
                  const SizedBox(width: 16),
                  _buildStat('⬇ $_speed'),
                  const SizedBox(width: 16),
                  _buildStat('$_peers peers'),
                  const SizedBox(width: 16),
                  _buildStat(_downloaded),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'MP4: starts at 20 MB · MKV: starts at 100 MB + header',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.5),
                  ),
                ),
                child: const Text(
                  '⚡ P2P NATIVE',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.accent,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
