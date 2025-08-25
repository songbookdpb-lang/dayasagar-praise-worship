import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/song_models.dart';

class PersistentCacheService {
  static final PersistentCacheService _instance = PersistentCacheService._internal();
  factory PersistentCacheService() => _instance;
  PersistentCacheService._internal();

 
  Future<void> initialize() async {
   
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      print('Initialize cache error: $e');
    }
  }

  Future<File> _getCacheFile(String key) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/cache_$key.json');
  }

  Future<bool> delete(String key) async {
    try {
      final file = await _getCacheFile(key);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Cache delete error for key $key: $e');
      return false;
    }
  }

  Future<bool> cacheSongs(String key, List<Song> songs) async {
    try {
      final file = await _getCacheFile(key);
      final cacheData = {
        'songs': songs.map((song) => song.toMap()).toList(),
        'cachedAt': DateTime.now().toIso8601String(),
        'totalCount': songs.length,
        'lastUpdatedAt': songs.isNotEmpty 
            ? songs.map((s) => s.updatedAt.millisecondsSinceEpoch).reduce((a, b) => a > b ? a : b)
            : DateTime.now().millisecondsSinceEpoch,
      };
      
      await file.writeAsString(jsonEncode(cacheData));
      return true;
    } catch (e) {
      print('Cache songs error for key $key: $e');
      return false;
    }
  }

  Future<List<Song>> getCachedSongs(String key) async {
    try {
      final file = await _getCacheFile(key);
      if (!await file.exists()) return [];
      
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);
      
      if (data is Map<String, dynamic> && data.containsKey('songs')) {
        final songsData = data['songs'] as List;
        return songsData.map((songMap) => Song.fromMap(songMap)).toList();
      }
      
      return [];
    } catch (e) {
      print('Get cached songs error for key $key: $e');
      return [];
    }
  }

  Future<bool> mergeSongsToCache(String key, List<Song> newSongs) async {
    try {
      final existingSongs = await getCachedSongs(key);
      final Map<String, Song> songMap = {
        for (var song in existingSongs) song.id: song
      };
      
      for (var newSong in newSongs) {
        songMap[newSong.id] = newSong;
      }
      
      final mergedSongs = songMap.values.toList();
      return await cacheSongs(key, mergedSongs);
    } catch (e) {
      print('Merge songs to cache error for key $key: $e');
      return false;
    }
  }

  Future<List<Song>> getCachedSongsByLanguage(String language) async {
    final key = 'songs_$language';
    return await getCachedSongs(key);
  }

  Future<bool> cacheSongsByLanguage(String language, List<Song> songs) async {
    final key = 'songs_$language';
    return await cacheSongs(key, songs);
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
      final dir = await getApplicationDocumentsDirectory();
      final cachedFiles = dir.listSync().where((f) => 
        f.path.contains('cache_songs_') && f.path.endsWith('.json')
      );
      
      final languages = <String>[];
      for (final file in cachedFiles) {
        final fileName = file.path.split('/').last;
        final match = RegExp(r'cache_songs_(.+)\.json').firstMatch(fileName);
        if (match != null) {
          languages.add(match.group(1)!);
        }
      }
      
      return languages..sort();
    } catch (e) {
      print('Get cached languages error: $e');
      return [];
    }
  }

  Future<bool> saveLastSyncTimestamp(String collection, int timestamp) async {
    try {
      final key = 'last_sync_$collection';
      final file = await _getCacheFile(key);
      final data = {
        'lastSync': timestamp,
        'collection': collection,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      await file.writeAsString(jsonEncode(data));
      return true;
    } catch (e) {
      print('Save last sync timestamp error for $collection: $e');
      return false;
    }
  }

  Future<int?> getLastSyncTimestamp(String collection) async {
    try {
      final key = 'last_sync_$collection';
      final file = await _getCacheFile(key);
      if (!await file.exists()) return null;
      
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);
      
      if (data is Map<String, dynamic> && data.containsKey('lastSync')) {
        return data['lastSync'] as int?;
      }
      
      return null;
    } catch (e) {
      print('Get last sync timestamp error for $collection: $e');
      return null;
    }
  }
  Future<void> clearSyncTimestamp(String collection) async {
    try {
      final key = 'last_sync_$collection';
      final file = await _getCacheFile(key);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Clear sync timestamp error for $collection: $e');
    }
  }

  Future<bool> setLastSyncTimestamp(String collection, DateTime timestamp) async {
    return await saveLastSyncTimestamp(collection, timestamp.millisecondsSinceEpoch);
  }

  Future<DateTime?> getLastSyncTimestampAsDateTime(String collection) async {
    final timestamp = await getLastSyncTimestamp(collection);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    final dir = await getApplicationDocumentsDirectory();
    final cachedFiles = dir.listSync().where((f) => f.path.contains('cache_')).toList();
    
    int schedules = 0;
    int songs = 0;
    int syncTimestamps = 0;
    int other = 0;
    
    for (final file in cachedFiles) {
      final fileName = file.path.split('/').last;
      if (fileName.contains('schedule')) {
        schedules++;
      } else if (fileName.contains('songs_')) {
        songs++;
      } else if (fileName.contains('last_sync_')) {
        syncTimestamps++;
      } else {
        other++;
      }
    }
    
    return {
      'total_files': cachedFiles.length,
      'schedules': schedules,
      'songs': songs,
      'sync_timestamps': syncTimestamps,
      'other': other,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  Future<void> cacheSchedule(String key, String scheduleText) async {
    final file = await _getCacheFile(key);
    await file.writeAsString(jsonEncode({
      'text': scheduleText,
      'cachedAt': DateTime.now().toIso8601String(),
    }));
  }

  Future<String?> getCachedSchedule(String key) async {
    final file = await _getCacheFile(key);
    if (!await file.exists()) return null;
    
    try {
      final data = jsonDecode(await file.readAsString());
      return data['text'] as String?;
    } catch (e) {
      print('Error reading cached schedule for key $key: $e');
      return null;
    }
  }

  Future<void> clearAllCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final cachedFiles = dir.listSync().where((f) => f.path.contains('cache_'));
    for (final file in cachedFiles) {
      if (file is File) {
        try {
          await file.delete();
        } catch (e) {
          print('Error deleting cache file ${file.path}: $e');
        }
      }
    }
  }

  Future<double> getCacheSizeMB() async {
    final dir = await getApplicationDocumentsDirectory();
    final cachedFiles = dir.listSync().where((f) => f.path.contains('cache_')).toList();
    int totalBytes = 0;
    
    for (final file in cachedFiles) {
      if (file is File) {
        try {
          totalBytes += await file.length();
        } catch (e) {
          print('Error getting file size for ${file.path}: $e');
        }
      }
    }
    
    return totalBytes / (1024 * 1024);
  }

  Future<List<Song>> getPagedSongsCache(String key) async {
    return await getCachedSongs(key);
  }

  Future<bool> setPagedSongsCache(String key, List<Song> songs) async {
    return await cacheSongs(key, songs);
  }
}
