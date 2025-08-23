import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/song_models.dart';

class CacheService {
  static const String songsBoxName = 'songsCacheBox';
  static const String syncBoxName = 'syncTimestampBox';

  Future<void> initialize() async {
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

  Future<List<Song>> getPagedSongsCache(String key) async {
    final box = await _openSongsBox();
    final jsonString = box.get(key);

    if (jsonString == null) return [];

    try {
      final List<dynamic> rawList = jsonDecode(jsonString);
      return rawList
          .map((json) => Song.fromMap(Map<String, dynamic>.from(json)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setPagedSongsCache(String key, List<Song> songs) async {
    final box = await _openSongsBox();
    final jsonList = songs.map((s) => s.toMap()).toList();
    await box.put(key, jsonEncode(jsonList));
  }

  Future<void> cacheSongsByLanguage(String language, List<Song> songs) async {
    final key = 'songs_$language';
    await setPagedSongsCache(key, songs);
  }

  Future<List<Song>> getCachedSongsByLanguage(String language) async {
    final key = 'songs_$language';
    return await getPagedSongsCache(key);
  }

  Future<void> mergeSongsToCache(String key, List<Song> newSongs) async {
    final existingSongs = await getPagedSongsCache(key);
    final Map<String, Song> songMap = {
      for (var song in existingSongs) song.id: song
    };
    
    for (var newSong in newSongs) {
      songMap[newSong.id] = newSong;
    }
    
    final mergedSongs = songMap.values.toList();
    await setPagedSongsCache(key, mergedSongs);
  }
  Future<List<Song>> searchCachedSongs(String query, {String? language}) async {
    try {
      List<Song> allSongs = [];
      
      if (language != null) {
        allSongs = await getCachedSongsByLanguage(language);
      } else {
        final languages = await getCachedLanguages();
        for (final lang in languages) {
          final songs = await getCachedSongsByLanguage(lang);
          allSongs.addAll(songs);
        }
      }
      
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

  Future<List<Song>> getAllCachedSongs() async {
    final languages = await getCachedLanguages();
    final allSongs = <Song>[];
    
    for (final language in languages) {
      final songs = await getCachedSongsByLanguage(language);
      allSongs.addAll(songs);
    }
    
    return allSongs;
  }

  Future<void> saveLastSyncTimestamp(String collection, int timestamp) async {
    final box = await _openSyncBox();
    await box.put('last_sync_$collection', timestamp);
  }

  Future<int?> getLastSyncTimestamp(String collection) async {
    final box = await _openSyncBox();
    final timestamp = box.get('last_sync_$collection');
    
    if (timestamp != null && timestamp is int) {
      return timestamp;
    }
    
    return null;
  }

  Future<void> setLastSyncTimestamp(String collection, DateTime timestamp) async {
    await saveLastSyncTimestamp(collection, timestamp.millisecondsSinceEpoch);
  }
  Future<DateTime?> getLastSyncTimestampAsDateTime(String collection) async {
    final timestamp = await getLastSyncTimestamp(collection);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  Future<void> clearSyncTimestamp(String collection) async {
    final box = await _openSyncBox();
    await box.delete('last_sync_$collection');
  }


  Future<void> clearAllCache() async {
    if (Hive.isBoxOpen(songsBoxName)) await Hive.box(songsBoxName).clear();
    if (Hive.isBoxOpen(syncBoxName)) await Hive.box(syncBoxName).clear();
  }
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
  Future<int> getTotalCachedSongsCount() async {
    final allSongs = await getAllCachedSongs();
    return allSongs.where((song) => !song.isDeleted).length;
  }

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

  Future<void> clearLanguageCache(String language) async {
    final key = 'songs_$language';
    final box = await _openSongsBox();
    await box.delete(key);
  }

  Future<bool> isLanguageCached(String language) async {
    final languages = await getCachedLanguages();
    return languages.contains(language);
  }
  Future<int> getCacheSizeBytes() async {
    try {
      final box = await _openSongsBox();
      int totalSize = 0;
      
      for (final key in box.keys) {
        final value = box.get(key);
        if (value is String) {
          totalSize += value.length * 2; 
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Get cache size error: $e');
      return 0;
    }
  }

  Future<double> getCacheSizeMB() async {
    final sizeBytes = await getCacheSizeBytes();
    return sizeBytes / (1024 * 1024);
  }
}
