// lib/services/persistent_cache_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PersistentCacheService {
  static final PersistentCacheService _instance = PersistentCacheService._internal();
  factory PersistentCacheService() => _instance;
  PersistentCacheService._internal();

  Future<File> _getCacheFile(String key) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/cache_$key.json');
  }

  // ✅ FIXED: Updated method signatures to match bible_provider expectations
  
  /// Get cached data as List<String> (for bible books provider)
  Future<List<String>?> get(String key) async {
    try {
      final file = await _getCacheFile(key);
      if (!await file.exists()) return null;
      
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);
      
      // Handle different data structures
      if (data is Map<String, dynamic>) {
        if (data.containsKey('items') && data['items'] is List) {
          return List<String>.from(data['items']);
        } else if (data.containsKey('text') && data['text'] is String) {
          // Handle old schedule format - return as single item list
          return [data['text'] as String];
        }
      } else if (data is List) {
        return List<String>.from(data);
      }
      
      return null;
    } catch (e) {
      print('Cache get error for key $key: $e');
      return null;
    }
  }

  /// Set cached data as List<String> with expiration
  Future<bool> set(String key, List<String> value, Duration? duration) async {
    try {
      final file = await _getCacheFile(key);
      final cacheData = {
        'items': value,
        'cachedAt': DateTime.now().toIso8601String(),
        'expiresAt': duration != null 
            ? DateTime.now().add(duration).toIso8601String()
            : null,
      };
      
      await file.writeAsString(jsonEncode(cacheData));
      return true;
    } catch (e) {
      print('Cache set error for key $key: $e');
      return false;
    }
  }

  /// Delete specific cached item
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

  // ============================================================================
  // EXISTING SCHEDULE-SPECIFIC METHODS (Backward Compatibility)
  // ============================================================================

  /// Cache a schedule (legacy method - kept for compatibility)
  Future<void> cacheSchedule(String key, String scheduleText) async {
    final file = await _getCacheFile(key);
    await file.writeAsString(jsonEncode({
      'text': scheduleText,
      'cachedAt': DateTime.now().toIso8601String(),
    }));
  }

  /// Get a cached schedule (legacy method - kept for compatibility)
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

  /// Clear all caches in the cache directory
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

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    final dir = await getApplicationDocumentsDirectory();
    final cachedFiles = dir.listSync().where((f) => f.path.contains('cache_')).toList();
    
    int schedules = 0;
    int bibleBooks = 0;
    int other = 0;
    
    for (final file in cachedFiles) {
      final fileName = file.path.split('/').last;
      if (fileName.contains('schedule')) {
        schedules++;
      } else if (fileName.contains('bible_books')) {
        bibleBooks++;
      } else {
        other++;
      }
    }
    
    return {
      'total_files': cachedFiles.length,
      'schedules': schedules,
      'bible_books': bibleBooks,
      'other': other,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  /// Get cache size in MB
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
}
