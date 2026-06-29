import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const imdbId = 'tt30068605';
  final url = Uri.parse('https://torrentio.strem.fun/stream/movie/$imdbId.json');
  
  try {
    print('Querying Torrentio for $imdbId...');
    final resp = await http.get(url);
    print('Torrentio response status: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final streams = data['streams'] as List? ?? [];
      print('Found ${streams.length} torrent streams:');
      for (var s in streams) {
        print('- Title: "${s['title']}" | InfoHash: "${s['infoHash']}"');
      }
    } else {
      print('Failed. Response: ${resp.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
