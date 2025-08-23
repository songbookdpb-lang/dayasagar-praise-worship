
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_models.dart';
import '../models/schedule_model.dart';
import 'cache_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  FirebaseFirestore get _firestore => _db;
  CollectionReference get _songsCollection => _db.collection('songs');
  CollectionReference get _schedulesCollection => _db.collection('schedules');

  Future<List<Song>> getSongsChangedSince(Timestamp lastSync, {int limit = 500}) async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .where('updatedAt', isGreaterThan: lastSync)
          .orderBy('updatedAt')
          .limit(limit)
          .get();
      
      return snapshot.docs.map(Song.fromFirestore).toList();
    } catch (e) {
      throw Exception('Failed to get songs changed since: $e');
    }
  }
  Future<List<Song>> getSongsChangedSinceByLanguage(
    String language, 
    Timestamp lastSync, {
    int limit = 500
  }) async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .where('language', isEqualTo: language)
          .where('updatedAt', isGreaterThan: lastSync)
          .orderBy('updatedAt')
          .limit(limit)
          .get();
      
      return snapshot.docs.map(Song.fromFirestore).toList();
    } catch (e) {
      throw Exception('Failed to get songs changed since for language $language: $e');
    }
  }

  Future<String> addSong(Song song) async {
    final now = Timestamp.now();
    final songWithTracking = Song(
      id: song.id,
      songName: song.songName,
      lyrics: song.lyrics,
      language: song.language,
      createdAt: now,
      updatedAt: now,
      changeType: 'created',
      isDeleted: false,
    );
    
    final doc = await _songsCollection.add(songWithTracking.toFirestore());
    return doc.id;
  }

  Stream<List<Song>> getSongs() {
    return _songsCollection
        .where('isDeleted', isEqualTo: false)
        .orderBy('songName')
        .snapshots()
        .map((s) => s.docs.map(Song.fromFirestore).toList());
  }

  Stream<List<Song>> getSongsByLanguage(String language) {
    return _songsCollection
        .where('language', isEqualTo: language)
        .where('isDeleted', isEqualTo: false)
        .orderBy('songName')
        .snapshots()
        .map((s) => s.docs.map(Song.fromFirestore).toList());
  }
  Future<List<Song>> searchSongs(String query, String language) async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .where('language', isEqualTo: language)
          .where('isDeleted', isEqualTo: false)
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

  Future<List<Song>> searchSongsAdvanced({
    String? query,
    String? language,
    int limit = 50,
  }) async {
    try {
      Query firestoreQuery = _firestore.collection('songs')
          .where('isDeleted', isEqualTo: false);
      
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

  Future<List<Song>> searchAllSongs(String query) async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .where('isDeleted', isEqualTo: false)
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
          .where('isDeleted', isEqualTo: false)
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

  Future<void> updateSong(String id, Song song) async {
    final now = Timestamp.now();
    await _songsCollection.doc(id).update({
      'songName': song.songName,
      'lyrics': song.lyrics,
      'language': song.language,
      'updatedAt': now,
      'changeType': 'edited',
      'isDeleted': false,
    });
  }
  
  Future<void> deleteSong(String id) async {
    final now = Timestamp.now();
    await _songsCollection.doc(id).update({
      'updatedAt': now,
      'changeType': 'deleted',
      'isDeleted': true,
    });
  }

  Future<List<Song>> _getPaginatedSongs(String language, int limit, DocumentSnapshot? last) async {
    var q = _songsCollection
        .where('language', isEqualTo: language)
        .where('isDeleted', isEqualTo: false)
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
    final snap = await _songsCollection
        .where('isDeleted', isEqualTo: false)
        .get();
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

  Future<void> bulkAddSongs(List<Song> songs) async {
    final batch = _firestore.batch();
    final now = Timestamp.now();
    
    for (final song in songs) {
      final docRef = _songsCollection.doc();
      final songWithTracking = Song(
        id: docRef.id,
        songName: song.songName,
        lyrics: song.lyrics,
        language: song.language,
        createdAt: now,
        updatedAt: now,
        changeType: 'created',
        isDeleted: false,
      );
      batch.set(docRef, songWithTracking.toFirestore());
    }
    
    await batch.commit();
  }
  Future<List<Song>> getSongsWithCache({
    String? language,
    bool useCache = true,
  }) async {
    try {
      Query query = _firestore.collection('songs')
          .where('isDeleted', isEqualTo: false);
      
      if (language != null) {
        query = query.where('language', isEqualTo: language);
      }
      
      query = query.orderBy('songName');
      
      final snapshot = await query.get(GetOptions(
        source: useCache ? Source.cache : Source.server,
      ));
      
      return snapshot.docs.map(Song.fromFirestore).toList();
    } catch (e) {
      if (!useCache) {
        throw Exception('Failed to get songs: $e');
      } else {
        return getSongsWithCache(language: language, useCache: true);
      }
    }
  }

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

  String _formatDate(DateTime d) => 
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, int>> getContentStatistics() async {
    try {
      final songSnapshot = await _songsCollection
          .where('isDeleted', isEqualTo: false)
          .get();
      final scheduleSnapshot = await _schedulesCollection.get();
      
      return {
        'songs': songSnapshot.size,
        'schedules': scheduleSnapshot.size,
      };
    } catch (e) {
      throw Exception('Failed to get statistics: $e');
    }
  }

  Future<Map<String, Map<String, int>>> getStatisticsByLanguage() async {
    try {
      final stats = <String, Map<String, int>>{};
      
      final songSnapshot = await _songsCollection
          .where('isDeleted', isEqualTo: false)
          .get();
      for (final doc in songSnapshot.docs) {
        final language = (doc.data() as Map)['language'] as String? ?? 'Unknown';
        stats[language] = stats[language] ?? {'songs': 0};
        stats[language]!['songs'] = stats[language]!['songs']! + 1;
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
Future<void> updateSchedule(String scheduleId, Schedule schedule) async {
  try {
    await _firestore
        .collection('schedules')
        .doc(scheduleId)
        .update(schedule.toMap());
    
    debugPrint('Schedule updated successfully: $scheduleId');
  } catch (e) {
    debugPrint('Error updating schedule: $e');
    throw Exception('Failed to update schedule: $e');
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
}
