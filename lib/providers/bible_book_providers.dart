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
  Future<List<String>?> get(String key) async {
    try {
      final file = await _getCacheFile(key);
      if (!await file.exists()) return null;
      
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);
      
      if (data is Map<String, dynamic>) {
        if (data.containsKey('items') && data['items'] is List) {
          return List<String>.from(data['items']);
        } else if (data.containsKey('text') && data['text'] is String) {
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
  Future<bool> isValid(String key) async {
    try {
      final file = await _getCacheFile(key);
      if (!await file.exists()) return false;
      
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);
      
      if (data is Map<String, dynamic> && data.containsKey('expiresAt')) {
        final expiresAt = data['expiresAt'] as String?;
        if (expiresAt != null) {
          final expiry = DateTime.parse(expiresAt);
          return DateTime.now().isBefore(expiry);
        }
      }
      
      return true; 
    } catch (e) {
      print('Cache validity check error for key $key: $e');
      return false;
    }
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
  Future<void> clearExpiredCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final cachedFiles = dir.listSync().where((f) => f.path.contains('cache_'));
    
    for (final file in cachedFiles) {
      if (file is File) {
        try {
          final content = await file.readAsString();
          final data = jsonDecode(content);
          
          if (data is Map<String, dynamic> && data.containsKey('expiresAt')) {
            final expiresAt = data['expiresAt'] as String?;
            if (expiresAt != null) {
              final expiry = DateTime.parse(expiresAt);
              if (DateTime.now().isAfter(expiry)) {
                await file.delete();
                print('Deleted expired cache: ${file.path}');
              }
            }
          }
        } catch (e) {
          print('Error checking expiry for ${file.path}: $e');
        }
      }
    }
  }

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

  Future<Map<String, dynamic>> getCacheInfo(String key) async {
    try {
      final file = await _getCacheFile(key);
      if (!await file.exists()) {
        return {'exists': false};
      }
      
      final stat = await file.stat();
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      return {
        'exists': true,
        'size_bytes': stat.size,
        'size_kb': (stat.size / 1024).toStringAsFixed(2),
        'created': stat.modified.toIso8601String(),
        'cached_at': data is Map ? data['cachedAt'] : null,
        'expires_at': data is Map ? data['expiresAt'] : null,
        'is_valid': await isValid(key),
      };
    } catch (e) {
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }
}
