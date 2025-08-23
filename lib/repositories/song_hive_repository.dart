import 'package:dayasagar_praise_worship/models/song_hive_model.dart';
import 'package:dayasagar_praise_worship/models/song_models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class SongHiveRepository {
  static const String _songsBoxName = 'songs_box';
  static const String _metadataBoxName = 'sync_metadata_box';
  static const int _batchSize = 20;

  Box<SongHive>? _songBox;
  Box<SyncMetadata>? _metadataBox;

  // Initialize Hive
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SongHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SyncMetadataAdapter());
    }
  }

  // Open boxes
  Future<void> openBoxes() async {
    _songBox = await Hive.openBox<SongHive>(_songsBoxName);
    _metadataBox = await Hive.openBox<SyncMetadata>(_metadataBoxName);
  }

  // Close boxes
  Future<void> closeBoxes() async {
    await _songBox?.close();
    await _metadataBox?.close();
  }

  // ═══════════════════════════════════════════════════════════
  //                    CACHE OPERATIONS  
  // ═══════════════════════════════════════════════════════════

  // Get all songs by language from cache
  Future<List<Song>> getCachedSongsByLanguage(String language) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final hiveSongs = _songBox!.values
          .where((song) => song.language == language && !song.isDeleted)
          .toList();
      
      // Sort by song name for consistent UI
      hiveSongs.sort((a, b) => a.songName.compareTo(b.songName));
      
      return hiveSongs.map((hiveSong) => hiveSong.toSong()).toList();
    } catch (e) {
      debugPrint('Error getting cached songs: $e');
      return [];
    }
  }

  // Get all songs across languages
  Future<List<Song>> getAllCachedSongs() async {
    try {
      if (_songBox == null) await openBoxes();
      
      final hiveSongs = _songBox!.values
          .where((song) => !song.isDeleted)
          .toList();
      
      hiveSongs.sort((a, b) => a.songName.compareTo(b.songName));
      return hiveSongs.map((hiveSong) => hiveSong.toSong()).toList();
    } catch (e) {
      debugPrint('Error getting all cached songs: $e');
      return [];
    }
  }

  // Search songs in cache
  Future<List<Song>> searchCachedSongs(String query) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final queryLower = query.toLowerCase();
      final hiveSongs = _songBox!.values
          .where((song) =>
              !song.isDeleted &&
              (song.songName.toLowerCase().contains(queryLower) ||
               song.lyrics.toLowerCase().contains(queryLower)))
          .toList();

      return hiveSongs.map((hiveSong) => hiveSong.toSong()).toList();
    } catch (e) {
      debugPrint('Error searching cached songs: $e');
      return [];
    }
  }

  // Get song by ID from cache
  Future<Song?> getCachedSongById(String songId) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final hiveSong = _songBox!.values
          .where((song) => song.id == songId && !song.isDeleted)
          .firstOrNull;
      
      return hiveSong?.toSong();
    } catch (e) {
      debugPrint('Error getting cached song by ID: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //                  INCREMENTAL SYNC LOGIC
  // ═══════════════════════════════════════════════════════════

  // Save songs to cache (batch update)
  Future<void> saveSongsToCache(List<Song> songs, String language, int batchNumber) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final hiveSongs = songs.map((song) => 
        SongHive.fromSong(song, fetchBatch: batchNumber)).toList();

      // Use song ID as key for efficient updates
      final Map<String, SongHive> songMap = {};
      for (final hiveSong in hiveSongs) {
        songMap[hiveSong.id] = hiveSong;
      }

      await _songBox!.putAll(songMap);
      
      // Update metadata
      await _updateSyncMetadata(language, batchNumber, songs.isNotEmpty);
      
      debugPrint('Saved ${songs.length} songs for $language, batch: $batchNumber');
    } catch (e) {
      debugPrint('Error saving songs to cache: $e');
      throw Exception('Failed to save songs: $e');
    }
  }

  // Update single song in cache (for admin operations)
  Future<void> updateSongInCache(Song song) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final existingHiveSong = _songBox!.get(song.id);
      final batchNumber = existingHiveSong?.fetchBatch ?? 0;
      
      final hiveSong = SongHive.fromSong(song, fetchBatch: batchNumber);
      await _songBox!.put(song.id, hiveSong);
      
      debugPrint('Updated song in cache: ${song.songName}');
    } catch (e) {
      debugPrint('Error updating song in cache: $e');
      throw Exception('Failed to update song: $e');
    }
  }

  // Add new song to cache (for admin operations)
  Future<void> addSongToCache(Song song) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final metadata = await getSyncMetadata(song.language);
      final batchNumber = metadata?.currentBatch ?? 0;
      
      final hiveSong = SongHive.fromSong(song, fetchBatch: batchNumber);
      await _songBox!.put(song.id, hiveSong);
      
      debugPrint('Added new song to cache: ${song.songName}');
    } catch (e) {
      debugPrint('Error adding song to cache: $e');
      throw Exception('Failed to add song: $e');
    }
  }

  // Remove song from cache (soft delete)
  Future<void> removeSongFromCache(String songId) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final hiveSong = _songBox!.get(songId);
      if (hiveSong != null) {
        final updatedSong = hiveSong.copyWith(isDeleted: true);
        await _songBox!.put(songId, updatedSong);
        debugPrint('Soft deleted song from cache: $songId');
      }
    } catch (e) {
      debugPrint('Error removing song from cache: $e');
      throw Exception('Failed to remove song: $e');
    }
  }

  // ✅ NEW: Clear language-specific cache
  Future<void> clearLanguageCache(String language) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final keysToDelete = <String>[];
      
      // Find all songs for this language
      for (final entry in _songBox!.toMap().entries) {
        if (entry.value.language == language) {
          keysToDelete.add(entry.key);
        }
      }
      
      // Delete songs for this language
      await _songBox!.deleteAll(keysToDelete);
      
      // Clear metadata for this language
      if (_metadataBox != null) {
        await _metadataBox!.delete(language);
      }
      
      debugPrint('Cleared cache for language: $language (${keysToDelete.length} songs)');
    } catch (e) {
      debugPrint('Error clearing language cache: $e');
      throw Exception('Failed to clear language cache: $e');
    }
  }

  // ✅ NEW: Hard delete song from cache (permanent removal)
  Future<void> hardDeleteSongFromCache(String songId) async {
    try {
      if (_songBox == null) await openBoxes();
      
      await _songBox!.delete(songId);
      debugPrint('Hard deleted song from cache: $songId');
    } catch (e) {
      debugPrint('Error hard deleting song from cache: $e');
      throw Exception('Failed to hard delete song: $e');
    }
  }

  // ✅ NEW: Bulk add songs to cache
  Future<void> bulkAddSongsToCache(List<Song> songs) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final Map<String, SongHive> songMap = {};
      
      for (final song in songs) {
        final metadata = await getSyncMetadata(song.language);
        final batchNumber = metadata?.currentBatch ?? 0;
        final hiveSong = SongHive.fromSong(song, fetchBatch: batchNumber);
        songMap[song.id] = hiveSong;
      }
      
      await _songBox!.putAll(songMap);
      debugPrint('Bulk added ${songs.length} songs to cache');
    } catch (e) {
      debugPrint('Error bulk adding songs to cache: $e');
      throw Exception('Failed to bulk add songs: $e');
    }
  }

  // ✅ NEW: Get songs by change type
  Future<List<Song>> getCachedSongsByChangeType(String changeType) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final hiveSongs = _songBox!.values
          .where((song) => song.changeType == changeType && !song.isDeleted)
          .toList();
      
      hiveSongs.sort((a, b) => a.songName.compareTo(b.songName));
      return hiveSongs.map((hiveSong) => hiveSong.toSong()).toList();
    } catch (e) {
      debugPrint('Error getting songs by change type: $e');
      return [];
    }
  }

  // ✅ NEW: Get deleted songs
  Future<List<Song>> getDeletedSongs() async {
    try {
      if (_songBox == null) await openBoxes();
      
      final hiveSongs = _songBox!.values
          .where((song) => song.isDeleted)
          .toList();
      
      return hiveSongs.map((hiveSong) => hiveSong.toSong()).toList();
    } catch (e) {
      debugPrint('Error getting deleted songs: $e');
      return [];
    }
  }

  // ✅ NEW: Cleanup old deleted songs
  Future<void> cleanupDeletedSongs({int olderThanDays = 30}) async {
    try {
      if (_songBox == null) await openBoxes();
      
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
      final keysToDelete = <String>[];
      
      for (final entry in _songBox!.toMap().entries) {
        final song = entry.value;
        if (song.isDeleted && song.updatedAt.isBefore(cutoffDate)) {
          keysToDelete.add(entry.key);
        }
      }
      
      await _songBox!.deleteAll(keysToDelete);
      debugPrint('Cleaned up ${keysToDelete.length} old deleted songs');
    } catch (e) {
      debugPrint('Error cleaning up deleted songs: $e');
      throw Exception('Failed to cleanup deleted songs: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //                   SYNC METADATA OPERATIONS
  // ═══════════════════════════════════════════════════════════

  // Get sync metadata for language
  Future<SyncMetadata?> getSyncMetadata(String language) async {
    try {
      if (_metadataBox == null) await openBoxes();
      return _metadataBox!.get(language);
    } catch (e) {
      debugPrint('Error getting sync metadata: $e');
      return null;
    }
  }

  // Update sync metadata
  Future<void> _updateSyncMetadata(String language, int batchNumber, bool hasMoreData) async {
    try {
      if (_metadataBox == null) await openBoxes();
      
      final metadata = SyncMetadata(
        language: language,
        lastSyncTime: DateTime.now(),
        currentBatch: batchNumber,
        hasMoreData: hasMoreData,
      );
      
      await _metadataBox!.put(language, metadata);
    } catch (e) {
      debugPrint('Error updating sync metadata: $e');
    }
  }

  // Check if initial sync is needed
  Future<bool> needsInitialSync(String language) async {
    try {
      final metadata = await getSyncMetadata(language);
      return metadata == null || metadata.currentBatch == 0;
    } catch (e) {
      debugPrint('Error checking initial sync need: $e');
      return true;
    }
  }

  // Check if incremental sync is needed
  Future<bool> needsIncrementalSync(String language) async {
    try {
      final metadata = await getSyncMetadata(language);
      if (metadata == null) return true;

      // Check if last sync was more than 5 minutes ago
      final timeDifference = DateTime.now().difference(metadata.lastSyncTime);
      return timeDifference.inMinutes >= 5 && metadata.hasMoreData;
    } catch (e) {
      debugPrint('Error checking incremental sync need: $e');
      return false;
    }
  }

  // Get current batch number for language
  Future<int> getCurrentBatch(String language) async {
    try {
      final metadata = await getSyncMetadata(language);
      return metadata?.currentBatch ?? 0;
    } catch (e) {
      debugPrint('Error getting current batch: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //                      UTILITY METHODS
  // ═══════════════════════════════════════════════════════════

  // Clear all cache data
  Future<void> clearAllCache() async {
    try {
      if (_songBox == null || _metadataBox == null) await openBoxes();
      
      await _songBox!.clear();
      await _metadataBox!.clear();
      debugPrint('Cleared all cache data');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      throw Exception('Failed to clear cache: $e');
    }
  }

  // Get cache statistics
  Future<Map<String, int>> getCacheStats() async {
    try {
      final languages = ['Hindi', 'English', 'Odia', 'Sardari'];
      final stats = <String, int>{};
      
      for (final language in languages) {
        final songs = await getCachedSongsByLanguage(language);
        stats[language] = songs.length;
      }
      
      if (_songBox != null) {
        stats['total'] = _songBox!.length;
      }
      return stats;
    } catch (e) {
      debugPrint('Error getting cache stats: $e');
      return {};
    }
  }

  // ✅ NEW: Get detailed cache statistics
  Future<Map<String, dynamic>> getDetailedCacheStats() async {
    try {
      if (_songBox == null) await openBoxes();
      
      final languages = ['Hindi', 'English', 'Odia', 'Sardari'];
      final stats = <String, dynamic>{
        'byLanguage': <String, int>{},
        'byChangeType': <String, int>{},
        'total': _songBox!.length,
        'active': 0,
        'deleted': 0,
      };
      
      int totalActive = 0;
      int totalDeleted = 0;
      final changeTypeCounts = <String, int>{};
      
      for (final language in languages) {
        final songs = await getCachedSongsByLanguage(language);
        stats['byLanguage'][language] = songs.length;
        totalActive += songs.length;
        
        for (final song in songs) {
          final changeType = song.changeType ?? 'unchanged';
          changeTypeCounts[changeType] = (changeTypeCounts[changeType] ?? 0) + 1;
        }
      }
      
      final deletedSongs = await getDeletedSongs();
      totalDeleted = deletedSongs.length;
      
      stats['active'] = totalActive;
      stats['deleted'] = totalDeleted;
      stats['byChangeType'] = changeTypeCounts;
      
      return stats;
    } catch (e) {
      debugPrint('Error getting detailed cache stats: $e');
      return {'error': e.toString()};
    }
  }

  // Watch cache changes (for reactive UI)
  Stream<List<Song>> watchCachedSongsByLanguage(String language) async* {
    yield await getCachedSongsByLanguage(language);
    
    if (_songBox != null) {
      await for (final _ in _songBox!.watch()) {
        yield await getCachedSongsByLanguage(language);
      }
    }
  }

  // Watch all cached songs
  Stream<List<Song>> watchAllCachedSongs() async* {
    yield await getAllCachedSongs();
    
    if (_songBox != null) {
      await for (final _ in _songBox!.watch()) {
        yield await getAllCachedSongs();
      }
    }
  }

  // ✅ NEW: Watch specific song changes
  Stream<Song?> watchSongById(String songId) async* {
    yield await getCachedSongById(songId);
    
    if (_songBox != null) {
      await for (final _ in _songBox!.watch(key: songId)) {
        yield await getCachedSongById(songId);
      }
    }
  }

  // ✅ NEW: Get cache size in MB
  Future<double> getCacheSizeInMB() async {
    try {
      if (_songBox == null) await openBoxes();
      
      // Rough estimation: each song ~2KB on average
      final songCount = _songBox!.length;
      final estimatedSizeKB = songCount * 2;
      return estimatedSizeKB / 1024; // Convert to MB
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0.0;
    }
  }

  // ✅ NEW: Check if box is healthy
  Future<bool> isBoxHealthy() async {
    try {
      if (_songBox == null) await openBoxes();
      
      // Basic health check
      final canRead = _songBox!.isOpen;
      final hasData = _songBox!.isNotEmpty;
      
      return canRead;
    } catch (e) {
      debugPrint('Box health check failed: $e');
      return false;
    }
  }
}

// Extension for null safety
extension ListExtension<SongHive> on List<SongHive> {
  SongHive? get firstOrNull => isEmpty ? null : first;
}
