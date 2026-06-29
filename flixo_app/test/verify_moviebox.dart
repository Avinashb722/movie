import 'package:flutter_test/flutter_test.dart';
import 'package:flixo_app/services/moviebox_service.dart';

void main() {
  test('Verify MovieBox Service works', () async {
    print('--- STARTING MOVIEBOX VERIFICATION ---');
    print('Resolving streams for movie "Avatar"...');
    try {
      final streams = await MovieBoxService.resolveStreams('Avatar');
      print('Found ${streams.length} stream(s):');
      for (var s in streams) {
        print(' - Quality: ${s.resolution}p, Size: ${s.size}, Url: ${s.url}');
      }
      expect(streams, isNotEmpty);
    } catch (e) {
      print('Verification ERROR: $e');
      fail('MovieBox resolution threw an error: $e');
    }
  });
}
