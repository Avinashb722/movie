import 'package:flutter/material.dart';

class WebIframeWidget extends StatelessWidget {
  final String videoKey;
  const WebIframeWidget({super.key, required this.videoKey});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Web platform only'));
  }
}
