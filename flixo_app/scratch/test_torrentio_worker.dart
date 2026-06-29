import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const imdbId = 'tt30068605';
  const proxy = 'https://long-wind-ad98.avinashbiradar722.workers.dev/';
  final target = 'https://torrentio.strem.fun/stream/movie/$imdbId.json';
  final url = Uri.parse('$proxy?url=${Uri.encodeComponent(target)}');
  
  try {
    print('Querying Torrentio via Cloudflare Worker proxy: $url...');
    final resp = await http.get(url);
    print('Worker proxy response status: ${resp.statusCode}');
    print('Worker proxy response body: ${resp.body}');
  } catch (e) {
    print('Error: $e');
  }
}
