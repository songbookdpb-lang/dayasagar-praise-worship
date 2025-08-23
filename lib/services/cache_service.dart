import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/song_models.dart';

class CacheService {
  static const String songsBoxName = 'songsCacheBox';
  static const String syncBoxName = 'syncTimestampBox';

  // ✅ ADDED: Missing initialize method
  Future<void> initialize() async {
    // Initialize Hive if not already initialized
    // This method can be empty since Hive boxes are opened on demand
  }

  Future<Box> _openSongsBox() async {
    if (!Hive.isBoxOpen(songsBoxName)) {
      return await Hive.openBox(songsBoxName);
    }
    return Hive.box(songsBoxName);
  }

  Future<Box> _openSyncBox() async {
    if (!Hive.isBoxOpen(syncBoxName)) {
      return await Hive.openBox(syncBoxName);
    }
    return Hive.box(syncBoxName);
  }

  // ============================================================================
  // SONG CACHING METHODS (STORED FOREVER FOR OFFLINE ACCESS)
  // ============================================================================

  /// ✅ Get cached songs by key (stored forever locally)
  Future<List<Song>> getPagedSongsCache(String key) async {
    final box = await _openSongsBox();
    final jsonString = box.get(key);

    if (jsonString == null) return [];

    try {
      final List<dynamic> rawList = jsonDecode(jsonString);
      // ✅ FIXED: Use single parameter Song.fromMap
      return rawList
          .map((json) => Song.fromMap(Map<String, dynamic>.from(json)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// ✅ Cache songs by key (stored forever locally)
  Future<void> setPagedSongsCache(String key, List<Song> songs) async {
    final box = await _openSongsBox();
    final jsonList = songs.map((s) => s.toMap()).toList();
    await box.put(key, jsonEncode(jsonList));
  }

  /// ✅ NEW: Cache songs by language (for organized storage)
  Future<void> cacheSongsByLanguage(String language, List<Song> songs) async {
    final key = 'songs_$language';
    await setPagedSongsCache(key, songs);
  }

  /// ✅ NEW: Get cached songs by language
  Future<List<Song>> getCachedSongsByLanguage(String language) async {
    final key = 'songs_$language';
    return await getPagedSongsCache(key);
  }

  /// ✅ NEW: Merge new songs with existing cached songs (for incremental sync)
  Future<void> mergeSongsToCache(String key, List<Song> newSongs) async {
    // Get existing cached songs
    final existingSongs = await getPagedSongsCache(key);
    final Map<String, Song> songMap = {
      for (var song in existingSongs) song.id: song
    };
    
    // Merge new songs (overwrite existing ones with same ID)
    for (var newSong in newSongs) {
      songMap[newSong.id] = newSong;
    }
    
    // Cache merged results
    final mergedSongs = songMap.values.toList();
    await setPagedSongsCache(key, mergedSongs);
  }

  /// ✅ NEW: Search cached songs offline (works without internet)
  Future<List<Song>> searchCachedSongs(String query, {String? language}) async {
    try {
      List<Song> allSongs = [];
      
      if (language != null) {
        // Search in specific language cache
        allSongs = await getCachedSongsByLanguage(language);
      } else {
        // Search across all cached languages
        final languages = await getCachedLanguages();
        for (final lang in languages) {
          final songs = await getCachedSongsByLanguage(lang);
          allSongs.addAll(songs);
        }
      }
      
      // Filter by query and exclude deleted songs
      final queryLower = query.toLowerCase();
      return allSongs.where((song) => 
        !song.isDeleted &&
        (song.songName.toLowerCase().contains(queryLower) ||
         song.lyrics.toLowerCase().contains(queryLower))
      ).toList();
    } catch (e) {
      print('Search cached songs error: $e');
      return [];
    }
  }

  /// ✅ NEW: Get list of cached languages
  Future<List<String>> getCachedLanguages() async {
    try {
      final box = await _openSongsBox();
      final keys = box.keys.where((key) => key.toString().startsWith('songs_'));
      
      final languages = <String>[];
      for (final key in keys) {
        final language = key.toString().replaceFirst('songs_', '');
        if (language.isNotEmpty) {
          languages.add(language);
        }
      }
      
      return languages..sort();
    } catch (e) {
      print('Get cached languages error: $e');
      return [];
    }
  }

  /// ✅ NEW: Get all cached songs (across all languages)
  Future<List<Song>> getAllCachedSongs() async {
    final languages = await getCachedLanguages();
    final allSongs = <Song>[];
    
    for (final language in languages) {
      final songs = await getCachedSongsByLanguage(language);
      allSongs.addAll(songs);
    }
    
    return allSongs;
  }

  // ============================================================================
  // SYNC TIMESTAMP MANAGEMENT (FOR INCREMENTAL SYNC)
  // ============================================================================

  /// ✅ UPDATED: Store last sync timestamp as int for incremental sync compatibility
  Future<void> saveLastSyncTimestamp(String collection, int timestamp) async {
    final box = await _openSyncBox();
    await box.put('last_sync_$collection', timestamp);
  }

  /// ✅ UPDATED: Get last sync timestamp as int for incremental sync compatibility
  Future<int?> getLastSyncTimestamp(String collection) async {
    final box = await _openSyncBox();
    final timestamp = box.get('last_sync_$collection');
    
    if (timestamp != null && timestamp is int) {
      return timestamp;
    }
    
    return null;
  }

  /// ✅ KEPT: Original DateTime version for backward compatibility
  Future<void> setLastSyncTimestamp(String collection, DateTime timestamp) async {
    await saveLastSyncTimestamp(collection, timestamp.millisecondsSinceEpoch);
  }

  /// ✅ ADDED: Get DateTime version for backward compatibility
  Future<DateTime?> getLastSyncTimestampAsDateTime(String collection) async {
    final timestamp = await getLastSyncTimestamp(collection);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// ✅ NEW: Clear sync timestamp
  Future<void> clearSyncTimestamp(String collection) async {
    final box = await _openSyncBox();
    await box.delete('last_sync_$collection');
  }

  // ============================================================================
  // CACHE MANAGEMENT & STATISTICS
  // ============================================================================

  /// Clear all song caches (but keep them forever by default)
  Future<void> clearAllCache() async {
    if (Hive.isBoxOpen(songsBoxName)) await Hive.box(songsBoxName).clear();
    if (Hive.isBoxOpen(syncBoxName)) await Hive.box(syncBoxName).clear();
  }

  /// ✅ UPDATED: Get cache statistics (songs only)
  Future<Map<String, int>> getCacheStats() async {
    final Map<String, int> stats = {
      'songs': 0,
      'languages': 0,
      'sync_timestamps': 0,
    };

    if (Hive.isBoxOpen(songsBoxName)) {
      final songsBox = Hive.box(songsBoxName);
      stats['songs'] = songsBox.length;
      stats['languages'] = (await getCachedLanguages()).length;
    }

    if (Hive.isBoxOpen(syncBoxName)) {
      final syncBox = Hive.box(syncBoxName);
      stats['sync_timestamps'] = syncBox.length;
    }

    return stats;
  }

  /// ✅ NEW: Get total number of cached songs across all languages
  Future<int> getTotalCachedSongsCount() async {
    final allSongs = await getAllCachedSongs();
    return allSongs.where((song) => !song.isDeleted).length;
  }

  /// ✅ NEW: Get cache size information
  Future<Map<String, dynamic>> getCacheInfo() async {
    final stats = await getCacheStats();
    final totalSongs = await getTotalCachedSongsCount();
    final languages = await getCachedLanguages();
    
    return {
      'total_active_songs': totalSongs,
      'cached_languages': languages,
      'languages_count': languages.length,
      'cache_files': stats['songs'],
      'sync_timestamps': stats['sync_timestamps'],
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================================
  // ADDITIONAL UTILITY METHODS
  // ============================================================================

  /// ✅ ADDED: Delete specific language cache
  Future<void> clearLanguageCache(String language) async {
    final key = 'songs_$language';
    final box = await _openSongsBox();
    await box.delete(key);
  }

  /// ✅ ADDED: Check if language is cached
  Future<bool> isLanguageCached(String language) async {
    final languages = await getCachedLanguages();
    return languages.contains(language);
  }

  /// ✅ ADDED: Get cache size in bytes (approximate)
  Future<int> getCacheSizeBytes() async {
    try {
      final box = await _openSongsBox();
      int totalSize = 0;
      
      for (final key in box.keys) {
        final value = box.get(key);
        if (value is String) {
          totalSize += value.length * 2; // Approximate UTF-16 encoding
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Get cache size error: $e');
      return 0;
    }
  }

  /// ✅ ADDED: Get cache size in MB
  Future<double> getCacheSizeMB() async {
    final sizeBytes = await getCacheSizeBytes();
    return sizeBytes / (1024 * 1024);
  }
}
