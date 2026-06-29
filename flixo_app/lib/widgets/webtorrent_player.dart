import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/torrentio_service.dart';

/// WebTorrent player widget.
///
/// Runs WebTorrent.js inside a Flutter WebView. Loads an inline HTML page
/// that uses WebTorrent to stream a magnet link directly into a <video> element.
///
/// Architecture:
///   Flutter  →  WebView  →  WebTorrent.js (CDN)
///                              ↓  WebRTC peer-to-peer
///                         Torrent pieces from peers
///                              ↓
///                         <video> element streams movie
class WebTorrentPlayer extends StatefulWidget {
  final TorrentStream stream;
  final String movieTitle;
  final VoidCallback? onError;

  const WebTorrentPlayer({
    super.key,
    required this.stream,
    required this.movieTitle,
    this.onError,
  });

  @override
  State<WebTorrentPlayer> createState() => _WebTorrentPlayerState();
}

class _WebTorrentPlayerState extends State<WebTorrentPlayer> {
  WebViewController? _ctrl;
  String _status = 'Initializing WebTorrent…';
  double _progress = 0;
  String _speed = '';
  String _peers = '';
  bool _isPlaying = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _validateAndSetup();
  }

  void _validateAndSetup() {
    final magnet = widget.stream.magnetUri;

    // Validate magnet link
    if (magnet.isEmpty) {
      debugPrint('[WebTorrent] ERROR: Empty magnet URI');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Magnet link unavailable';
          _status = 'Error: No magnet link';
        });
      }
      widget.onError?.call();
      return;
    }

    debugPrint('[WebTorrent] Selected stream: ${widget.stream.quality} - ${widget.stream.name}');
    debugPrint('[WebTorrent] Magnet: ${magnet.substring(0, magnet.length.clamp(0, 100))}...');

    _setupWebView();
  }

  void _setupWebView() {
    if (kIsWeb) return;

    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 12; Pixel 6) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      // Listen on BOTH channels for compatibility
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) => _handleBridgeMessage(msg.message),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (msg) => _handleBridgeMessage(msg.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          debugPrint('[WebTorrent] Page loaded, injecting magnet...');
          _injectMagnet();
        },
        onWebResourceError: (error) {
          debugPrint('[WebTorrent] WebView error: ${error.description}');
        },
      ))
      ..loadFlutterAsset('assets/webtorrent_player.html');

    if (mounted) setState(() {});
  }

  void _injectMagnet() {
    final magnet = widget.stream.magnetUri;
    if (magnet.isEmpty) {
      debugPrint('[WebTorrent] Cannot inject: empty magnet');
      return;
    }

    final escaped = magnet
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');

    debugPrint('[WebTorrent] Injecting magnet into WebView...');
    _ctrl?.runJavaScript("window.startTorrent('$escaped');");
  }

  void _handleBridgeMessage(String message) {
    if (!mounted) return;

    try {
      // Handle JSON format from the new HTML
      if (message.startsWith('{')) {
        try {
          final data = Map<String, dynamic>.from(
            (message.contains('"type"'))
                ? _parseJson(message)
                : {'raw': message},
          );
          final type = data['type'];
          switch (type) {
            case 'status':
              setState(() => _status = data['message'] ?? '');
              break;
            case 'progress':
              setState(() {
                _progress = (data['progress'] ?? 0).toDouble() / 100.0;
                _speed = data['speed'] ?? '';
                _peers = data['peers']?.toString() ?? '';
                if (_progress > 0) _isPlaying = true;
              });
              break;
            case 'ready':
              setState(() => _isPlaying = true);
              break;
            case 'error':
              debugPrint('[WebTorrent] Error: ${data['message']}');
              setState(() {
                _hasError = true;
                _errorMessage = data['message'] ?? 'Unknown error';
              });
              widget.onError?.call();
              break;
          }
        } catch (_) {
          // Not valid JSON, try bridge format
        }
        return;
      }

      // Handle bridge format: "status:msg" / "progress:pct|speed|peers"
      if (message.startsWith('status:')) {
        setState(() => _status = message.substring(7));
      } else if (message.startsWith('progress:')) {
        final parts = message.substring(9).split('|');
        setState(() {
          _progress = (double.tryParse(parts[0]) ?? 0) / 100.0;
          _speed = parts.length > 1 ? parts[1] : '';
          _peers = parts.length > 2 ? parts[2] : '';
          if (_progress > 0) _isPlaying = true;
        });
      } else if (message.startsWith('error:')) {
        debugPrint('[WebTorrent] Error: ${message.substring(6)}');
        setState(() {
          _hasError = true;
          _errorMessage = message.substring(6);
        });
        widget.onError?.call();
      }
    } catch (e) {
      debugPrint('[WebTorrent] Bridge parse error: $e');
    }
  }

  Map<String, dynamic> _parseJson(String json) {
    // Simple JSON parser to avoid importing dart:convert in widget
    try {
      return Map<String, dynamic>.from(
        Map.castFrom(Uri.splitQueryString(json)),
      );
    } catch (_) {
      return {};
    }
  }

  @override
  void dispose() {
    _ctrl?.runJavaScript('window.stopTorrent && window.stopTorrent();');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Center(
        child: Text(
          'WebTorrent not supported on Flutter Web.\nUse the mobile app.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_hasError) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_ctrl == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _ctrl!),

        // Progress overlay (shown until video starts)
        if (!_isPlaying)
          Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.amber),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

        // Mini stats bar (shown when downloading/streaming)
        if (_isPlaying)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.black54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  if (_speed.isNotEmpty)
                    Text(
                      '⬇ $_speed',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11),
                    ),
                  if (_peers.isNotEmpty)
                    Text(
                      '$_peers peers',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
