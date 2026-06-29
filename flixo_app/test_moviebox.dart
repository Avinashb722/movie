import 'package:flutter/foundation.dart';
import 'lib/services/moviebox_service.dart';
import 'lib/services/archive_service.dart';

void main() async {
  debugPrint = (String? message, {int? wrapWidth}) {
    print(message);
  };

  print('=== STARTING MOVIEBOX RESOLVE TEST ===');
  final mbStreams = await MovieBoxService.resolveStreams('Karuppu');
  print('Resolved ${mbStreams.length} MovieBox streams:');
  for (var s in mbStreams) {
    print('- ${s.resolution}p: ${s.url} (${s.size}) [${s.language}]');
  }

  print('\n=== STARTING ARCHIVE RESOLVE TEST ===');
  final arcStreams = await ArchiveService.resolveStreams('Karuppu');
  print('Resolved ${arcStreams.length} Archive streams:');
  for (var s in arcStreams) {
    print('- ${s.label}: ${s.url} [${s.language}]');
  }
}
