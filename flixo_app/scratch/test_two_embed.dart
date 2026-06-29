import 'dart:io';
import '../lib/services/two_embed_service.dart';

void main() async {
  // Test with a known IMDb ID that works on 2embed
  const testImdbId = 'tt39139925'; // Dhurandhar

  print('Testing TwoEmbedService resolver...');
  print('IMDb ID: $testImdbId');
  print('');

  final service = TwoEmbedService.instance;
  
  try {
    final url = await service.resolveStreamUrl(testImdbId);
    
    if (url != null) {
      print('✅ SUCCESS! Resolved stream URL:');
      print('   $url');
      print('');
      print('URL analysis:');
      print('   - Is LookMovie HLS4 (TikTok): ${url.contains('lookmovie2.skin/stream/')}');
      print('   - Is LookMovie HLS2 (premilkyway): ${url.contains('premilkyway.com')}');
      print('   - Is m3u8: ${url.contains('.m3u8')}');
      exit(0);
    } else {
      print('❌ FAILED: resolveStreamUrl returned null');
      exit(1);
    }
  } catch (e) {
    print('❌ ERROR: $e');
    exit(1);
  }
}
