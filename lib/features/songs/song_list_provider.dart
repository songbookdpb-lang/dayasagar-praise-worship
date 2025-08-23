import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_models.dart';
import '../../services/incremental_sync_service.dart';

final cachedSongsProvider = StreamProvider.family<List<Song>, String>((ref, language) {
  final syncService = ref.read(incrementalSyncServiceProvider);
  return syncService.watchCachedSongsByLanguage(language);
});

final allCachedSongsProvider = StreamProvider<List<Song>>((ref) {
  final syncService = ref.read(incrementalSyncServiceProvider);
  return syncService.watchCachedSongs();
});

final songByIdProvider = FutureProvider.family<Song?, String>((ref, songId) async {
  final syncService = ref.read(incrementalSyncServiceProvider);
  return await syncService.getCachedSongById(songId);
});

final songSearchQueryProvider = StateProvider.family<String, String>(
  (ref, language) => '',
);

final globalSongSearchQueryProvider = StateProvider<String>((ref) => '');

final songSearchResultsProvider = FutureProvider.family<List<Song>, String>((
  ref,
  language,
) async {
  final query = ref.watch(songSearchQueryProvider(language));
  if (query.isEmpty) return [];

  try {
    final syncService = ref.read(incrementalSyncServiceProvider);
    final allSongs = await syncService.getCachedSongsByLanguage(language);
    final queryLower = query.toLowerCase();
    
    return allSongs.where((song) =>
      song.songName.toLowerCase().contains(queryLower) ||
      song.lyrics.toLowerCase().contains(queryLower)
    ).toList();
  } catch (e) {
    return [];
  }
});

final globalSongSearchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(globalSongSearchQueryProvider);
  if (query.isEmpty) return [];
  
  try {
    final syncService = ref.read(incrementalSyncServiceProvider);
    return await syncService.searchCachedSongs(query.trim());
  } catch (e) {
    return [];
  }
});

final globalSongSearchProvider = FutureProvider.family<List<Song>, String>((ref, query) async {
  if (query.isEmpty) return [];
  
  try {
    final syncService = ref.read(incrementalSyncServiceProvider);
    return await syncService.searchCachedSongs(query);
  } catch (e) {
    return [];
  }
});

final songCountByLanguageProvider = FutureProvider.family<int, String>((ref, language) async {
  try {
    final syncService = ref.read(incrementalSyncServiceProvider);
    final songs = await syncService.getCachedSongsByLanguage(language);
    return songs.length;
  } catch (e) {
    return 0;
  }
});

final totalSongsCountProvider = FutureProvider<int>((ref) async {
  try {
    final syncService = ref.read(incrementalSyncServiceProvider);
    final songs = await syncService.getAllCachedSongs();
    return songs.length;
  } catch (e) {
    return 0;
  }
});

final cacheStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  try {
    final syncService = ref.read(incrementalSyncServiceProvider);
    return await syncService.getCacheStatsByLanguage();
  } catch (e) {
    return {};
  }
});

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  return SyncStatusNotifier(ref.read(incrementalSyncServiceProvider));
});

class SyncStatus {
  final bool isLoading;
  final bool hasError;
  final String? error;
  final DateTime? lastSyncTime;
  final int totalSongs;

  SyncStatus({
    this.isLoading = false,
    this.hasError = false,
    this.error,
    this.lastSyncTime,
    this.totalSongs = 0,
  });

  SyncStatus copyWith({
    bool? isLoading,
    bool? hasError,
    String? error,
    DateTime? lastSyncTime,
    int? totalSongs,
  }) {
    return SyncStatus(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      error: error ?? this.error,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      totalSongs: totalSongs ?? this.totalSongs,
    );
  }
}

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  final IncrementalSyncService _syncService;

  SyncStatusNotifier(this._syncService) : super(SyncStatus());

  Future<void> performSync() async {
    state = state.copyWith(isLoading: true, hasError: false, error: null);
    
    try {
      final result = await _syncService.performIncrementalSync();
      
      if (result.success) {
        final totalSongs = await _syncService.getAllCachedSongs();
        state = state.copyWith(
          isLoading: false,
          lastSyncTime: DateTime.now(),
          totalSongs: totalSongs.length,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          hasError: true,
          error: result.error ?? 'Sync failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        error: e.toString(),
      );
    }
  }

  Future<void> forceSync() async {
    state = state.copyWith(isLoading: true, hasError: false, error: null);
    
    try {
      await _syncService.forceSyncAll();
      final totalSongs = await _syncService.getAllCachedSongs();
      state = state.copyWith(
        isLoading: false,
        lastSyncTime: DateTime.now(),
        totalSongs: totalSongs.length,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        error: e.toString(),
      );
    }
  }
}

