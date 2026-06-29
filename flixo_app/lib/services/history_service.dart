import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';

class HistoryService {
  static final HistoryService instance = HistoryService._internal();
  HistoryService._internal() {
    _loadHistory();
  }

  final ValueNotifier<List<Movie>> historyNotifier = ValueNotifier<List<Movie>>([]);

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString('history');
      if (content != null) {
        final list = jsonDecode(content) as List;
        historyNotifier.value = list.map((e) => Movie.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('[HistoryService] Error loading history: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final data = historyNotifier.value.map((e) => {
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('history', content);
    } catch (e) {
      debugPrint('[HistoryService] Error saving history: $e');
    }
  }

  Future<void> addToHistory(Movie movie) async {
    final list = List<Movie>.from(historyNotifier.value);
    // Remove if already exists to move it to the front
    list.removeWhere((e) => e.id == movie.id);
    // Insert at front
    list.insert(0, movie);
    // Limit to 10 items
    if (list.length > 10) {
      list.removeRange(10, list.length);
    }
    historyNotifier.value = list;
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    historyNotifier.value = [];
    await _saveHistory();
  }
}
