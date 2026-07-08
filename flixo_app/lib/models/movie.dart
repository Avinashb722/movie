class Movie {
  final int    id;
  final String title;
  final String posterPath;
  final String backdropPath;
  final double rating;
  final String overview;
  final String releaseDate;
  final String language;
  final List<int> genreIds;
  final bool isTvShow;

  const Movie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.rating,
    required this.overview,
    required this.releaseDate,
    required this.language,
    this.genreIds = const [],
    this.isTvShow = false,
  });

  String get year => releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
  String get posterUrl => posterPath.isNotEmpty
      ? 'https://images.tmdb.org/t/p/w500$posterPath' : '';
  String get backdropUrl => backdropPath.isNotEmpty
      ? 'https://images.tmdb.org/t/p/w1280$backdropPath' : '';

  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
    id:           j['id'] ?? 0,
    title:        j['title'] ?? j['name'] ?? '',
    posterPath:   j['poster_path'] ?? '',
    backdropPath: j['backdrop_path'] ?? '',
    rating:       (j['vote_average'] ?? 0).toDouble(),
    overview:     j['overview'] ?? '',
    releaseDate:  j['release_date'] ?? j['first_air_date'] ?? '',
    language:     j['original_language'] ?? '',
    genreIds:     j['genre_ids'] != null ? List<int>.from(j['genre_ids']) : const [],
    isTvShow:     j['media_type'] == 'tv' || j['first_air_date'] != null || (j['name'] != null && j['title'] == null),
  );

  Map<String, dynamic> toJson() => {
    'id':                id,
    'title':             title,
    'poster_path':       posterPath,
    'backdrop_path':     backdropPath,
    'vote_average':      rating,
    'overview':          overview,
    'release_date':      releaseDate,
    'original_language': language,
    'genre_ids':         genreIds,
    'is_tv_show':        isTvShow,
  };
}

class CastMember {
  final String name;
  final String character;
  final String profilePath;

  const CastMember({required this.name, required this.character, required this.profilePath});

  String get photoUrl => profilePath.isNotEmpty
      ? 'https://images.tmdb.org/t/p/w185$profilePath' : '';

  factory CastMember.fromJson(Map<String, dynamic> j) => CastMember(
    name:        j['name'] ?? '',
    character:   j['character'] ?? '',
    profilePath: j['profile_path'] ?? '',
  );
}

class TvSeason {
  final int seasonNumber;
  final int episodeCount;
  final String name;
  final String posterPath;

  const TvSeason({
    required this.seasonNumber,
    required this.episodeCount,
    required this.name,
    required this.posterPath,
  });

  factory TvSeason.fromJson(Map<String, dynamic> json) => TvSeason(
        seasonNumber: json['season_number'] ?? 0,
        episodeCount: json['episode_count'] ?? 0,
        name: json['name'] ?? '',
        posterPath: json['poster_path'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'season_number': seasonNumber,
        'episode_count': episodeCount,
        'name': name,
        'poster_path': posterPath,
      };
}

class MovieDetail extends Movie {
  final String imdbId;
  final int    runtime;
  final List<String> genres;
  final List<CastMember> cast;
  final String trailerYoutubeKey;
  final List<TvSeason> seasons;
  final int numberOfSeasons;

  const MovieDetail({
    required super.id,
    required super.title,
    required super.posterPath,
    required super.backdropPath,
    required super.rating,
    required super.overview,
    required super.releaseDate,
    required super.language,
    super.genreIds,
    super.isTvShow,
    required this.imdbId,
    required this.runtime,
    required this.genres,
    required this.cast,
    required this.trailerYoutubeKey,
    this.seasons = const [],
    this.numberOfSeasons = 0,
  });

  String get runtimeStr {
    if (runtime == 0) return '';
    final h = runtime ~/ 60;
    final m = runtime % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  factory MovieDetail.fromJson(Map<String, dynamic> j) {
    final ext   = j['external_ids'] as Map<String, dynamic>? ?? {};
    final creds = j['credits'] as Map<String, dynamic>? ?? {};
    final castList = (creds['cast'] as List? ?? [])
        .take(10)
        .map((c) => CastMember.fromJson(c))
        .toList();
    final genreList = (j['genres'] as List? ?? [])
        .map((g) => g['name'].toString())
        .toList();
    final genreIdsList = (j['genres'] as List? ?? [])
        .map((g) => (g['id'] as num).toInt())
        .toList();
    final videos = j['videos'] as Map<String, dynamic>? ?? {};
    final videoList = videos['results'] as List? ?? [];
    final trailer = videoList.firstWhere(
      (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
      orElse: () => null,
    );
    final trailerKey = trailer != null ? trailer['key'] as String? ?? '' : '';

    final isTv = j['first_air_date'] != null || j['number_of_seasons'] != null || j['name'] != null;
    final seasonsJson = j['seasons'] as List? ?? [];
    final seasonsList = seasonsJson
        .map((s) => TvSeason.fromJson(s))
        .where((s) => s.seasonNumber > 0) // Skip season 0 (Specials) for cleaner UI
        .toList();

    return MovieDetail(
      id:           j['id'] ?? 0,
      title:        j['title'] ?? j['name'] ?? '',
      posterPath:   j['poster_path'] ?? '',
      backdropPath: j['backdrop_path'] ?? '',
      rating:       (j['vote_average'] ?? 0).toDouble(),
      overview:     j['overview'] ?? '',
      releaseDate:  j['release_date'] ?? j['first_air_date'] ?? '',
      language:     j['original_language'] ?? '',
      genreIds:     genreIdsList,
      isTvShow:     isTv,
      imdbId:       ext['imdb_id'] ?? j['imdb_id'] ?? '',
      runtime:      j['runtime'] ?? (j['episode_run_time'] is List && (j['episode_run_time'] as List).isNotEmpty ? (j['episode_run_time'] as List)[0] : 0),
      genres:       genreList,
      cast:         castList,
      trailerYoutubeKey: trailerKey,
      seasons:      seasonsList,
      numberOfSeasons: j['number_of_seasons'] ?? seasonsList.length,
    );
  }
}
