class VidSrcStream {
  final String label;
  final String url;
  final String provider;

  const VidSrcStream({
    required this.label,
    required this.url,
    required this.provider,
  });
}

class VidSrcService {
  /// Generates the direct player iframe URLs for the given movie's IMDb ID.
  static List<VidSrcStream> getStreams(String imdbId) {
    if (imdbId.trim().isEmpty || !imdbId.startsWith('tt')) {
      return [];
    }
    return [
      VidSrcStream(
        label: 'VidSrc (to) Embed Player',
        url: 'https://vidsrc.to/embed/movie/$imdbId',
        provider: 'VidSrc.to',
      ),
      VidSrcStream(
        label: 'VidSrc (me) Embed Player',
        url: 'https://vidsrc.me/embed/$imdbId',
        provider: 'VidSrc.me',
      ),
      VidSrcStream(
        label: '2Embed Embed Player',
        url: 'https://www.2embed.cc/embed/$imdbId',
        provider: '2Embed',
      ),
    ];
  }
}
