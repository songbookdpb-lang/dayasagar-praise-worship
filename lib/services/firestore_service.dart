// lib/services/firestore_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_models.dart';
import '../models/bible_verse_model.dart';
import '../models/schedule_model.dart';
import 'cache_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  FirebaseFirestore get _firestore => _db;

  // Keep online collections for songs and schedules
  CollectionReference get _songsCollection => _db.collection('songs');
  CollectionReference get _schedulesCollection => _db.collection('schedules');

  // ============================================================================
  // OFFLINE BIBLE SUPPORT HELPERS
  // ============================================================================

  bool _isEnglishLocal(String language) {
    final lang = language.trim().toLowerCase();
    return lang == 'english' || lang == 'en-english';
  }

  bool _isHindiLocal(String language) {
    final lang = language.trim().toLowerCase();
    return lang.startsWith('hi') || lang == 'hindi';
  }

  bool _isOdiaLocal(String language) {
    final lang = language.trim().toLowerCase();
    return lang.startsWith('od') || lang.startsWith('or') || lang == 'odia';
  }

  bool _isLocalBibleLanguage(String language) =>
      _isEnglishLocal(language) ||
      _isHindiLocal(language) ||
      _isOdiaLocal(language);

  String _getAssetPath(String language) {
    if (_isEnglishLocal(language)) {
      return 'assets/bible/EN-English/asv.json';
    } else if (_isHindiLocal(language)) {
      return 'assets/bible/HI-Hindi/asv.json';
    } else if (_isOdiaLocal(language)) {
      return 'assets/bible/OD-Odia/asv.json';
    } else {
      return 'assets/bible/EN-English/asv.json'; // Fallback
    }
  }

  Future<List<dynamic>> _loadBibleFromAsset(String language) async {
    try {
      final assetPath = _getAssetPath(language);
      final raw = await rootBundle.loadString(assetPath);
      
      final dynamic jsonData = json.decode(raw);
      
      if (jsonData is List) {
        return jsonData;
      } else if (jsonData is Map<String, dynamic>) {
        return (jsonData['verses'] as List<dynamic>? ?? []);
      } else {
        throw Exception('Unexpected JSON structure: ${jsonData.runtimeType}');
      }
    } catch (e) {
      debugPrint('Error loading $language Bible from asset: $e');
      return [];
    }
  }

  // ========== SONG METHODS (ONLINE - UNCHANGED) ==========
  Future<String> addSong(Song song) async {
    final doc = await _songsCollection.add(song.toFirestore());
    return doc.id;
  }

  Stream<List<Song>> getSongs() {
    return _songsCollection
        .orderBy('songName')
        .snapshots()
        .map((s) => s.docs.map(Song.fromFirestore).toList());
  }

  Stream<List<Song>> getSongsByLanguage(String language) {
    return _songsCollection
        .where('language', isEqualTo: language)
        .orderBy('songName')
        .snapshots()
        .map((s) => s.docs.map(Song.fromFirestore).toList());
  }

  Future<List<Song>> searchSongs(String query, String language) async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .where('language', isEqualTo: language)
          .orderBy('songName')
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => Song.fromFirestore(doc))
          .where((song) =>
              song.songName.toLowerCase().contains(query.toLowerCase()) ||
              song.lyrics.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      throw Exception('Failed to search songs: $e');
    }
  }

  Future<List<Song>> searchAllSongs(String query) async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .orderBy('songName')
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => Song.fromFirestore(doc))
          .where((song) =>
              song.songName.toLowerCase().contains(query.toLowerCase()) ||
              song.lyrics.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      throw Exception('Failed to search all songs: $e');
    }
  }

  Future<List<Song>> getSongsByLanguagePaginated(
    String language, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('songs')
          .where('language', isEqualTo: language)
          .orderBy('songName')
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Song.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get songs by language: $e');
    }
  }

  Future<void> updateSong(String id, Song song) async => 
      _songsCollection.doc(id).update(song.toFirestore());
  
  Future<void> deleteSong(String id) async => 
      _songsCollection.doc(id).delete();

  Future<List<Song>> _getPaginatedSongs(String language, int limit, DocumentSnapshot? last) async {
    var q = _songsCollection
        .where('language', isEqualTo: language)
        .orderBy('songName')
        .limit(limit);
    if (last != null) q = q.startAfterDocument(last);
    final snap = await q.get();
    return snap.docs.map(Song.fromFirestore).toList();
  }

  Future<List<Song>> getPaginatedSongsCacheFirst(String language,
      {int page = 0, int limit = 40, required CacheService cacheService}) async {
    final key = 'cached_songs_${language}_page_$page';
    final cached = await cacheService.getPagedSongsCache(key);
    if (cached.isNotEmpty) {
      _getPaginatedSongs(language, limit, null)
          .then((fresh) => cacheService.setPagedSongsCache(key, fresh))
          .catchError((e) => print('Background refresh failed: $e'));
      return cached;
    }
    final fresh = await _getPaginatedSongs(language, limit, null);
    await cacheService.setPagedSongsCache(key, fresh);
    return fresh;
  }

  Future<List<Song>> getPaginatedSongs(String language, {DocumentSnapshot? lastDoc}) =>
      _getPaginatedSongs(language, 40, lastDoc);

  Future<List<String>> getAvailableSongLanguages() async {
    final snap = await _songsCollection.get();
    return {
      for (var d in snap.docs) 
        (d.data() as Map)['language']
    }.whereType<String>().toList()..sort();
  }

  Future<List<Song>> getSongsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    final batches = <List<String>>[];
    for (int i = 0; i < ids.length; i += 10) {
      batches.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }
    
    final List<Song> songs = [];
    for (final batch in batches) {
      final snap = await _songsCollection
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      songs.addAll(snap.docs.map(Song.fromFirestore));
    }
    
    return songs;
  }

  Stream<Song?> getSongById(String id) => 
      _songsCollection
          .doc(id)
          .snapshots()
          .map((d) => d.exists ? Song.fromFirestore(d) : null);

  Future<Song?> getSongByIdOnce(String id) async {
    final doc = await _songsCollection.doc(id).get();
    return doc.exists ? Song.fromFirestore(doc) : null;
  }

  Future<List<Song>> searchSongsAdvanced({
    String? query,
    String? language,
    int limit = 50,
  }) async {
    try {
      Query firestoreQuery = _firestore.collection('songs');
      
      if (language != null && language.isNotEmpty) {
        firestoreQuery = firestoreQuery.where('language', isEqualTo: language);
      }
      
      firestoreQuery = firestoreQuery.orderBy('songName').limit(limit);
      
      final snapshot = await firestoreQuery.get();
      List<Song> songs = snapshot.docs.map(Song.fromFirestore).toList();
      
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        songs = songs.where((song) =>
            song.songName.toLowerCase().contains(queryLower) ||
            song.lyrics.toLowerCase().contains(queryLower)).toList();
      }
      
      return songs;
    } catch (e) {
      throw Exception('Failed to search songs: $e');
    }
  }

  Future<void> bulkAddSongs(List<Song> songs) async {
    final batch = _firestore.batch();
    
    for (final song in songs) {
      final docRef = _songsCollection.doc();
      batch.set(docRef, song.toFirestore());
    }
    
    await batch.commit();
  }

  Future<List<Song>> getSongsWithCache({
    String? language,
    bool useCache = true,
  }) async {
    try {
      Query query = _firestore.collection('songs');
      
      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }
      
      query = query.orderBy('songName');
      
      final snapshot = await query.get(GetOptions(
        source: useCache ? Source.cache : Source.server,
      ));
      
      return snapshot.docs.map(Song.fromFirestore).toList();
    } catch (e) {
      if (useCache) {
        throw Exception('Failed to get songs: $e');
      } else {
        return getSongsWithCache(language: language, useCache: true);
      }
    }
  }

  // ========== BIBLE VERSE METHODS (OFFLINE - MODIFIED) ==========

  // ✅ UPDATED: Bible verses now load from local assets
  Stream<List<BibleVerse>> getBibleVerses() {
    // Default to English for general Bible verses
    return Stream.fromFuture(_getBibleVersesFromAsset('English'));
  }

  Stream<List<BibleVerse>> getBibleVersesByLanguageStream(String language) {
    return Stream.fromFuture(_getBibleVersesFromAsset(language));
  }

  Stream<List<BibleVerse>> getBibleVersesByLanguage(String language) {
    return Stream.fromFuture(_getBibleVersesFromAsset(language));
  }

  Stream<List<BibleVerse>> searchBibleByBookAndLanguage(String book, String language) {
    return Stream.fromFuture(_getBibleVersesFromAsset(language, book: book));
  }

  Future<List<BibleVerse>> searchBibleByBookAndLanguageOnce(String book, String language) async {
    return await _getBibleVersesFromAsset(language, book: book);
  }

  Stream<List<BibleVerse>> getBibleVersesByChapter(String language, String book, String chapter) {
    final chapterNum = int.tryParse(chapter);
    return Stream.fromFuture(_getBibleVersesFromAsset(language, book: book, chapter: chapterNum));
  }

  Future<List<BibleVerse>> getBibleVersesByChapterOnce(String language, String book, String chapter) async {
    final chapterNum = int.tryParse(chapter);
    return await _getBibleVersesFromAsset(language, book: book, chapter: chapterNum);
  }

  // ✅ NEW: Core method to get Bible verses from local assets
  Future<List<BibleVerse>> _getBibleVersesFromAsset(String language, {String? book, int? chapter}) async {
    try {
      if (!_isLocalBibleLanguage(language)) {
        // For unsupported languages, return empty list
        return [];
      }

      final List<dynamic> versesJson = await _loadBibleFromAsset(language);
      final List<BibleVerse> verses = [];

      for (final verse in versesJson) {
        if (verse is! Map<String, dynamic>) continue;
        
        final vBook = (verse['book_name'] ?? verse['book'] ?? '').toString();
        final vChapter = verse['chapter'];
        final vChapterNum = vChapter is int ? vChapter : int.tryParse(vChapter.toString());

        // Filter by book and chapter if specified
        bool shouldInclude = true;
        if (book != null && vBook != book) shouldInclude = false;
        if (chapter != null && vChapterNum != chapter) shouldInclude = false;

        if (shouldInclude) {
          final vText = (verse['text'] ?? verse['verse_text'] ?? verse['verse'] ?? '').toString();
          final vChapterStr = vChapterNum?.toString() ?? '';
          final vNum = (verse['verse'] ?? verse['verse_number'] ?? '1').toString();
          final id = 'local_${language}_${vBook}_${vChapterStr}_$vNum';

          verses.add(BibleVerse.fromMap({
            'id': id,
            'book': vBook,
            'chapter': vChapterStr,
            'verse': vText,
            'language': language,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          }, id));
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Loaded ${verses.length} verses from $language asset (book: $book, chapter: $chapter)');
      }
      return verses;
    } catch (e) {
      debugPrint('Error getting $language verses from asset: $e');
      return [];
    }
  }

  // ✅ UPDATED: Get Bible books from local assets
  Future<List<String>> getBibleBooks(String language) async {
    try {
      if (!_isLocalBibleLanguage(language)) {
        return [];
      }

      final List<dynamic> versesJson = await _loadBibleFromAsset(language);
      final Set<String> bookNames = {};

      for (final verse in versesJson) {
        if (verse is! Map<String, dynamic>) continue;
        
        final bookName = (verse['book_name'] ?? verse['book'] ?? '').toString();
        if (bookName.isNotEmpty) {
          bookNames.add(bookName);
        }
      }

      final books = bookNames.toList()..sort();
      return books;
    } catch (e) {
      throw Exception('Failed to get books for language: $e');
    }
  }

  // ✅ UPDATED: Get Bible chapters from local assets
  Future<List<int>> getBibleChapters(String language, String bookName) async {
    try {
      if (!_isLocalBibleLanguage(language)) {
        return [];
      }

      final List<dynamic> versesJson = await _loadBibleFromAsset(language);
      final Set<int> chapterNumbers = {};

      for (final verse in versesJson) {
        if (verse is! Map<String, dynamic>) continue;
        
        final vBook = (verse['book_name'] ?? verse['book'] ?? '').toString();
        final vChapter = verse['chapter'];

        if (vBook == bookName && vChapter != null) {
          final chapterNum = vChapter is int ? vChapter : int.tryParse(vChapter.toString());
          if (chapterNum != null && chapterNum > 0) {
            chapterNumbers.add(chapterNum);
          }
        }
      }

      final chapters = chapterNumbers.toList()..sort();
      return chapters;
    } catch (e) {
      throw Exception('Failed to get chapters for book $bookName in $language: $e');
    }
  }

  Future<List<String>> getBooksForLanguage(String language) async {
    return (await getBibleBooks(language));
  }

  Future<List<String>> getChaptersForBook(String language, String book) async {
    final chapters = await getBibleChapters(language, book);
    return chapters.map((c) => c.toString()).toList();
  }

Future<List<String>> getBibleBooksPaginated(
  String language, {
  int limit = 20,
  String? startAfter,
}) async {
  try {
    // ✅ FIXED: Use offline method instead of Firestore
    final allBooks = await getBibleBooks(language);
    
    int startIndex = 0;
    if (startAfter != null) {
      final afterIndex = allBooks.indexOf(startAfter);
      startIndex = afterIndex >= 0 ? afterIndex + 1 : 0;
    }
    
    final endIndex = (startIndex + limit).clamp(0, allBooks.length);
    return allBooks.sublist(startIndex, endIndex);
  } catch (e) {
    throw Exception('Failed to get paginated books for $language: $e');
  }
}

  Future<List<String>> getBibleChaptersPaginated(
  String language,
  String book, {
  int limit = 20,
  String? startAfter,
}) async {
  try {
    // ✅ FIXED: Use offline method instead of Firestore
    final allChapters = await getChaptersForBook(language, book);
    
    int startIndex = 0;
    if (startAfter != null) {
      final afterIndex = allChapters.indexOf(startAfter);
      startIndex = afterIndex >= 0 ? afterIndex + 1 : 0;
    }
    
    final endIndex = (startIndex + limit).clamp(0, allChapters.length);
    return allChapters.sublist(startIndex, endIndex);
  } catch (e) {
    throw Exception('Failed to get paginated chapters for $book in $language: $e');
  }
}

  Future<List<BibleVerse>> searchBibleVerses(String query, String language) async {
    try {
      final allVerses = await _getBibleVersesFromAsset(language);
      return allVerses
          .where((verse) =>
              verse.book.toLowerCase().contains(query.toLowerCase()) ||
              verse.chapter.toLowerCase().contains(query.toLowerCase()) ||
              verse.verse.toLowerCase().contains(query.toLowerCase()))
          .take(50)
          .toList();
    } catch (e) {
      throw Exception('Failed to search Bible verses: $e');
    }
  }

  Future<List<BibleVerse>> searchAllBibleVerses(String query) async {
    try {
      // Search across all supported languages
      final languages = ['English', 'Hindi', 'Odia'];
      final List<BibleVerse> allResults = [];
      
      for (final language in languages) {
        try {
          final results = await searchBibleVerses(query, language);
          allResults.addAll(results);
        } catch (e) {
          // Continue with other languages if one fails
          continue;
        }
      }
      
      return allResults.take(100).toList();
    } catch (e) {
      throw Exception('Failed to search all Bible verses: $e');
    }
  }

  Future<List<BibleVerse>> getBibleVersesByLanguagePaginated(
    String language, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final allVerses = await _getBibleVersesFromAsset(language);
      // For simplicity, return first 'limit' verses (can be enhanced with proper pagination)
      return allVerses.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get Bible verses: $e');
    }
  }

  Future<List<BibleVerse>> searchBibleVersesByBook(String bookName, String query) async {
    try {
      // Search in all supported languages for this book
      final languages = ['English', 'Hindi', 'Odia'];
      final List<BibleVerse> allResults = [];
      
      for (final language in languages) {
        try {
          final verses = await _getBibleVersesFromAsset(language, book: bookName);
          final results = verses
              .where((verse) => verse.verse.toLowerCase().contains(query.toLowerCase()))
              .toList();
          allResults.addAll(results);
        } catch (e) {
          continue;
        }
      }
      
      return allResults.take(50).toList();
    } catch (e) {
      throw Exception('Failed to search verses in book: $e');
    }
  }

  // ✅ REMOVED: These methods are no longer needed for offline Bible
  Future<String> addBibleVerse(BibleVerse verse) async {
    throw Exception('Adding Bible verses not supported in offline mode');
  }

  Future<void> updateBibleVerse(String id, BibleVerse verse) async {
    throw Exception('Updating Bible verses not supported in offline mode');
  }
  
  Future<void> deleteBibleVerse(String id) async {
    throw Exception('Deleting Bible verses not supported in offline mode');
  }

  Future<List<BibleVerse>> _getPaginatedBible(String language, int limit, DocumentSnapshot? last) async {
    // Return from local assets instead
    final verses = await _getBibleVersesFromAsset(language);
    return verses.take(limit).toList();
  }

  Future<List<BibleVerse>> getPaginatedBibleVersesCacheFirst(String language,
      {int page = 0, int limit = 40, required CacheService cacheService}) async {
    // For offline, just return from assets (caching handled by OS)
    return await _getBibleVersesFromAsset(language);
  }

  Future<List<BibleVerse>> getPaginatedBibleVerses(String language, {DocumentSnapshot? lastDoc}) =>
      _getBibleVersesFromAsset(language);

  // ✅ UPDATED: Available Bible languages (offline only)
  Future<List<String>> getAvailableBibleLanguages() async {
    // Return supported offline languages
    return ['English', 'Hindi', 'Odia'];
  }

  // ✅ FIXED: Critical error in getBibleVersesByIds method
  Future<List<BibleVerse>> getBibleVersesByIds(List<String> ids) async {
  final List<BibleVerse> verses = [];

  for (final id in ids) {
    if (id.startsWith('local_')) {
      final parts = id.split('_');

      // Ensure we have enough parts: local_language_book_chapter_verse
      if (parts.length >= 5) {
        final language = parts[1];

        // Chapter and verse number
        final chapterStr = parts[parts.length - 2];
        final verseNum = parts[parts.length - 1];

        // Book name (could contain underscores, so join remaining parts)
        final bookParts = parts.sublist(2, parts.length - 2);
        final book = bookParts.join('_');

        final chapter = int.tryParse(chapterStr);

        if (chapter != null) {
          // Load verses from asset
          final allVerses = await _getBibleVersesFromAsset(
            language,
            book: book,
            chapter: chapter,
          );

          // Find the exact verse
          final verse = allVerses.where((v) => v.id == id).firstOrNull;
          if (verse != null) {
            verses.add(verse);
          }
        }
      }
    }
  }

  return verses;
}


  Stream<BibleVerse?> getBibleVerseById(String id) =>
      Stream.fromFuture(_getBibleVerseByIdOnce(id));

  Future<BibleVerse?> getBibleVerseByIdOnce(String id) async {
    final verses = await getBibleVersesByIds([id]);
    return verses.isNotEmpty ? verses.first : null;
  }

  Future<BibleVerse?> _getBibleVerseByIdOnce(String id) async {
    if (id.startsWith('local_')) {
      final verses = await getBibleVersesByIds([id]);
      return verses.isNotEmpty ? verses.first : null;
    }
    return null;
  }

  Future<List<BibleVerse>> searchBibleVersesAdvanced({
    String? query,
    String? language,
    String? book,
    int limit = 50,
  }) async {
    try {
      final searchLanguage = language ?? 'English';
      List<BibleVerse> verses;
      
      if (book != null) {
        verses = await _getBibleVersesFromAsset(searchLanguage, book: book);
      } else {
        verses = await _getBibleVersesFromAsset(searchLanguage);
      }
      
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        verses = verses.where((verse) =>
            verse.book.toLowerCase().contains(queryLower) ||
            verse.chapter.toLowerCase().contains(queryLower) ||
            verse.verse.toLowerCase().contains(queryLower)).toList();
      }
      
      return verses.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to search Bible verses: $e');
    }
  }

  Future<void> bulkAddBibleVerses(List<BibleVerse> verses) async {
    throw Exception('Bulk adding Bible verses not supported in offline mode');
  }

  Future<List<BibleVerse>> getBibleVersesWithCache({
    String? language,
    String? book,
    String? chapter,
    bool useCache = true,
  }) async {
    try {
      final searchLanguage = language ?? 'English';
      final chapterNum = chapter != null ? int.tryParse(chapter) : null;
      
      return await _getBibleVersesFromAsset(
        searchLanguage,
        book: book,
        chapter: chapterNum,
      );
    } catch (e) {
      throw Exception('Failed to get Bible verses: $e');
    }
  }

  // ========== SCHEDULE METHODS (ONLINE - UNCHANGED) ==========
  Future<void> saveSchedule(Schedule s) async => 
      _schedulesCollection.doc(s.id).set(s.toFirestore());

  Stream<Schedule?> getScheduleForDate(DateTime d) {
    return _schedulesCollection
        .doc(_formatDate(d))
        .snapshots()
        .map((doc) => doc.exists ? Schedule.fromFirestore(doc) : null);
  }

  Future<Schedule?> getScheduleForDateOnce(DateTime d) async {
    final doc = await _schedulesCollection.doc(_formatDate(d)).get();
    return doc.exists ? Schedule.fromFirestore(doc) : null;
  }

  Stream<List<Schedule>> getSchedules() {
    return _schedulesCollection
        .orderBy('scheduleDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Schedule.fromFirestore).toList());
  }

  Future<void> deleteSchedule(String id) async => 
      _schedulesCollection.doc(id).delete();

  // ========== UTILITY METHODS ==========
  String _formatDate(DateTime d) => 
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, int>> getContentStatistics() async {
    try {
      final songSnapshot = await _songsCollection.get();
      final scheduleSnapshot = await _schedulesCollection.get();
      
      // For Bible, count from local assets
      int bibleCount = 0;
      final languages = ['English', 'Hindi', 'Odia'];
      for (final language in languages) {
        try {
          final verses = await _getBibleVersesFromAsset(language);
          bibleCount += verses.length;
        } catch (e) {
          // Continue with other languages
        }
      }
      
      return {
        'songs': songSnapshot.size,
        'bible_verses': bibleCount,
        'schedules': scheduleSnapshot.size,
      };
    } catch (e) {
      throw Exception('Failed to get statistics: $e');
    }
  }

  Future<Map<String, Map<String, int>>> getStatisticsByLanguage() async {
    try {
      final stats = <String, Map<String, int>>{};
      
      // Songs from Firestore
      final songSnapshot = await _songsCollection.get();
      for (final doc in songSnapshot.docs) {
        final language = (doc.data() as Map)['language'] as String? ?? 'Unknown';
        stats[language] = stats[language] ?? {'songs': 0, 'bible_verses': 0};
        stats[language]!['songs'] = stats[language]!['songs']! + 1;
      }
      
      // Bible verses from local assets
      final languages = ['English', 'Hindi', 'Odia'];
      for (final language in languages) {
        try {
          final verses = await _getBibleVersesFromAsset(language);
          stats[language] = stats[language] ?? {'songs': 0, 'bible_verses': 0};
          stats[language]!['bible_verses'] = verses.length;
        } catch (e) {
          continue;
        }
      }
      
      return stats;
    } catch (e) {
      throw Exception('Failed to get statistics by language: $e');
    }
  }

  Future<bool> checkConnection() async {
    try {
      await _firestore.enableNetwork();
      final snapshot = await _firestore.collection('songs').limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<DateTime?> getLastSyncTimestamp(String collection) async {
    try {
      final doc = await _firestore
          .collection('sync_metadata')
          .doc(collection)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['lastSync'] as Timestamp).toDate();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateLastSyncTimestamp(String collection) async {
    try {
      await _firestore
          .collection('sync_metadata')
          .doc(collection)
          .set({
        'lastSync': FieldValue.serverTimestamp(),
        'collection': collection,
      });
    } catch (e) {
      print('Failed to update sync timestamp: $e');
    }
  }

  // ✅ NEW: Get collection for legacy compatibility (for non-Bible collections)
  CollectionReference getCollection(String collectionName) {
    if (collectionName == 'bible_verses') {
      throw Exception('Bible verses are offline only. Use specific Bible methods instead.');
    }
    return _firestore.collection(collectionName);
  }
}

// ✅ NEW: Extension for List.firstOrNull compatibility
extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
