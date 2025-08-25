import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/song_models.dart';
import '../repositories/song_hive_repository.dart';

class IncrementalSyncResult {
  final bool success;
  final int newSongs;
  final int updatedSongs;
  final int deletedSongs;
  final String? error;
  final String? message;

  IncrementalSyncResult({
    required this.success,
    required this.newSongs,
    required this.updatedSongs,
    required this.deletedSongs,
    this.error,
    this.message,
  });
}

class IncrementalSyncService {
  final SongHiveRepository _hiveRepository = SongHiveRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _batchSize = 20;
  static const List<String> _languages = ['Hindi', 'English', 'Odia', 'Sardari'];

  static IncrementalSyncService? _instance;
  static IncrementalSyncService get instance {
    _instance ??= IncrementalSyncService();
    return _instance!;
  }

  Future<void> initializeSync() async {
    try {
      await SongHiveRepository.initialize();
      await _hiveRepository.openBoxes();
      debugPrint('Incremental sync service initialized');
    } catch (e) {
      debugPrint('Error initializing sync service: $e');
      throw Exception('Failed to initialize sync service: $e');
    }
  }

  Future<IncrementalSyncResult> performIncrementalSync() async {
    try {
      int totalNew = 0;
      int totalUpdated = 0;
      int totalDeleted = 0;

      for (final language in _languages) {
        final result = await _syncLanguage(language);
        totalNew += result.newSongs;
        totalUpdated += result.updatedSongs;
        totalDeleted += result.deletedSongs;
      }

      return IncrementalSyncResult(
        success: true,
        newSongs: totalNew,
        updatedSongs: totalUpdated,
        deletedSongs: totalDeleted,
        message: totalNew > 0 ? 'Synced $totalNew new songs' : 'Already up to date',
      );
    } catch (e) {
      debugPrint('Error in incremental sync: $e');
      return IncrementalSyncResult(
        success: false,
        newSongs: 0,
        updatedSongs: 0,
        deletedSongs: 0,
        error: e.toString(),
        message: 'Sync failed: ${e.toString()}',
      );
    }
  }

  Future<IncrementalSyncResult> pullNextBatch(String language) async {
    try {
      debugPrint('Manually pulling next batch for $language');
      final result = await _syncLanguage(language);
      return result.copyWith(
        message: result.newSongs > 0 
            ? 'Fetched ${result.newSongs} new songs for $language'
            : 'No new songs available for $language'
      );
    } catch (e) {
      debugPrint('Error pulling next batch for $language: $e');
      return IncrementalSyncResult(
        success: false,
        newSongs: 0,
        updatedSongs: 0,
        deletedSongs: 0,
        error: e.toString(),
        message: 'Failed to fetch $language songs: ${e.toString()}',
      );
    }
  }

  Future<IncrementalSyncResult> pullAllLanguagesManually() async {
    try {
      debugPrint('Starting manual pull for all languages');
      
      int totalNew = 0;
      int totalUpdated = 0;
      int totalDeleted = 0;
      List<String> languageResults = [];

      for (final language in _languages) {
        try {
          final result = await _syncLanguage(language);
          
          if (result.success) {
            totalNew += result.newSongs;
            totalUpdated += result.updatedSongs;
            totalDeleted += result.deletedSongs;
            
            if (result.newSongs > 0) {
              languageResults.add('$language: ${result.newSongs}');
            }
          }
        } catch (e) {
          debugPrint('Error syncing $language: $e');
          languageResults.add('$language: error');
        }
      }

      final message = totalNew > 0 
          ? 'Fetched $totalNew new songs (${languageResults.join(', ')})'
          : 'No new songs available';

      return IncrementalSyncResult(
        success: true,
        newSongs: totalNew,
        updatedSongs: totalUpdated,
        deletedSongs: totalDeleted,
        message: message,
      );
    } catch (e) {
      debugPrint('Error in manual pull all: $e');
      return IncrementalSyncResult(
        success: false,
        newSongs: 0,
        updatedSongs: 0,
        deletedSongs: 0,
        error: e.toString(),
        message: 'Manual refresh failed: ${e.toString()}',
      );
    }
  }