final songsPaginationProvider =
    StateNotifierProvider.family<
      SongsPaginationNotifier,
      PaginationState<Song>,
      String
    >((ref, language) => SongsPaginationNotifier(ref, language));

class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final bool isFromCache;
  final bool isInitialized;
  final int currentPage;
  final dynamic error;

  const PaginationState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = false,
    this.isFromCache = false,
    this.isInitialized = false,
    this.currentPage = 0,
    this.error,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    bool? isFromCache,
    bool? isInitialized,
    int? currentPage,
    dynamic error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      isFromCache: isFromCache ?? this.isFromCache,
      isInitialized: isInitialized ?? this.isInitialized,
      currentPage: currentPage ?? this.currentPage,
      error: error ?? this.error,
    );
  }
}

class SongsPaginationNotifier extends StateNotifier<PaginationState<Song>> {
  final Ref ref;
  final String language;
  final IncrementalSyncService _syncService = IncrementalSyncService.instance;
  static const int pageSize = 20;

  SongsPaginationNotifier(this.ref, this.language)
    : super(const PaginationState<Song>()) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.delayed(const Duration(milliseconds: 100));
    await loadInitialData();
  }

  Future<void> loadInitialData() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final cachedSongs = await _syncService.getCachedSongsByLanguage(language);
      
      if (cachedSongs.isNotEmpty) {
        final initialItems = cachedSongs.take(pageSize).toList();
        state = state.copyWith(
          items: initialItems,
          isLoading: false,
          isFromCache: true,
          isInitialized: true,
          hasMore: cachedSongs.length > pageSize,
          currentPage: 1,
        );
      }

      _syncService.performIncrementalSync();
      
      if (cachedSongs.isEmpty) {
        final songs = await _syncService.getCachedSongsByLanguage(language);
        final initialItems = songs.take(pageSize).toList();
        state = state.copyWith(
          items: initialItems,
          isLoading: false,
          isFromCache: false,
          isInitialized: true,
          hasMore: songs.length > pageSize,
          currentPage: 1,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load songs: ${e.toString()}',
      );
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final allCachedSongs = await _syncService.getCachedSongsByLanguage(language);
      
      final startIndex = state.items.length;
      final endIndex = (startIndex + pageSize).clamp(0, allCachedSongs.length);
      
      final newItems = allCachedSongs.sublist(startIndex, endIndex);
      
      final updatedItems = <Song>[...state.items, ...newItems];
      final hasMore = endIndex < allCachedSongs.length;

      state = state.copyWith(
        items: updatedItems,
        isLoading: false,
        hasMore: hasMore,
        currentPage: state.currentPage + 1,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load more songs: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    state = const PaginationState<Song>();
    
    await _syncService.performIncrementalSync();
    
    ref.invalidate(cachedSongsProvider(language));
    
    await loadInitialData();
  }

  void clearSongs() {
    state = const PaginationState<Song>();
  }
}

final songsLoadingStateProvider = Provider.family<bool, String>((ref, language) {
  final paginationState = ref.watch(songsPaginationProvider(language));
  return paginationState.isLoading;
});

final songsErrorProvider = Provider.family<String?, String>((ref, language) {
  final paginationState = ref.watch(songsPaginationProvider(language));
  return paginationState.error?.toString();
});

final hasMoreSongsProvider = Provider.family<bool, String>((ref, language) {
  final paginationState = ref.watch(songsPaginationProvider(language));
  return paginationState.hasMore;
});

