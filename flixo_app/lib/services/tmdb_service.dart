import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/movie.dart';

class TmdbService {
  static const _key  = 'ee88434dff18c194e5b7a1bec83824b8';
  static const _base = 'https://api.themoviedb.org/3';
  static const _fallbackBase = 'https://api.tmdb.org/3';
  static const _proxy = 'https://ver-orcin-alpha.vercel.app/api?url=';
  static const imageBase  = 'https://images.tmdb.org/t/p/w500';
  static const backdropBase = 'https://images.tmdb.org/t/p/w1280';

  static bool _useFallback = false;

  // On web: TMDB is ISP-blocked, route through Vercel proxy
  // On native: try direct first, then fallback
  static Future<http.Response?> _getWithProxy(Uri directUri) async {
    if (kIsWeb) {
      // Web: go straight to Vercel proxy (TMDB blocked by ISP)
      try {
        final proxyUri = Uri.parse('$_proxy${Uri.encodeComponent(directUri.toString())}');
        final res = await http.get(proxyUri).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) return res;
      } catch (_) {}
      return null;
    }
    // Native: try direct
    try {
      final res = await http.get(directUri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) return res;
    } catch (_) {
      _useFallback = true;
    }
    return null;
  }

  static Future<List<Movie>> _fetch(String path, [Map<String, String>? extra]) async {
    final params = {'api_key': _key, ...?extra};
    
    // Try primary base
    if (!_useFallback || kIsWeb) {
      final uri = Uri.parse('$_base$path').replace(queryParameters: params);
      final res = await _getWithProxy(uri);
      if (res != null) {
        final data = json.decode(res.body);
        return (data['results'] as List)
            .map((e) => Movie.fromJson(e))
            .where((m) => m.posterPath.isNotEmpty)
            .toList();
      }
    }

    // Fallback to secondary base (native only - proxy already tried for web)
    if (!kIsWeb) {
      try {
        final uri = Uri.parse('$_fallbackBase$path').replace(queryParameters: params);
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          return (data['results'] as List)
              .map((e) => Movie.fromJson(e))
              .where((m) => m.posterPath.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }

    return [];
  }

  // Fetch pages 1 and 2 in parallel for ~40 results per endpoint
  static Future<List<Movie>> _fetchMultiPage(String path, [Map<String, String>? extra]) async {
    final p1 = _fetch(path, {...?extra, 'page': '1'});
    final p2 = _fetch(path, {...?extra, 'page': '2'});
    final results = await Future.wait([p1, p2]);
    final seen = <int>{};
    final combined = <Movie>[];
    for (final list in results) {
      for (final m in list) {
        if (seen.add(m.id)) combined.add(m);
      }
    }
    return combined;
  }

  static Future<List<Movie>> getTrending()   => _fetchMultiPage('/trending/movie/week');
  static Future<List<Movie>> getNowPlaying() => _fetchMultiPage('/movie/now_playing');
  static Future<List<Movie>> getTopRated()   => _fetchMultiPage('/movie/top_rated');
  static Future<List<Movie>> getPopular()    => _fetchMultiPage('/movie/popular');
  static Future<List<Movie>> getTvShows()    => _fetchMultiPage('/trending/tv/week');

  // Search fetches both pages for more results
  static Future<List<Movie>> searchMovies(String q) async {
    final p1 = _fetch('/search/movie', {'query': q, 'include_adult': 'false', 'page': '1'});
    final p2 = _fetch('/search/movie', {'query': q, 'include_adult': 'false', 'page': '2'});
    final results = await Future.wait([p1, p2]);
    final seen = <int>{};
    final combined = <Movie>[];
    for (final list in results) {
      for (final m in list) {
        if (seen.add(m.id)) combined.add(m);
      }
    }
    return combined;
  }

  static Future<List<Movie>> getByLanguage(String lang) =>
      _fetchMultiPage('/discover/movie', {
        'with_original_language': lang,
        'sort_by': 'popularity.desc',
      });

  static Future<List<Movie>> getByGenre(int genreId) =>
      _fetchMultiPage('/discover/movie', {
        'with_genres': genreId.toString(),
        'sort_by': 'popularity.desc',
      });

  // Named convenience getters for all 14 rows
  static Future<List<Movie>> getTelugu()  => getByLanguage('te');
  static Future<List<Movie>> getTamil()   => getByLanguage('ta');
  static Future<List<Movie>> getKannada() => getByLanguage('kn');
  static Future<List<Movie>> getAnime()   => getByLanguage('ja');
  static Future<List<Movie>> getHorror()  => getByGenre(27);
  static Future<List<Movie>> getComedy()  => getByGenre(35);
  static Future<List<Movie>> getSciFi()   => getByGenre(878);
  static Future<List<Movie>> getRomance() => getByGenre(10749);

  static Future<MovieDetail?> getDetail(int id) async {
    final params = {
      'api_key': _key,
      'append_to_response': 'external_ids,credits,videos',
    };

    final uri = Uri.parse('$_base/movie/$id').replace(queryParameters: params);
    final res = await _getWithProxy(uri);
    if (res != null) {
      return MovieDetail.fromJson(json.decode(res.body));
    }

    if (!kIsWeb) {
      try {
        final fbUri = Uri.parse('$_fallbackBase/movie/$id').replace(queryParameters: params);
        final fbRes = await http.get(fbUri).timeout(const Duration(seconds: 8));
        if (fbRes.statusCode == 200) {
          return MovieDetail.fromJson(json.decode(fbRes.body));
        }
      } catch (_) {}
    }

    return null;
  }

  static Future<List<Movie>> getSimilar(int id) =>
      _fetch('/movie/$id/similar');

  static Future<List<Movie>> discoverMovies({String? lang, int? genreId, String? sortBy, int page = 1}) {
    final Map<String, String> params = {'page': page.toString()};
    if (lang != null) params['with_original_language'] = lang;
    if (genreId != null) params['with_genres'] = genreId.toString();
    if (sortBy != null) params['sort_by'] = sortBy;
    return _fetch('/discover/movie', params);
  }

  static Future<List<Movie>> discoverMultiPage({String? lang, int? genreId, String? year, String? sortBy, int startPage = 1}) async {
    final Map<String, String> baseParams = {};
    if (lang != null) baseParams['with_original_language'] = lang;
    if (genreId != null) baseParams['with_genres'] = genreId.toString();
    if (year != null) baseParams['primary_release_year'] = year;
    if (sortBy != null) baseParams['sort_by'] = sortBy;

    final p1 = _fetch('/discover/movie', {...baseParams, 'page': startPage.toString()});
    final p2 = _fetch('/discover/movie', {...baseParams, 'page': (startPage + 1).toString()});
    final p3 = _fetch('/discover/movie', {...baseParams, 'page': (startPage + 2).toString()});

    final results = await Future.wait([p1, p2, p3]);
    final seen = <int>{};
    final combined = <Movie>[];
    for (final list in results) {
      for (final m in list) {
        if (seen.add(m.id)) combined.add(m);
      }
    }
    return combined;
  }

  static Future<Movie?> getMovieById(int id) async {
    return await getDetail(id);
  }
}

