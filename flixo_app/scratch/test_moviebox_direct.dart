import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/services/moviebox_service.dart';

Future<void> main() async {
  print('=== MOVIEBOX DIRECT SERVICE TEST ===');
  
  // Test with a extremely popular movie like "John Wick: Chapter 4" or "Avatar: The Way of Water"
  final title = 'Avatar: The Way of Water';
  print('Resolving streams for "$title"...');
  
  try {
    final streams = await MovieBoxService.resolveStreams(title);
    print('Found ${streams.length} stream(s):');
    for (final s in streams) {
      print('  * Resolution: ${s.resolution}p, Size: ${s.size}, URL: ${s.url.substring(0, s.url.length > 100 ? 100 : s.url.length)}...');
    }
  } catch (e) {
    print('Error: $e');
  }
}
