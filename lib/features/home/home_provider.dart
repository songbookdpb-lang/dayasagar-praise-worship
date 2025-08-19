// lib/features/home/home_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/schedule_model.dart';
import '../../models/song_models.dart';
import '../../models/bible_verse_model.dart';
import '../../models/search_result_model.dart';
import '../../services/persistent_cache_service.dart';
import '../../services/firestore_service.dart';

// Debug logging utility
void _debugLog(String message) {
  if (kDebugMode) {
    debugPrint('[HomeProvider] $message');
  }
}

// Search query providers
final homeSearchQueryProvider = StateProvider<String>((ref) => '');
final globalSongSearchProvider = StateProvider<String>((ref) => '');
final globalBibleSearchProvider = StateProvider<String>((ref) => '');

// Search suggestions provider
final searchSuggestionsProvider = Provider<List<String>>((ref) {
  return [
    'Jesus',
    'Love',
    'Grace',
    'Worship',
    'Praise',
    'Hallelujah',
    'John 3:16',
    'Psalms 23',
    'Faith',
    'Hope',
    'Peace',
    'Salvation',
  ];
});

// Recent searches provider
final recentSearchesProvider = StateProvider<List<String>>((ref) => []);

// SIMPLIFIED: App settings provider (no caching)
final appSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('main')
        .get();
    
    if (doc.exists) {
      return Map<String, dynamic>.from(doc.data() ?? {}); // FIXED: Proper type casting
    }
    return <String, dynamic>{};
  } catch (e) {
    _debugLog('Failed to load settings: $e');
    return <String, dynamic>{};
  }
});

// SIMPLIFIED: Today's schedule provider (no advanced caching)
final todayScheduleTextProvider = FutureProvider<String?>((ref) async {
  final today = DateTime.now();
  final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  
  try {
    // Try cache first
    final cacheService = PersistentCacheService();
    final cachedSchedule = await cacheService.getCachedSchedule(todayString);
    if (cachedSchedule != null) {
      _debugLog('Using cached schedule for: $todayString');
      return cachedSchedule;
    }
    
    // Fetch from server
    final scheduleDoc = await FirebaseFirestore.instance
        .collection('schedules')
        .doc(todayString)
        .get();
    
    if (scheduleDoc.exists) {
      final schedule = Schedule.fromFirestore(scheduleDoc);
      final scheduleText = schedule.scheduleText;
      
      // Cache the result
      if (scheduleText != null && scheduleText.isNotEmpty) {
        try {
          await cacheService.cacheSchedule(todayString, scheduleText);
          _debugLog('Cached schedule for: $todayString');
        } catch (cacheError) {
          _debugLog('Failed to cache schedule: $cacheError');
        }
      }
      
      return scheduleText;
    }
    return null;
  } catch (e) {
    _debugLog('Error loading schedule: $e');
    return null;
  }
});

// SIMPLIFIED: Global song search results (no complex caching)
final globalSongSearchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(globalSongSearchProvider);
  
  if (query.isEmpty) {
    return [];
  }

  try {
    final firestoreService = ref.read(firestoreServiceProvider);
    final songs = await firestoreService.searchAllSongs(query);
    _debugLog('Found ${songs.length} songs for: $query');
    return songs;
  } catch (e) {
    _debugLog('Error searching songs: $e');
    return [];
  }
});

// SIMPLIFIED: Global Bible search results (no complex caching)
final globalBibleSearchResultsProvider = FutureProvider<List<BibleVerse>>((ref) async {
  final query = ref.watch(globalBibleSearchProvider);
  
  if (query.isEmpty) {
    return [];
  }

  try {
    final firestoreService = ref.read(firestoreServiceProvider);
    final verses = await firestoreService.searchAllBibleVerses(query);
    _debugLog('Found ${verses.length} Bible verses for: $query');
    return verses;
  } catch (e) {
    _debugLog('Error searching Bible verses: $e');
    return [];
  }
});

// Home search results provider
final homeSearchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(homeSearchQueryProvider);
  
  if (query.isEmpty) {
    return [];
  }

  try {
    // Update the global search providers
    ref.read(globalSongSearchProvider.notifier).state = query;
    ref.read(globalBibleSearchProvider.notifier).state = query;
    
    // Get results from the global search providers
    final songsTask = ref.read(globalSongSearchResultsProvider.future);
    final versesTask = ref.read(globalBibleSearchResultsProvider.future);
    
    final results = await Future.wait([songsTask, versesTask]);
    final songs = results[0] as List<Song>;
    final verses = results[1] as List<BibleVerse>;

    // Convert to search results
    final searchResults = <SearchResult>[];
    
    // Add song results
    for (final song in songs) {
      searchResults.add(SongSearchResult(song));
    }
    
    // Add Bible verse results
    for (final verse in verses) {
      searchResults.add(BibleSearchResult(verse));
    }
    
    _debugLog('Found ${searchResults.length} total results for: $query');
    return searchResults;
  } catch (e) {
    _debugLog('Home search error: $e');
    return [];
  }
});

// SIMPLIFIED: Clear cache provider (using only existing methods)
final clearCacheProvider = FutureProvider<void>((ref) async {
  try {
    final cacheService = PersistentCacheService();
    await cacheService.clearAllCache();
    _debugLog('Cache cleared successfully');
  } catch (e) {
    _debugLog('Error clearing cache: $e');
    rethrow; // FIXED: Use rethrow instead of throw
  }
});

// SIMPLIFIED: Cache statistics provider (using only existing methods)
final cacheStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final cacheService = PersistentCacheService();
    final hiveStats = await cacheService.getCacheStats();
    final cacheSizeMB = await cacheService.getCacheSizeMB();
    
    return {
      'hive_songs': hiveStats['songs'] ?? 0,
      'hive_bible_verses': hiveStats['bible_verses'] ?? 0,
      'hive_schedules': hiveStats['schedules'] ?? 0,
      'hive_search_results': hiveStats['search_results'] ?? 0,
      'total_size_mb': cacheSizeMB,
      'last_updated': DateTime.now().toIso8601String(),
    };
  } catch (e) {
    _debugLog('Error getting cache stats: $e');
    return {
      'error': e.toString(),
      'total_size_mb': 0.0,
    };
  }
});

// SIMPLIFIED: Search history management (using only existing methods)
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>(
  (ref) => SearchHistoryNotifier(),
);

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]);
  
  void addSearch(String query) {
    if (query.trim().isEmpty) return;
    
    final trimmedQuery = query.trim();
    final currentHistory = [...state];
    
    // Remove if already exists
    currentHistory.remove(trimmedQuery);
    
    // Add to beginning
    currentHistory.insert(0, trimmedQuery);
    
    // Keep only last 10 searches
    if (currentHistory.length > 10) {
      currentHistory.removeRange(10, currentHistory.length);
    }
    
    state = currentHistory;
  }
  
  void removeSearch(String query) {
    state = state.where((item) => item != query).toList();
  }
  
  void clearHistory() {
    state = [];
  }
}
