import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:running_playlist_ai/features/curated_songs/domain/curated_song.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for curated running songs with three-tier loading.
///
/// Loading priority:
/// 1. SharedPreferences cache (check 24h TTL)
/// 2. Supabase remote fetch (refresh cache on success)
/// 3. Bundled JSON asset fallback (always available)
///
/// This ensures the app always has curated data, even on first launch
/// offline. Supabase is the refresh mechanism, not the primary source.
class CuratedSongRepository {
  static const _cacheKey = 'curated_songs_cache';

  /// Cache time-to-live: 24 hours.
  static const cacheTtl = Duration(hours: 24);

  /// Loads curated songs using three-tier strategy.
  ///
  /// Returns cached songs if cache is valid (< 24h old), otherwise
  /// tries Supabase refresh. Falls back to bundled JSON asset if
  /// both cache and Supabase are unavailable.
  static Future<List<CuratedSong>> loadCuratedSongs() async {
    // Tier 1: Try SharedPreferences cache
    final cached = await _loadFromCache();
    if (cached != null) return cached;

    // Tier 2: Try Supabase fetch
    final remote = await _fetchFromSupabase();
    if (remote != null) {
      await _saveToCache(remote);
      return remote;
    }

    // Tier 3: Load bundled JSON asset (always available)
    return _loadBundledAsset();
  }

  /// Builds a lookup key set from curated songs for scoring.
  ///
  /// Returns a `Set<String>` of normalized `'artist|title'` keys
  /// for O(1) membership checks during playlist scoring.
  static Set<String> buildLookupSet(List<CuratedSong> songs) {
    return songs.map((s) => s.lookupKey).toSet();
  }

  /// Loads curated songs from SharedPreferences cache.
  ///
  /// Returns null if cache is empty or expired (> 24h old).
  static Future<List<CuratedSong>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_cacheKey);
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      // Check TTL
      final cachedAt = DateTime.parse(json['cachedAt'] as String);
      if (DateTime.now().difference(cachedAt) > cacheTtl) {
        await prefs.remove(_cacheKey);
        return null;
      }

      final songs = (json['songs'] as List<dynamic>)
          .map((s) => CuratedSong.fromJson(s as Map<String, dynamic>))
          .toList();
      return songs;
    } on Exception {
      return null;
    }
  }

  /// Fetches curated songs from Supabase.
  ///
  /// Returns null on any failure (network error, table not found,
  /// auth error, etc.) for graceful degradation.
  static Future<List<CuratedSong>?> _fetchFromSupabase() async {
    try {
      final response = await Supabase.instance.client
          .from('curated_songs')
          .select();
      return (response as List<dynamic>)
          .map(
            (row) =>
                CuratedSong.fromSupabaseRow(row as Map<String, dynamic>),
          )
          .toList();
      // ignore: avoid_catches_without_on_clauses, Supabase.instance throws AssertionError (Error, not Exception) when not initialized.
    } catch (_) {
      return null;
    }
  }

  /// Loads curated songs from the bundled JSON asset.
  ///
  /// This is the ultimate fallback -- the app always has curated data,
  /// even on first launch offline.
  static Future<List<CuratedSong>> _loadBundledAsset() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/curated_songs.json');
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) => CuratedSong.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Failed to load bundled curated_songs.json: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Saves curated songs to SharedPreferences cache with timestamp.
  static Future<void> _saveToCache(List<CuratedSong> songs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = {
        'cachedAt': DateTime.now().toIso8601String(),
        'songs': songs.map((s) => s.toJson()).toList(),
      };
      await prefs.setString(_cacheKey, jsonEncode(json));
    } on Exception {
      // Cache save failure is non-critical; ignore silently
    }
  }
}
