// lib/features/songs/song_list_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_models.dart';
import '../../services/firestore_service.dart';

// Pagination state for songs
class SongsPaginationState {
  final List<Song> songs;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  SongsPaginationState({
    required this.songs,
    required this.isLoading,
    required this.hasMore,
    this.error,
  });

  SongsPaginationState copyWith({
    List<Song>? songs,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return SongsPaginationState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
    );
  }
}

// Provider for search query
final songSearchQueryProvider = StateProvider.family<String, String>(
  (ref, language) => '',
);

// Provider for pagination
final songsPaginationProvider =
    StateNotifierProvider.family<
      SongsPaginationNotifier,
      SongsPaginationState,
      String
    >((ref, language) => SongsPaginationNotifier(ref, language));

// Provider for search results
final songSearchResultsProvider = FutureProvider.family<List<Song>, String>((
  ref,
  language,
) async {
  final query = ref.watch(songSearchQueryProvider(language));
  if (query.isEmpty) return [];

  try {
    final firestoreService = ref.read(firestoreServiceProvider);
    return await firestoreService.searchSongs(query, language);
  } catch (e) {
    return [];
  }
});

class SongsPaginationNotifier extends StateNotifier<SongsPaginationState> {
  final Ref ref;
  final String language;
  static const int pageSize = 20;

  SongsPaginationNotifier(this.ref, this.language)
    : super(SongsPaginationState(songs: [], isLoading: false, hasMore: true)) {
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.delayed(const Duration(milliseconds: 100));
    await fetchNextPage();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // FIXED: Use the correct method that exists in your FirestoreService
      // Try one of these methods based on what exists in your FirestoreService:

      // Option 1: If you have a stream method, use .first to get a Future
      final songsStream = firestoreService
          .getSongs(); // or getSongsByLanguage if it exists
      final allSongs = await songsStream.first;

      // Filter by language if needed
      final languageSongs = allSongs
          .where((song) => song.language == language)
          .toList();

      // FIXED: Implement simple pagination by slicing the list
      final startIndex = state.songs.length;
      // REMOVED: unused endIndex variable

      // Get the next page of songs
      final newSongs = languageSongs.skip(startIndex).take(pageSize).toList();

      // FIXED: Proper list concatenation with correct types
      final updatedSongs = <Song>[...state.songs, ...newSongs];
      final hasMore = newSongs.length == pageSize;

      state = state.copyWith(
        songs: updatedSongs,
        isLoading: false,
        hasMore: hasMore,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load songs: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    state = SongsPaginationState(
      songs: [],
      isLoading: false,
      hasMore: true,
      error: null,
    );
    await fetchNextPage();
  }

  Future<void> loadInitialData() async {
    if (state.songs.isEmpty && !state.isLoading) {
      await fetchNextPage();
    }
  }
}
