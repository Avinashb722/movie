import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Windows-only in-app P2P torrent streaming via WebTorrent CLI.
///
/// WebTorrent CLI spins up a local HTTP server and streams the torrent file
/// over HTTP so media_kit can play it directly — no external client needed.
///
/// SETUP (one-time, done automatically if Node.js is present):
///   npm install -g webtorrent-cli
///
/// Usage:
///   final service = WindowsTorrentStreamService();
///   final url = await service.startStream(magnetUri);
///   // play `url` with media_kit
///   service.dispose(); // when done
class WindowsTorrentStreamService {
  Process? _process;
  bool _disposed = false;
  static const int _port = 8889; // Avoid conflict with local proxy on 3009
  static const Duration _startTimeout = Duration(seconds: 45);

  /// Find local installation path of VLC on Windows
  static String? getVlcPath() {
    final paths = [
      r'C:\Program Files\VideoLAN\VLC\vlc.exe',
      r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe',
    ];
    for (final p in paths) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  /// Launch magnet stream directly inside local VLC media player
  static Future<bool> launchInVlc(String magnetUri) async {
    final vlc = getVlcPath();
    if (vlc == null) return false;
    try {
      debugPrint('[WTorrent] Launching VLC directly via cmd: $vlc');
      // Use cmd.exe /c start to force protocol URI parsing
      await Process.start(
        'cmd.exe',
        ['/c', 'start', '""', vlc, magnetUri],
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (e) {
      debugPrint('[WTorrent] VLC launch error: $e');
      return false;
    }
  }

  /// Returns true if webtorrent-cli is installed and usable.
  static Future<bool> isAvailable() async {
    try {
      final result = await Process.run(
        'webtorrent',
        ['--version'],
        runInShell: true,
      ).timeout(const Duration(seconds: 5));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Installs webtorrent-cli globally via npm (requires Node.js).
  /// Returns true on success.
  static Future<bool> install() async {
    try {
      debugPrint('[WTorrent] Installing webtorrent-cli via npm...');
      final result = await Process.run(
        'npm',
        ['install', '-g', 'webtorrent-cli'],
        runInShell: true,
      ).timeout(const Duration(seconds: 120));
      debugPrint('[WTorrent] npm install exit: ${result.exitCode}');
      debugPrint('[WTorrent] npm stdout: ${result.stdout}');
      if (result.stderr.toString().isNotEmpty) {
        debugPrint('[WTorrent] npm stderr: ${result.stderr}');
      }
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('[WTorrent] Install failed: $e');
      return false;
    }
  }

  /// Starts streaming the torrent and returns the local HTTP URL.
  /// Throws if webtorrent is not available or stream fails to start.
  Future<String> startStream(String magnetOrHash, {String? preferredFileName, void Function(String)? onProgress}) async {
    if (_disposed) throw StateError('Service already disposed');

    debugPrint('[WTorrent] Starting stream for: ${magnetOrHash.substring(0, magnetOrHash.length.clamp(0, 60))}...');

    // Kill any previous process
    await dispose();
    _disposed = false;

    final completer = Completer<String>();

    _process = await Process.start(
      'webtorrent.cmd',
      [
        magnetOrHash,
        '-p', _port.toString(),
        '-s', '0',
      ],
      runInShell: false,
    );

    // Listen for the URL in stdout
    final stdoutSub = _process!.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final cleanLine = line.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '').trim();
          if (cleanLine.isNotEmpty) {
            debugPrint('[WTorrent] stdout: $cleanLine');
            if (onProgress != null) {
              onProgress(cleanLine);
            }
          }

          // WebTorrent prints something like "Server running at http://localhost:8889/..."
          final urlMatch = RegExp(r'http://localhost:$_port[^\s]*').firstMatch(line)
              ?? RegExp(r'http://127\.0\.0\.1:$_port[^\s]*').firstMatch(line)
              ?? RegExp(r'(https?://localhost:\d+[^\s]*)').firstMatch(line);
          if (urlMatch != null && !completer.isCompleted) {
            completer.complete(urlMatch.group(0)!);
          }
          // Also detect "Fetching" to know it started
          if (line.toLowerCase().contains('fetching') && !completer.isCompleted) {
            debugPrint('[WTorrent] Torrent is being fetched...');
          }
        });

    _process!.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) => debugPrint('[WTorrent] stderr: $line'));

    // Timeout
    Timer(_startTimeout, () {
      if (!completer.isCompleted) {
        stdoutSub.cancel();
        completer.completeError(
          TimeoutException('WebTorrent did not start serving within ${_startTimeout.inSeconds}s'),
        );
      }
    });

    try {
      final url = await completer.future;
      debugPrint('[WTorrent] ✅ Stream ready at: $url');
      return url;
    } catch (e) {
      // Don't kill process immediately on stdout timeout, let polling try to connect
      if (e is TimeoutException) {
        debugPrint('[WTorrent] Stdout timeout, letting process run for polling fallback.');
      } else {
        await dispose();
      }
      rethrow;
    }
  }

  /// Polls the local HTTP server until it's ready, as an alternative to stdout parsing.
  /// Returns the stream URL on success.
  Future<String> waitForServer({int maxRetries = 30, Duration retryDelay = const Duration(seconds: 2)}) async {
    final client = HttpClient();
    for (int i = 0; i < maxRetries; i++) {
      try {
        final req = await client.get('127.0.0.1', _port, '/');
        final resp = await req.close();
        if (resp.statusCode == 200 || resp.statusCode == 206 || resp.statusCode == 302) {
          client.close();
          return 'http://127.0.0.1:$_port/';
        }
        await resp.drain<void>();
      } catch (_) {
        // Not ready yet
      }
      await Future.delayed(retryDelay);
      debugPrint('[WTorrent] Waiting for server... (attempt ${i+1}/$maxRetries)');
    }
    client.close();
    throw TimeoutException('WebTorrent HTTP server never became ready');
  }

  Future<void> dispose() async {
    _disposed = true;
    if (_process != null) {
      try {
        _process!.kill(ProcessSignal.sigterm);
        await _process!.exitCode.timeout(const Duration(seconds: 3)).catchError((_) {
          _process!.kill(ProcessSignal.sigkill);
          return 0;
        });
      } catch (_) {}
      _process = null;
      debugPrint('[WTorrent] Process killed');
    }
  }
}
