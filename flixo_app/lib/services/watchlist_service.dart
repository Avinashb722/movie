import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/movie.dart';

class WatchlistService {
  static final WatchlistService instance = WatchlistService._internal();
  WatchlistService._internal() {
    _loadWatchlist();
  }

  final ValueNotifier<List<Movie>> watchlistNotifier = ValueNotifier<List<Movie>>([]);

  Future<void> _loadWatchlist() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString('watchlist');
        if (content != null) {
          final list = jsonDecode(content) as List;
          watchlistNotifier.value = list.map((e) => Movie.fromJson(e)).toList();
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/watchlist.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          final list = jsonDecode(content) as List;
          watchlistNotifier.value = list.map((e) => Movie.fromJson(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('[WatchlistService] Error loading watchlist: $e');
    }
  }

  Future<void> _saveWatchlist() async {
    try {
      final data = watchlistNotifier.value.map((e) => {
        'id': e.id,
        'title': e.title,
        'poster_path': e.posterPath,
        'backdrop_path': e.backdropPath,
        'vote_average': e.rating,
        'overview': e.overview,
        'release_date': e.releaseDate,
        'original_language': e.language,
      }).toList();
      final content = jsonEncode(data);

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('watchlist', content);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/watchlist.json');
        await file.writeAsString(content);
      }
    } catch (e) {
      debugPrint('[WatchlistService] Error saving watchlist: $e');
    }
  }

  bool isInWatchlist(int movieId) {
    return watchlistNotifier.value.any((e) => e.id == movieId);
  }

  Future<void> toggleWatchlist(Movie movie) async {
    final list = List<Movie>.from(watchlistNotifier.value);
    final idx = list.indexWhere((e) => e.id == movie.id);
    if (idx != -1) {
      list.removeAt(idx);
    } else {
      list.add(movie);
    }
    watchlistNotifier.value = list;
    await _saveWatchlist();
  }
}
