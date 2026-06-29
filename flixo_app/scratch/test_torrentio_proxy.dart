import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const imdbId = 'tt30068605';
  const proxy = 'https://ver-orcin-alpha.vercel.app/api?url=';
  final target = 'https://torrentio.strem.fun/stream/movie/$imdbId.json';
  final url = Uri.parse('$proxy${Uri.encodeComponent(target)}');
  
  try {
    print('Querying Torrentio via Vercel proxy: $url...');
    final resp = await http.get(url);
    print('Vercel proxy response status: ${resp.statusCode}');
    print('Vercel proxy response body: ${resp.body}');
  } catch (e) {
    print('Error: $e');
  }
}
