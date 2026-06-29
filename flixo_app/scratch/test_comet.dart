import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final imdbId = 'tt37971394'; // Blast
  final cometUri = Uri.parse('https://comet.strem.fun/stream/movie/$imdbId.json');
  
  print('Fetching from Comet Addon: $cometUri');
  try {
    final resp = await http.get(cometUri).timeout(const Duration(seconds: 10));
    print('Status: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final streams = data['streams'] as List? ?? [];
      print('Comet Streams count: ${streams.length}');
      for (var s in streams) {
        print(' - Title: ${s['title']}');
        print('   URL: ${s['url'] ?? s['externalUrl']}');
      }
    } else {
      print('Response: ${resp.body}');
    }
  } catch (e) {
    print('Comet Error: $e');
  }

  // Let's also check another popular public aggregator (Vidsrc/Superflix proxy)
  final vidsrcUri = Uri.parse('https://vidsrc.to/embed/movie/$imdbId');
  print('\nChecking Vidsrc.to embed status: $vidsrcUri');
  try {
    final resp = await http.head(vidsrcUri).timeout(const Duration(seconds: 10));
    print('Vidsrc.to HTTP code: ${resp.statusCode}');
  } catch (e) {
    print('Vidsrc Error: $e');
  }
}
