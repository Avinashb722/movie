import 'package:flutter_test/flutter_test.dart';
import 'package:flixo_app/services/two_embed_service.dart';

void main() {
  test('Verify 2Embed Stream Resolution for IMDb tt35064672', () async {
    print('--- STARTING 2EMBED STREAM VERIFICATION ---');
    final streamUrl = await TwoEmbedService.resolveStream(
      imdbId: 'tt35064672',
      tmdbId: 1392469,
    );
    print('Resolved Stream URL: $streamUrl');
    expect(streamUrl, isNotNull);
    expect(streamUrl, isNotEmpty);
  });
}
