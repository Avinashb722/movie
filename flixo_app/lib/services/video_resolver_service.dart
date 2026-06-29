import 'archive_service.dart';

export 'archive_service.dart' show ArchiveStream;

/// Thin wrapper that resolves real CDN/HLS streams for a movie.
///
/// Stream resolution order:
///   1. Internet Archive (archive.org) — free, legal, CDN-hosted
///      Returns HLS (.m3u8) adaptive streams or direct MP4 at multiple qualities.
///
/// Returns an empty list when nothing is found — the caller should show an
/// appropriate "not available" message (no sample/demo videos ever played).
class VideoResolverService {
  static Future<List<ArchiveStream>> resolveStreams(
    int tmdbId,
    String? imdbId,
    String title,
    int? year,
  ) async {
    // Internet Archive CDN search
    final streams = await ArchiveService.resolveStreams(
      title,
      year: year,
      imdbId: imdbId,
    );
    return streams;
  }
}