final autoSyncProvider = StreamProvider<void>((ref) async* {
  while (true) {
    await Future.delayed(const Duration(minutes: 5));
    try {
      final syncService = ref.read(incrementalSyncServiceProvider);
      await syncService.performIncrementalSync();
    } catch (e) {
      // ✅ FIXED: Added error logging instead of empty catch
      print('Auto-sync error: $e');
    }
    yield null;
  }
});

final songSortProvider = StateProvider<SongSortType>((ref) => SongSortType.nameAsc);

enum SongSortType { nameAsc, nameDesc, dateAsc, dateDesc, languageAsc, languageDesc }

final sortedSongsProvider = Provider.family<List<Song>, String>((ref, language) {
  final songs = ref.watch(cachedSongsProvider(language)).value ?? [];
  final sortType = ref.watch(songSortProvider);
  
  final sortedList = List<Song>.from(songs);
  
  switch (sortType) {
    case SongSortType.nameAsc:
      sortedList.sort((a, b) => a.songName.compareTo(b.songName));
      break;
    case SongSortType.nameDesc:
      sortedList.sort((a, b) => b.songName.compareTo(a.songName));
      break;
    case SongSortType.dateAsc:
      sortedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      break;
    case SongSortType.dateDesc:
      sortedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case SongSortType.languageAsc:
      sortedList.sort((a, b) => a.language.compareTo(b.language));
      break;
    case SongSortType.languageDesc:
      sortedList.sort((a, b) => b.language.compareTo(a.language));
      break;
  }
  
  return sortedList;
});

final favoritesongsProvider = StateNotifierProvider<FavoriteSongsNotifier, List<String>>((ref) {
  return FavoriteSongsNotifier();
});

class FavoriteSongsNotifier extends StateNotifier<List<String>> {
  FavoriteSongsNotifier() : super([]);

  void addFavorite(String songId) {
    if (!state.contains(songId)) {
      state = [...state, songId];
    }
  }

  void removeFavorite(String songId) {
    state = state.where((id) => id != songId).toList();
  }

  bool isFavorite(String songId) {
    return state.contains(songId);
  }

  void toggleFavorite(String songId) {
    if (isFavorite(songId)) {
      removeFavorite(songId);
    } else {
      addFavorite(songId);
    }
  }
}

final favoriteSongsListProvider = Provider<List<Song>>((ref) {
  final favoriteIds = ref.watch(favoritesongsProvider);
  final allSongs = ref.watch(allCachedSongsProvider).value ?? [];
  
  return allSongs.where((song) => favoriteIds.contains(song.id)).toList();
});

final recentlyPlayedProvider = StateNotifierProvider<RecentlyPlayedNotifier, List<String>>((ref) {
  return RecentlyPlayedNotifier();
});

class RecentlyPlayedNotifier extends StateNotifier<List<String>> {
  RecentlyPlayedNotifier() : super([]);

  void addRecentSong(String songId) {
    final newState = [songId, ...state.where((id) => id != songId)];
    state = newState.take(50).toList();
  }

  void clearRecent() {
    state = [];
  }
}

final recentlyPlayedSongsProvider = Provider<List<Song>>((ref) {
  final recentIds = ref.watch(recentlyPlayedProvider);
  final allSongs = ref.watch(allCachedSongsProvider).value ?? [];
  
  return recentIds
      .map((id) {
        try {
          return allSongs.firstWhere((song) => song.id == id);
        } catch (e) {
          // ✅ FIXED: Return null instead of throwing, then filter out nulls
          return null;
        }
      })
      .where((song) => song != null) // ✅ FIXED: This comparison is now valid
      .cast<Song>()
      .toList();
});

final songStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final allSongs = ref.watch(allCachedSongsProvider).value ?? [];
  final favorites = ref.watch(favoritesongsProvider);
  final recent = ref.watch(recentlyPlayedProvider);
  
  final languageStats = <String, int>{};
  for (final song in allSongs) {
    languageStats[song.language] = (languageStats[song.language] ?? 0) + 1;
  }
  
  return {
    'totalSongs': allSongs.length,
    'favoritesCount': favorites.length,
    'recentCount': recent.length,
    'languageStats': languageStats,
    'mostPopularLanguage': languageStats.isNotEmpty 
        ? languageStats.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : null,
  };
});

