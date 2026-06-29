import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const key = 'ee88434dff18c194e5b7a1bec83824b8';
  const proxy = 'https://ver-orcin-alpha.vercel.app/api?url=';
  
  final queryUrl = Uri.encodeComponent('https://api.themoviedb.org/3/search/movie?api_key=$key&query=Junior');
  final queryUri = Uri.parse('$proxy$queryUrl');
  
  try {
    final resp = await http.get(queryUri);
    final data = json.decode(resp.body);
    final results = data['results'] as List? ?? [];
    print('Found ${results.length} search results for "Junior":');
    
    for (var r in results) {
      final id = r['id'];
      final title = r['title'] ?? '';
      final origTitle = r['original_title'] ?? '';
      final lang = r['original_language'] ?? '';
      final release = r['release_date'] ?? '';
      
      // Fetch external IDs to see if there is an IMDB ID
      final extUrl = Uri.encodeComponent('https://api.themoviedb.org/3/movie/$id/external_ids?api_key=$key');
      final extUri = Uri.parse('$proxy$extUrl');
      final extResp = await http.get(extUri);
      final extData = json.decode(extResp.body);
      final imdbId = extData['imdb_id'] ?? '';
      
      print('- Title: "$title" | Original: "$origTitle" | Language: "$lang" | Release: "$release" | TMDB ID: $id | IMDB ID: "$imdbId"');
    }
  } catch (e) {
    print('Error: $e');
  }
}
