import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/song_models.dart';
import '../models/bible_verse_model.dart';

class CacheService {
  static const String songsBoxName = 'songsCacheBox';
  static const String bibleBoxName = 'bibleCacheBox';

  Future<Box> _openSongsBox() async {
    if (!Hive.isBoxOpen(songsBoxName)) {
      return await Hive.openBox(songsBoxName);
    }
    return Hive.box(songsBoxName);
  }

  Future<Box> _openBibleBox() async {
    if (!Hive.isBoxOpen(bibleBoxName)) {
      return await Hive.openBox(bibleBoxName);
    }
    return Hive.box(bibleBoxName);
  }

  // Return List<Song> instead of List<dynamic>
  Future<List<Song>> getPagedSongsCache(String key) async {
    final box = await _openSongsBox();
    final jsonString = box.get(key);

    if (jsonString == null) return [];

    try {
      final List<dynamic> rawList = jsonDecode(jsonString);
      return rawList
          .map((json) => Song.fromMap(Map<String, dynamic>.from(json), json['id'] as String))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Accept List<Song> instead of List<dynamic>
  Future<void> setPagedSongsCache(String key, List<Song> songs) async {
    final box = await _openSongsBox();
    final jsonList = songs.map((s) => s.toMap()..['id'] = s.id).toList();
    await box.put(key, jsonEncode(jsonList));
  }

  // Return List<BibleVerse> instead of List<dynamic>
  Future<List<BibleVerse>> getPagedBibleCache(String key) async {
    final box = await _openBibleBox();
    final jsonString = box.get(key);

    if (jsonString == null) return [];

    try {
      final List<dynamic> rawList = jsonDecode(jsonString);
      return rawList
          .map((json) => BibleVerse.fromMap(Map<String, dynamic>.from(json), json['id'] as String))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Accept List<BibleVerse> instead of List<dynamic>
  Future<void> setPagedBibleCache(String key, List<BibleVerse> verses) async {
    final box = await _openBibleBox();
    final jsonList = verses.map((v) => v.toMap()..['id'] = v.id).toList();
    await box.put(key, jsonEncode(jsonList));
  }

  Future<void> clearAllCache() async {
    if (Hive.isBoxOpen(songsBoxName)) await Hive.box(songsBoxName).clear();
    if (Hive.isBoxOpen(bibleBoxName)) await Hive.box(bibleBoxName).clear();
  }

  Future<Map<String, int>> getCacheStats() async {
    final Map<String, int> stats = {
      'songs': 0,
      'bible_verses': 0,
      'search_results': 0, // Added for compatibility
    };

    if (Hive.isBoxOpen(songsBoxName)) {
      final box = Hive.box(songsBoxName);
      stats['songs'] = box.length;
    }
    if (Hive.isBoxOpen(bibleBoxName)) {
      final box = Hive.box(bibleBoxName);
      stats['bible_verses'] = box.length;
    }
    return stats;
  }
}
