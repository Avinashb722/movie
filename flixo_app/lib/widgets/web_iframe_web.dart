import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class WebIframeWidget extends StatefulWidget {
  final String videoKey;
  const WebIframeWidget({super.key, required this.videoKey});

  @override
  State<WebIframeWidget> createState() => _WebIframeWidgetState();
}

class _WebIframeWidgetState extends State<WebIframeWidget> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'iframe-${widget.videoKey}';
    
    // Register the iframe view factory using the Web platform view registry
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/${widget.videoKey}?autoplay=1&mute=0&controls=0&rel=0&showinfo=0&modestbranding=1&playsinline=1&iv_load_policy=3&fs=0'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; encrypted-media; picture-in-picture'
        ..setAttribute('allowfullscreen', 'true');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