final offlineAvailableProvider = Provider.family<bool, String>((ref, songId) {
  final song = ref.watch(songByIdProvider(songId)).value;
  return song != null && !song.isDeleted;
});

final cacheSizeProvider = FutureProvider<double>((ref) async {
  try {
    final syncService = ref.read(incrementalSyncServiceProvider);
    final status = await syncService.getCacheStatus();
    return (status['totalSongs'] as int) * 0.1;
  } catch (e) {
    return 0.0;
  }
});

final languageListProvider = Provider<List<String>>((ref) {
  final allSongs = ref.watch(allCachedSongsProvider).value ?? [];
  return allSongs.map((song) => song.language).toSet().toList()..sort();
});

final songsFilterProvider = StateProvider<SongFilter>((ref) => SongFilter());

class SongFilter {
  final String? language;
  final bool? isFavorite;
  final DateTime? fromDate;
  final DateTime? toDate;

  SongFilter({this.language, this.isFavorite, this.fromDate, this.toDate});

  SongFilter copyWith({String? language, bool? isFavorite, DateTime? fromDate, DateTime? toDate}) {
    return SongFilter(
      language: language ?? this.language,
      isFavorite: isFavorite ?? this.isFavorite,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }
}

final filteredSongsProvider = Provider<List<Song>>((ref) {
  final allSongs = ref.watch(allCachedSongsProvider).value ?? [];
  final filter = ref.watch(songsFilterProvider);
  final favorites = ref.watch(favoritesongsProvider);
  
  return allSongs.where((song) {
    if (filter.language != null && song.language != filter.language) return false;
    if (filter.isFavorite == true && !favorites.contains(song.id)) return false;
    if (filter.isFavorite == false && favorites.contains(song.id)) return false;
    
    // ✅ FIXED: Convert Timestamp to DateTime before comparison
    if (filter.fromDate != null && song.createdAt.toDate().isBefore(filter.fromDate!)) return false;
    if (filter.toDate != null && song.createdAt.toDate().isAfter(filter.toDate!)) return false;
    
    return true;
  }).toList();
});

final batchOperationsProvider = StateNotifierProvider<BatchOperationsNotifier, BatchOperationsState>((ref) {
  return BatchOperationsNotifier(ref);
});

class BatchOperationsState {
  final List<String> selectedSongs;
  final bool isSelectionMode;

  BatchOperationsState({this.selectedSongs = const [], this.isSelectionMode = false});

  BatchOperationsState copyWith({List<String>? selectedSongs, bool? isSelectionMode}) {
    return BatchOperationsState(
      selectedSongs: selectedSongs ?? this.selectedSongs,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
    );
  }
}

class BatchOperationsNotifier extends StateNotifier<BatchOperationsState> {
  final Ref ref;

  BatchOperationsNotifier(this.ref) : super(BatchOperationsState());

  void toggleSelectionMode() {
    state = state.copyWith(
      isSelectionMode: !state.isSelectionMode,
      selectedSongs: state.isSelectionMode ? [] : state.selectedSongs,
    );
  }

  void toggleSongSelection(String songId) {
    final isSelected = state.selectedSongs.contains(songId);
    final newSelection = isSelected
        ? state.selectedSongs.where((id) => id != songId).toList()
        : [...state.selectedSongs, songId];
    
    state = state.copyWith(selectedSongs: newSelection);
  }

  void selectAll(List<String> songIds) {
    state = state.copyWith(selectedSongs: songIds);
  }

  void clearSelection() {
    state = state.copyWith(selectedSongs: []);
  }

  void addSelectedToFavorites() {
    final favoritesNotifier = ref.read(favoritesongsProvider.notifier);
    for (final songId in state.selectedSongs) {
      favoritesNotifier.addFavorite(songId);
    }
    clearSelection();
  }

  void removeSelectedFromFavorites() {
    final favoritesNotifier = ref.read(favoritesongsProvider.notifier);
    for (final songId in state.selectedSongs) {
      favoritesNotifier.removeFavorite(songId);
    }
    clearSelection();
  }
}
