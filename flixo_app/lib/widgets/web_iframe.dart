import 'package:flutter/material.dart';
import 'web_iframe_stub.dart' if (dart.library.js_util) 'web_iframe_web.dart';

Widget createWebIframe(String videoKey) {
  return WebIframeWidget(videoKey: videoKey);
}
