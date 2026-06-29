import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const imdbId = 'tt30068605';
  const proxy = 'https://corsproxy.io/?';
  final target = 'https://torrentio.strem.fun/stream/movie/$imdbId.json';
  final url = Uri.parse('$proxy${Uri.encodeComponent(target)}');
  
  try {
    print('Querying Torrentio via corsproxy.io: $url...');
    final resp = await http.get(url);
    print('corsproxy.io response status: ${resp.statusCode}');
    print('corsproxy.io response body: ${resp.body}');
  } catch (e) {
    print('Error: $e');
  }
}
