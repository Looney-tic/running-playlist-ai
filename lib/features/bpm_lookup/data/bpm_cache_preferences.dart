import 'dart:convert';

import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache for BPM lookup results in SharedPreferences.
///
/// Stores results as JSON strings, keyed by **queried BPM** (not target BPM).
/// Each entry includes a timestamp for TTL-based expiry.
///
/// Songs are cached **without** matchType. The match type is contextual and
/// must be assigned at load time based on the relationship between the cached
/// BPM and the current target BPM.
class BpmCachePreferences {
  static const _prefix = 'bpm_cache_';

  /// Cache time-to-live: 7 days.
  static const cacheTtl = Duration(days: 7);

  /// Loads cached songs for a [bpm] value, or null if not cached / expired.
  ///
  /// Returns songs with [BpmMatchType.exact] as the default matchType.
  /// The caller is responsible for reassigning the correct matchType.
  static Future<List<BpmSong>?> load(int bpm) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_prefix$bpm');
    if (jsonString == null) return null;

    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    // Check TTL
    final cachedAt = DateTime.parse(json['cachedAt'] as String);
    if (DateTime.now().difference(cachedAt) > cacheTtl) {
      await prefs.remove('$_prefix$bpm');
      return null;
    }

    final songs = (json['songs'] as List<dynamic>)
        .map((s) => BpmSong.fromJson(s as Map<String, dynamic>))
        .toList();
    return songs;
  }

  /// Saves songs for a [bpm] value with a timestamp.
  ///
  /// Songs are stored via [BpmSong.toJson], which excludes matchType.
  static Future<void> save(int bpm, List<BpmSong> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final json = {
      'cachedAt': DateTime.now().toIso8601String(),
      'songs': songs.map((s) => s.toJson()).toList(),
    };
    await prefs.setString('$_prefix$bpm', jsonEncode(json));
  }

  /// Clears a specific BPM cache entry.
  static Future<void> clear(int bpm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$bpm');
  }

  /// Clears all BPM cache entries.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
