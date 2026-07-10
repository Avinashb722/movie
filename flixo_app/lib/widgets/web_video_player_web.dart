import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void registerPointerInterceptor() {
  ui_web.platformViewRegistry.registerViewFactory('pointer-interceptor', (int viewId) {
    final div = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.pointerEvents = 'auto'
      ..style.background = 'transparent';
    return div;
  });
}

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
  bool _useSandbox = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'web-video-${widget.url.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    _initProxyUrl();
  }

  Future<void> _initProxyUrl() async {
    _useSandbox = false;

    await SharedPreferences.getInstance();

    String finalUrl = widget.url;

    // Extract original target URL if already wrapped in a proxy URL
    // BUT keep the proxy wrapper for m3u8/HLS streams (movienest.app rewrites relative URLs)
    if (finalUrl.contains('api?url=') && !finalUrl.contains('movienest.app')) {
      try {
        final uri = Uri.parse(finalUrl);
        final target = uri.queryParameters['url'];
        if (target != null && target.isNotEmpty) {
          finalUrl = target;
        }
      } catch (_) {}
    }

    final bool isMovieBox = finalUrl.contains('hakunaymatata.com') || finalUrl.contains('aoneroom.com');
    final bool isArchive = finalUrl.contains('archive.org');

    final bool isProxyAlready = finalUrl.contains('corsproxy.io') ||
        finalUrl.contains('www.movienest.app') ||
        finalUrl.contains('ver-orcin-alpha.vercel.app') ||
        finalUrl.contains('localhost:3009') ||
        finalUrl.contains('workers.dev');

    if (!isProxyAlready) {
      if (isArchive) {
        // Archive.org: use the dedicated Cloudflare Worker (corsproxy.io blocks Archive with 403)
        const cfWorker = 'https://long-wind-ad98.avinashbiradar722.workers.dev/';
        finalUrl = '$cfWorker?url=${Uri.encodeComponent(finalUrl)}';
      } else if (isMovieBox) {
        // Play ALL MovieBox-hosted streams (bcdn + bcdnxw) directly using the no-referrer sandboxed Blob player.
        // Node.js tests show bcdnxw blocks proxy referrers (403), but Chrome's native TLS handshake is accepted.
        // This matches the morning approach that was confirmed working.
        _useSandbox = true;
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
      final bool isIframe = finalUrl.contains('2embed') || finalUrl.contains('embed') || finalUrl.contains('vidnest.fun');

      if (isIframe) {
        final iframe = html.IFrameElement()
          ..src = finalUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..setAttribute('allowfullscreen', 'true')
          ..setAttribute('allow', 'autoplay; encrypted-media')
          ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-presentation allow-forms');
        return iframe;
      }

      if (_useSandbox) {
        final String iframeHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="referrer" content="no-referrer">
  <style>
    body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background-color: black; }
    video { width: 100%; height: 100%; object-fit: contain; }
  </style>
</head>
<body>
  <video src="$finalUrl" autoplay controls playsinline referrerpolicy="no-referrer" controlsList="nodownload"></video>
</body>
</html>
''';
        final blob = html.Blob([iframeHtml], 'text/html');
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        
        final iframe = html.IFrameElement()
          ..src = blobUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..setAttribute('allowfullscreen', 'true')
          ..setAttribute('allow', 'autoplay; encrypted-media');
        return iframe;
      }

      final bool isHls = finalUrl.contains('.m3u8') || finalUrl.contains('.txt') || Uri.decodeComponent(finalUrl).contains('.m3u8');
      if (isHls) {
        // Use a self-contained blob iframe with HLS.js embedded inline.
        // This is required because Flutter platform views render in a separate iframe context,
        // so document.getElementById() from the main frame cannot find the video element.
        final String iframeHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="referrer" content="no-referrer">
  <style>
    body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background-color: black; }
    video { width: 100%; height: 100%; object-fit: contain; }
  </style>
</head>
<body>
  <video id="hlsvideo" autoplay controls playsinline></video>
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  <script>
    var url = "${finalUrl.replaceAll('"', '\\"')}";
    function setupHls() {
      var video = document.getElementById('hlsvideo');
      if (typeof Hls !== 'undefined' && Hls.isSupported()) {
        var hls = new Hls({ enableWorker: false });
        hls.loadSource(url);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, function() { video.play(); });
        hls.on(Hls.Events.ERROR, function(event, data) {
          console.error('[HLS.js Error]', data.type, data.details, data.fatal ? 'FATAL' : '', data.url || '');
          if (data.fatal) {
            switch(data.type) {
              case Hls.ErrorTypes.NETWORK_ERROR:
                console.log('[HLS.js] Network error, attempting recovery...');
                hls.startLoad();
                break;
              default:
                console.log('[HLS.js] Fatal error, destroying...');
                hls.destroy();
                break;
            }
          }
        });
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = url;
        video.play();
      } else {
        console.error('[HLS.js] Not supported and no native HLS support');
      }
    }
    // Wait for HLS.js to load with polling (more reliable in blob iframes)
    function waitForHls() {
      if (typeof Hls !== 'undefined') {
        setupHls();
      } else {
        setTimeout(waitForHls, 100);
      }
    }
    waitForHls();
  </script>
</body>
</html>''';
        final blob = html.Blob([iframeHtml], 'text/html');
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final iframe = html.IFrameElement()
          ..src = blobUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..setAttribute('allowfullscreen', 'true')
          ..setAttribute('allow', 'autoplay; encrypted-media');
        return iframe;
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

      // Route requests through CORS proxies (like CF Workers or Vercel Proxies) using CORS mode.
      // Setting crossOrigin = 'anonymous' is required to prevent Chrome's ORB (Opaque Response Blocking) from blocking the playback.
      if (isArchive || finalUrl.contains('workers.dev') || finalUrl.contains('vercel.app') || finalUrl.contains('api?url=')) {
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
