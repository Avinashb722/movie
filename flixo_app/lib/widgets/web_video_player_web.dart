import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebVideoPlayerWidget extends StatefulWidget {
  final String url;
  final String? referer;
  final String? token;
  const WebVideoPlayerWidget({super.key, required this.url, this.referer, this.token});

  @override
  State<WebVideoPlayerWidget> createState() => _WebVideoPlayerWidgetState();
}

class _WebVideoPlayerWidgetState extends State<WebVideoPlayerWidget> {
  late String _viewId;
  String? _playableUrl;
  bool _loadingProxy = true;

  @override
  void initState() {
    super.initState();
    _viewId = 'web-video-${widget.url.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    _initProxyUrl();
  }

  Future<void> _initProxyUrl() async {
    await SharedPreferences.getInstance();

    String finalUrl = widget.url;

    final bool isMovieBox = widget.url.contains('hakunaymatata.com') || widget.url.contains('aoneroom.com');
    final bool isArchive = widget.url.contains('archive.org');

    final bool isProxyAlready = widget.url.contains('corsproxy.io') ||
        widget.url.contains('ver-orcin-alpha.vercel.app') ||
        widget.url.contains('localhost:3009') ||
        widget.url.contains('workers.dev');

    if (!isProxyAlready) {
      if (isArchive) {
        // Archive.org: use the dedicated Cloudflare Worker (corsproxy.io blocks Archive with 403)
        const cfWorker = 'https://long-wind-ad98.avinashbiradar722.workers.dev/';
        finalUrl = '$cfWorker?url=${Uri.encodeComponent(widget.url)}';
      } else if (isMovieBox) {
        // MovieBox: play direct — CDN has no CORS headers so no crossOrigin
        finalUrl = widget.url;
      }
    }

    // Inject Hls.js script for Chrome support
    if (html.document.querySelector('script[src*="hls.js"]') == null) {
      final script = html.ScriptElement()
        ..src = 'https://cdn.jsdelivr.net/npm/hls.js@latest'
        ..type = 'text/javascript';
      script.onLoad.listen((event) {
        debugPrint('[WebVideoPlayerWidget] Hls.js library loaded successfully.');
      });
      html.document.head!.append(script);
    }

    // Register HTML Video or IFrame View
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final bool isIframe = widget.url.contains('2embed') || widget.url.contains('embed');
      if (isIframe) {
        final iframe = html.IFrameElement()
          ..src = finalUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..setAttribute('allowfullscreen', 'true')
          ..setAttribute('allow', 'autoplay; encrypted-media');
        return iframe;
      }

      final bool isHls = finalUrl.contains('.m3u8') || Uri.decodeComponent(finalUrl).contains('.m3u8');
      if (isHls) {
        final video = html.VideoElement()
          ..id = 'video-$_viewId'
          ..autoplay = true
          ..controls = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = 'black'
          ..setAttribute('playsinline', 'true');

        final div = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = 'black';
        div.append(video);

        // Bind Hls.js programmatically after the element mounts and Hls is loaded
        void runHlsSetup([int attempt = 1]) {
          final jsCode = '''
            (function() {
              var video = document.getElementById('video-$_viewId');
              var url = '$finalUrl';
              if (video) {
                if (typeof Hls !== 'undefined') {
                  if (Hls.isSupported()) {
                    var hls = new Hls();
                    hls.loadSource(url);
                    hls.attachMedia(video);
                  } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
                    video.src = url;
                  }
                } else {
                  // Notify parent Dart context of undefined state
                  console.warn('Hls not loaded yet, attempt: ' + $attempt);
                }
              }
            })();
          ''';
          final script = html.ScriptElement()
            ..text = jsCode;
          html.document.body!.append(script);
          script.remove();
        }

        Future.delayed(const Duration(milliseconds: 150), () {
          runHlsSetup(1);
          // Fallback retries if script load lagged
          for (var i = 1; i <= 4; i++) {
            Future.delayed(Duration(milliseconds: 150 * i), () {
              runHlsSetup(i + 1);
            });
          }
        });

        return div;
      }

      final video = html.VideoElement()
        ..src = finalUrl
        ..autoplay = true
        ..controls = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.background = 'black'
        ..setAttribute('playsinline', 'true')
        ..setAttribute('controlsList', 'nodownload');

      // Archive.org supports CORS (ACAO: *) — set crossOrigin so Chrome can
      // verify the corsproxy.io response is valid media (prevents ERR_BLOCKED_BY_ORB).
      // MovieBox CDN has no CORS headers — do NOT set crossOrigin (causes preflight fail).
      if (isArchive) {
        video.crossOrigin = 'anonymous';
      }

      return video;
    });

    if (mounted) {
      setState(() {
        _playableUrl = finalUrl;
        _loadingProxy = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant WebVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _viewId = 'web-video-${widget.url.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _loadingProxy = true;
      });
      _initProxyUrl();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProxy) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      );
    }
    return HtmlElementView(viewType: _viewId);
  }
}
