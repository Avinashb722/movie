import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const imdbId = 'tt30068605';
  const proxy = 'http://localhost:3009/api?url=';
  final target = 'https://torrentio.strem.fun/stream/movie/$imdbId.json';
  final url = Uri.parse('$proxy${Uri.encodeComponent(target)}');
  
  try {
    print('Querying Torrentio via Local Node proxy: $url...');
    final resp = await http.get(url);
    print('Local proxy response status: ${resp.statusCode}');
    print('Local proxy response body: ${resp.body}');
  } catch (e) {
    print('Error: $e');
  }
}
