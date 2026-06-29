import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';

/// Caches all 14 home-screen rows in SharedPreferences.
/// Cache expires after [_ttlHours] hours (default 24h).
class HomeCacheService {
  static const _key     = 'home_cache_v2';
  static const _tsKey   = 'home_cache_ts_v2';
  static const _ttlHours = 24;

  static Future<Map<String, List<Movie>>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_tsKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      // Expire after TTL
      if (now - ts > _ttlHours * 3600 * 1000) return null;

      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final Map<String, dynamic> decoded = json.decode(raw);
      return decoded.map((k, v) {
        final list = (v as List).map((e) => Movie.fromJson(e)).toList();
        return MapEntry(k, list);
      });
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Map<String, List<Movie>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(
        data.map((k, v) => MapEntry(k, v.map((m) => m.toJson()).toList())),
      );
      await prefs.setString(_key, encoded);
      await prefs.setInt(_tsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_tsKey);
  }
}