  Future<IncrementalSyncResult> forceCompleteRefresh() async {
    try {
      debugPrint('Starting force complete refresh');
      
      await _hiveRepository.clearAllCache();
      
      for (final language in _languages) {
        await _hiveRepository.saveSongsToCache([], language, 0);
      }
      
      int totalNew = 0;
      List<String> results = [];
      
      for (final language in _languages) {
        final result = await _performInitialSync(language);
        if (result.success) {
          totalNew += result.newSongs;
          if (result.newSongs > 0) {
            results.add('$language: ${result.newSongs}');
          }
        }
      }

      final message = totalNew > 0 
          ? 'Refreshed all data: $totalNew songs (${results.join(', ')})'
          : 'Refresh completed - no songs found';

      debugPrint('Force refresh completed: $message');

      return IncrementalSyncResult(
        success: true,
        newSongs: totalNew,
        updatedSongs: 0,
        deletedSongs: 0,
        message: message,
      );
    } catch (e) {
      debugPrint('Error in force refresh: $e');
      return IncrementalSyncResult(
        success: false,
        newSongs: 0,
        updatedSongs: 0,
        deletedSongs: 0,
        error: e.toString(),
        message: 'Force refresh failed: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final stats = await getCacheStatsByLanguage();
      final Map<String, dynamic> status = {
        'languages': {},
        'totalSongs': 0,
      };

      int totalSongs = 0;
      for (final language in _languages) {
        final count = stats[language] ?? 0;
        final batch = await _hiveRepository.getCurrentBatch(language);
        final metadata = await _hiveRepository.getSyncMetadata(language);
        
        status['languages'][language] = {
          'songCount': count,
          'currentBatch': batch,
          'lastSyncTime': metadata?.lastSyncTime.toIso8601String(),
          'hasMoreData': metadata?.hasMoreData ?? true,
        };
        
        totalSongs += count;
      }
      
      status['totalSongs'] = totalSongs;
      return status;
    } catch (e) {
      debugPrint('Error getting cache status: $e');
      return {'error': e.toString()};
    }
  }

  Future<bool> shouldRefresh({Duration maxAge = const Duration(hours: 1)}) async {
    try {
      for (final language in _languages) {
        final metadata = await _hiveRepository.getSyncMetadata(language);
        if (metadata == null) return true;
        
        final timeSinceLastSync = DateTime.now().difference(metadata.lastSyncTime);
        if (timeSinceLastSync > maxAge) return true;
      }
      return false;
    } catch (e) {
      return true;
    }
  }

  Future<void> updateLocalCache(List<Song> songs) async {
    try {
      for (final song in songs) {
        if (song.isDeleted) {
          await _hiveRepository.removeSongFromCache(song.id);
        } else {
          final existingSong = await _hiveRepository.getCachedSongById(song.id);
          if (existingSong != null) {
            await _hiveRepository.updateSongInCache(song);
          } else {
            await _hiveRepository.addSongToCache(song);
          }
        }
      }
      debugPrint('Updated local cache with ${songs.length} songs');
    } catch (e) {
      debugPrint('Error updating local cache: $e');
      throw Exception('Failed to update local cache: $e');
    }
  }

  Future<void> addSongToLocalCache(Song song) async {
    try {
      await _hiveRepository.addSongToCache(song);
      debugPrint('Added song to local cache: ${song.songName}');
    } catch (e) {
      debugPrint('Error adding song to cache: $e');
      throw Exception('Failed to add song to cache: $e');
    }
  }

  Future<void> updateSongInLocalCache(Song song) async {
    try {
      await _hiveRepository.updateSongInCache(song);
      debugPrint('Updated song in local cache: ${song.songName}');
    } catch (e) {
      debugPrint('Error updating song in cache: $e');
      throw Exception('Failed to update song in cache: $e');
    }
  }

  Future<void> removeSongFromLocalCache(String songId) async {
    try {
      await _hiveRepository.removeSongFromCache(songId);
      debugPrint('Removed song from local cache: $songId');
    } catch (e) {
      debugPrint('Error removing song from cache: $e');
      throw Exception('Failed to remove song from cache: $e');
    }
  }

  Future<void> addSongToCache(Song song) async {
    try {
      await _hiveRepository.addSongToCache(song);
      debugPrint('Added song to cache: ${song.songName}');
    } catch (e) {
      debugPrint('Error adding song to cache: $e');
      throw Exception('Failed to add song to cache: $e');
    }
  }

  Future<void> updateSongInCache(Song song) async {
    try {
      await _hiveRepository.updateSongInCache(song);
      debugPrint('Updated song in cache: ${song.songName}');
    } catch (e) {
      debugPrint('Error updating song in cache: $e');
      throw Exception('Failed to update song in cache: $e');
    }
  }

  Future<void> markSongAsDeletedInCache(String songId, String language) async {
    try {
      final existingSong = await _hiveRepository.getCachedSongById(songId);
      if (existingSong != null) {
        final deletedSong = existingSong.copyWith(
          isDeleted: true,
          changeType: 'deleted',
          updatedAt: Timestamp.now(),
        );
        await _hiveRepository.updateSongInCache(deletedSong);
        debugPrint('Marked song as deleted in cache: $songId');
      }
    } catch (e) {
      debugPrint('Error marking song as deleted: $e');
      throw Exception('Failed to mark song as deleted: $e');
    }
  }

  Future<IncrementalSyncResult> syncSpecificLanguage(String language) async {
    try {
      debugPrint('Syncing specific language: $language');
      return await _syncLanguage(language);
    } catch (e) {
      debugPrint('Error syncing language $language: $e');
      return IncrementalSyncResult(
        success: false,
        newSongs: 0,
        updatedSongs: 0,
        deletedSongs: 0,
        error: e.toString(),
        message: 'Failed to sync $language: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>> getLanguageStatus(String language) async {
    try {
      final songs = await _hiveRepository.getCachedSongsByLanguage(language);
      final batch = await _hiveRepository.getCurrentBatch(language);
      final metadata = await _hiveRepository.getSyncMetadata(language);
      
      return {
        'language': language,
        'songCount': songs.length,
        'currentBatch': batch,
        'lastSyncTime': metadata?.lastSyncTime.toIso8601String(),
        'hasMoreData': metadata?.hasMoreData ?? true,
        'activeSongs': songs.where((s) => !s.isDeleted).length,
        'deletedSongs': songs.where((s) => s.isDeleted).length,
      };
    } catch (e) {
      debugPrint('Error getting language status for $language: $e');
      return {'error': e.toString()};
    }
  }

  Future<void> resetLanguageCache(String language) async {
    try {
      await _hiveRepository.clearLanguageCache(language);
      await _hiveRepository.saveSongsToCache([], language, 0);
      debugPrint('Reset cache for language: $language');
    } catch (e) {
      debugPrint('Error resetting cache for $language: $e');
      throw Exception('Failed to reset cache for $language: $e');
    }
  }

  Future<void> batchUpdateCache(List<Song> songs) async {
    try {
      debugPrint('Starting batch cache update for ${songs.length} songs');
      
      final Map<String, List<Song>> songsByLanguage = {};
      
      for (final song in songs) {
        songsByLanguage.putIfAbsent(song.language, () => []).add(song);
      }
      
      for (final entry in songsByLanguage.entries) {
        final language = entry.key;
        final languageSongs = entry.value;
        
        for (final song in languageSongs) {
          if (song.isDeleted) {
            await _hiveRepository.removeSongFromCache(song.id);
          } else {
            final existingSong = await _hiveRepository.getCachedSongById(song.id);
            if (existingSong != null) {
              await _hiveRepository.updateSongInCache(song);
            } else {
              await _hiveRepository.addSongToCache(song);
            }
          }
        }
        
        debugPrint('Updated ${languageSongs.length} songs for $language');
      }
      
      debugPrint('Batch cache update completed');
    } catch (e) {
      debugPrint('Error in batch cache update: $e');
      throw Exception('Batch cache update failed: $e');
    }
  }

  Stream<List<Song>> getRealtimeUpdatesStream() {
    return _firestore
        .collection('songs')
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        final songs = <Song>[];
        
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            final song = Song.fromMap(data);
            songs.add(song);
          } catch (e) {
            debugPrint('Error parsing song ${doc.id} in realtime stream: $e');
          }
        }
        
        await updateLocalCache(songs);
        
        return songs;
      } catch (e) {
        debugPrint('Error in realtime updates stream: $e');
        return <Song>[];
      }
    });
  }

  Stream<List<Song>> getRealtimeLanguageUpdatesStream(String language) {
    return _firestore
        .collection('songs')
        .where('language', isEqualTo: language)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        final songs = <Song>[];
        
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            final song = Song.fromMap(data);
            songs.add(song);
          } catch (e) {
            debugPrint('Error parsing song ${doc.id} for $language: $e');
          }
        }
        
        return songs;
      } catch (e) {
        debugPrint('Error in realtime language stream for $language: $e');
        return <Song>[];
      }
    });
  }

  Future<Map<String, dynamic>> getPerformanceMetrics() async {
    try {
      final stats = await getCacheStatsByLanguage();
      final cacheStatus = await getCacheStatus();
      
      return {
        'cacheStats': stats,
        'cacheStatus': cacheStatus,
        'languages': _languages,
        'batchSize': _batchSize,
        'totalCachedSongs': stats.values.fold(0, (sum, count) => sum + count),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting performance metrics: $e');
      return {'error': e.toString()};
    }
  }

  Future<void> optimizeCache() async {
    try {
      debugPrint('Starting cache optimization');
      
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      
      for (final language in _languages) {
        final songs = await _hiveRepository.getCachedSongsByLanguage(language);
        
        for (final song in songs) {
          if (song.isDeleted && song.updatedAt.toDate().isBefore(cutoffDate)) {
            await _hiveRepository.removeSongFromCache(song.id);
          }
        }
      }
      
      debugPrint('Cache optimization completed');
    } catch (e) {
      debugPrint('Error optimizing cache: $e');
      throw Exception('Cache optimization failed: $e');
    }
  }

  Future<bool> isSongCached(String songId) async {
    try {
      final song = await _hiveRepository.getCachedSongById(songId);
      return song != null;
    } catch (e) {
      debugPrint('Error checking if song is cached: $e');
      return false;
    }
  }

  Future<int> getCachedSongCount() async {
    try {
      final allSongs = await _hiveRepository.getAllCachedSongs();
      return allSongs.where((song) => !song.isDeleted).length;
    } catch (e) {
      debugPrint('Error getting cached song count: $e');
      return 0;
    }
  }

  Future<List<String>> getAvailableLanguages() async {
    try {
      final stats = await getCacheStatsByLanguage();
      return stats.entries
          .where((entry) => entry.value > 0)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      debugPrint('Error getting available languages: $e');
      return [];
    }
  }

  Future<void> preloadLanguage(String language) async {
    try {
      debugPrint('Preloading language: $language');
      await _syncLanguage(language);
      debugPrint('Preloaded language: $language');
    } catch (e) {
      debugPrint('Error preloading language $language: $e');
      throw Exception('Failed to preload $language: $e');
    }
  }

  Future<IncrementalSyncResult> refreshLanguage(String language) async {
    try {
      debugPrint('Refreshing language: $language');
      await resetLanguageCache(language);
      return await _performInitialSync(language);
    } catch (e) {
      debugPrint('Error refreshing language $language: $e');
      return IncrementalSyncResult(
        success: false,
        newSongs: 0,
        updatedSongs: 0,
        deletedSongs: 0,
        error: e.toString(),
        message: 'Failed to refresh $language: ${e.toString()}',
      );
    }
  }

  Future<IncrementalSyncResult> _syncLanguage(String language) async {
    try {
      final needsInitial = await _hiveRepository.needsInitialSync(language);
      final needsIncremental = await _hiveRepository.needsIncrementalSync(language);

      if (!needsInitial && !needsIncremental) {
        debugPrint('No sync needed for $language');
        return IncrementalSyncResult(
          success: true,
          newSongs: 0,
          updatedSongs: 0,
          deletedSongs: 0,
          message: 'Already up to date',
        );
      }

      if (needsInitial) {
        return await _performInitialSync(language);
      } else {
        return await _performIncrementalFetch(language);
      }
    } catch (e) {
      debugPrint('Error syncing language $language: $e');
      return IncrementalSyncResult(
        success: false,
        newSongs: 0,
        updatedSongs: 0,
        deletedSongs: 0,
        error: e.toString(),
        message: 'Failed to sync $language: ${e.toString()}',
      );
    }
  }

  Future<IncrementalSyncResult> _performInitialSync(String language) async {
    try {
      debugPrint('Performing initial sync for $language');

      final query = _firestore
          .collection('songs')
          .where('language', isEqualTo: language)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt')
          .limit(_batchSize);

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        return IncrementalSyncResult(
          success: true,
          newSongs: 0,
          updatedSongs: 0,
          deletedSongs: 0,
          message: 'No songs found for $language',
        );
      }

      final songs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Song.fromMap(data);
      }).toList();

      await _hiveRepository.saveSongsToCache(songs, language, 1);

      debugPrint('Initial sync completed for $language: ${songs.length} songs');

      return IncrementalSyncResult(
        success: true,
        newSongs: songs.length,
        updatedSongs: 0,
        deletedSongs: 0,
        message: 'Loaded ${songs.length} songs for $language',
      );
    } catch (e) {
      debugPrint('Error in initial sync for $language: $e');
      throw Exception('Initial sync failed: $e');
    }
  }

  Future<IncrementalSyncResult> _performIncrementalFetch(String language) async {
    try {
      debugPrint('Performing incremental fetch for $language');

      final currentBatch = await _hiveRepository.getCurrentBatch(language);
      final nextBatch = currentBatch + 1;

      final cachedSongs = await _hiveRepository.getCachedSongsByLanguage(language);
      
      Query query = _firestore
          .collection('songs')
          .where('language', isEqualTo: language)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt');

      if (cachedSongs.isNotEmpty) {
        final lastSongDoc = await _firestore
            .collection('songs')
            .doc(cachedSongs.last.id)
            .get();
        
        if (lastSongDoc.exists) {
          query = query.startAfterDocument(lastSongDoc);
        }
      }

      final snapshot = await query.limit(_batchSize).get();

      if (snapshot.docs.isEmpty) {
        debugPrint('No new songs to fetch for $language');
        return IncrementalSyncResult(
          success: true,
          newSongs: 0,
          updatedSongs: 0,
          deletedSongs: 0,
          message: 'No new songs available for $language',
        );
      }

      final songs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Song.fromMap(data);
      }).toList();

      await _hiveRepository.saveSongsToCache(songs, language, nextBatch);

      debugPrint('Incremental fetch completed for $language: ${songs.length} new songs');

      return IncrementalSyncResult(
        success: true,
        newSongs: songs.length,
        updatedSongs: 0,
        deletedSongs: 0,
        message: 'Fetched ${songs.length} new songs for $language',
      );
    } catch (e) {
      debugPrint('Error in incremental fetch for $language: $e');
      throw Exception('Incremental fetch failed: $e');
    }
  }

  Future<void> syncSingleSong(String songId) async {
    try {
      final doc = await _firestore.collection('songs').doc(songId).get();
      
      if (!doc.exists) {
        await _hiveRepository.removeSongFromCache(songId);
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      final song = Song.fromMap(data);

      if (song.isDeleted) {
        await _hiveRepository.removeSongFromCache(songId);
      } else {
        final existingSong = await _hiveRepository.getCachedSongById(songId);
        if (existingSong != null) {
          await _hiveRepository.updateSongInCache(song);
        } else {
          await _hiveRepository.addSongToCache(song);
        }
      }

      debugPrint('Synced single song: ${song.songName}');
    } catch (e) {
      debugPrint('Error syncing single song $songId: $e');
      throw Exception('Failed to sync song: $e');
    }
  }

  Stream<void> listenToSongChanges() {
    return _firestore
        .collection('songs')
        .snapshots()
        .asyncMap((snapshot) async {
          for (final change in snapshot.docChanges) {
            try {
              final songId = change.doc.id;
              
              switch (change.type) {
                case DocumentChangeType.added:
                case DocumentChangeType.modified:
                  await syncSingleSong(songId);
                  break;
                case DocumentChangeType.removed:
                  await _hiveRepository.removeSongFromCache(songId);
                  break;
              }
            } catch (e) {
              debugPrint('Error processing song change: $e');
            }
          }
        });
  }

  Future<List<Song>> getCachedSongsByLanguage(String language) async {
    return await _hiveRepository.getCachedSongsByLanguage(language);
  }

  Future<List<Song>> getAllCachedSongs() async {
    return await _hiveRepository.getAllCachedSongs();
  }

  Future<List<Song>> searchCachedSongs(String query) async {
    return await _hiveRepository.searchCachedSongs(query);
  }

  Future<Song?> getCachedSongById(String songId) async {
    return await _hiveRepository.getCachedSongById(songId);
  }

  Stream<List<Song>> watchCachedSongs({Duration interval = const Duration(seconds: 5)}) {
    return _hiveRepository.watchAllCachedSongs();
  }

  Stream<List<Song>> watchCachedSongsByLanguage(String language) {
    return _hiveRepository.watchCachedSongsByLanguage(language);
  }

  Future<void> forceSyncAll() async {
    try {
      await _hiveRepository.clearAllCache();
      await performIncrementalSync();
      debugPrint('Force sync completed');
    } catch (e) {
      debugPrint('Error in force sync: $e');
      throw Exception('Force sync failed: $e');
    }
  }

  Future<Map<String, int>> getCacheStatsByLanguage() async {
    return await _hiveRepository.getCacheStats();
  }

  Future<void> clearAllCache() async {
    await _hiveRepository.clearAllCache();
  }

  Future<void> dispose() async {
    await _hiveRepository.closeBoxes();
  }
}

extension IncrementalSyncResultExtension on IncrementalSyncResult {
  IncrementalSyncResult copyWith({
    bool? success,
    int? newSongs,
    int? updatedSongs,
    int? deletedSongs,
    String? error,
    String? message,
  }) {
    return IncrementalSyncResult(
      success: success ?? this.success,
      newSongs: newSongs ?? this.newSongs,
      updatedSongs: updatedSongs ?? this.updatedSongs,
      deletedSongs: deletedSongs ?? this.deletedSongs,
      error: error ?? this.error,
      message: message ?? this.message,
    );
  }
}

final incrementalSyncServiceProvider = Provider<IncrementalSyncService>((ref) {
  final service = IncrementalSyncService.instance;
  ref.onDispose(() => service.dispose());
  return service;
});
