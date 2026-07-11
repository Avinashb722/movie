import 'package:flutter/material.dart';

class WebVideoPlayerWidget extends StatelessWidget {
  final String url;
  final String? referer;
  final String? token;
  const WebVideoPlayerWidget({super.key, required this.url, this.referer, this.token});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
void registerPointerInterceptor() {}
