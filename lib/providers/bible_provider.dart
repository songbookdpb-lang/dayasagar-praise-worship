// lib/providers/bible_provider.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/bible_verse_model.dart';
import '../models/pagination_state.dart';
import '../services/persistent_cache_service.dart';

// ============================================================================
// HELPER FUNCTIONS FOR LOCAL SUPPORT (ALL LANGUAGES)
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

bool _isLocal(String language) =>
    _isEnglishLocal(language) ||
    _isHindiLocal(language) ||
    _isOdiaLocal(language);

// ✅ UPDATED: Get asset path for any supported language
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

// ✅ UPDATED: Load any language Bible from asset
Future<List<dynamic>> _loadBibleFromAsset(String language) async {
  try {
    final assetPath = _getAssetPath(language);
    final raw = await rootBundle.loadString(assetPath);
    
    final dynamic jsonData = json.decode(raw);
    
    if (jsonData is List) {
      return jsonData;
    } else if (jsonData is Map<String, dynamic>) {
      // Fallback for old format with "verses" property
      return (jsonData['verses'] as List<dynamic>? ?? []);
    } else {
      throw Exception('Unexpected JSON structure: ${jsonData.runtimeType}');
    }
  } catch (e) {
    debugPrint('Error loading $language Bible from asset: $e');
    return [];
  }
}

// ✅ UPDATED: Get books from any language asset
Future<List<String>> _getBooksFromAsset(String language) async {
  try {
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
    if (kDebugMode) {
      debugPrint('✅ Loaded ${books.length} $language books from asset');
    }
    return books;
  } catch (e) {
    debugPrint('Error getting $language books from asset: $e');
    return [];
  }
}

// ✅ UPDATED: Get chapters from any language asset
Future<List<int>> _getChaptersFromAsset(String language, String bookName) async {
  try {
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
    if (kDebugMode) {
      debugPrint('✅ Loaded ${chapters.length} chapters for $bookName in $language from asset');
    }
    return chapters;
  } catch (e) {
    debugPrint('Error getting $language chapters from asset: $e');
    return [];
  }
}

// ✅ UPDATED: Get verses from any language asset
Future<List<BibleVerse>> _getVersesFromAsset({
  required String language,
  String? book,
  int? chapter,
}) async {
  try {
    final List<dynamic> versesJson = await _loadBibleFromAsset(language);

    List<BibleVerse> verses = [];

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
        
        // Handle both individual verses and merged chapters
        if (vText.contains(RegExp(r'\d+\s+'))) {
          // This is a merged chapter - split into individual verses
          final individualVerses = _splitMergedChapter(vText, vBook, vChapterStr, language);
          verses.addAll(individualVerses);
        } else {
          // This is an individual verse
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

// ✅ UPDATED: Helper function to split merged chapters (with language parameter)
List<BibleVerse> _splitMergedChapter(String mergedText, String book, String chapter, String language) {
  final verses = <BibleVerse>[];
  
  try {
    // Split by verse numbers (assumes format: "text 2 more text 3 even more text")
    final parts = mergedText.split(RegExp(r'\s+(\d+)\s+'));
    
    if (parts.isNotEmpty) {
      // First verse (no number prefix)
      final firstVerseText = parts[0].trim();
      if (firstVerseText.isNotEmpty) {
        verses.add(BibleVerse.fromMap({
          'id': 'local_${language}_${book}_${chapter}_1',
          'book': book,
          'chapter': chapter,
          'verse': firstVerseText,
          'language': language,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        }, 'local_${language}_${book}_${chapter}_1'));
      }
      
      // Subsequent verses
      for (int i = 1; i < parts.length; i += 2) {
        if (i + 1 < parts.length) {
          final verseNumber = int.tryParse(parts[i]) ?? (i ~/ 2 + 2);
          final verseText = parts[i + 1].trim();
          
          if (verseText.isNotEmpty) {
            final id = 'local_${language}_${book}_${chapter}_$verseNumber';
            verses.add(BibleVerse.fromMap({
              'id': id,
              'book': book,
              'chapter': chapter,
              'verse': verseText,
              'language': language,
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            }, id));
          }
        }
      }
    }
  } catch (e) {
    debugPrint('Error splitting merged chapter: $e');
    // Fallback: return the whole text as verse 1
    verses.add(BibleVerse.fromMap({
      'id': 'local_${language}_${book}_${chapter}_1',
      'book': book,
      'chapter': chapter,
      'verse': mergedText,
      'language': language,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }, 'local_${language}_${book}_${chapter}_1'));
  }
  
  return verses;
}

// ============================================================================
// CACHE SERVICE PROVIDER
// ============================================================================

final cacheServiceProvider = Provider<PersistentCacheService>((ref) {
  return PersistentCacheService();
});

// ============================================================================
// BIBLE LANGUAGES PROVIDER (FULLY OFFLINE)
// ============================================================================

final bibleLanguagesProvider =
    StateNotifierProvider<BibleLanguagesNotifier, AsyncValue<List<String>>>(
  (ref) => BibleLanguagesNotifier(),
);

class BibleLanguagesNotifier extends StateNotifier<AsyncValue<List<String>>> {
  BibleLanguagesNotifier() : super(const AsyncValue.loading()) {
    loadLanguages();
  }

  Future<void> loadLanguages({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        state = const AsyncValue.loading();
      }

      // ✅ OFFLINE ONLY: Return supported local languages
      final supportedLanguages = ['English', 'Hindi', 'Odia'];
      state = AsyncValue.data(supportedLanguages);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading languages: $e');
      }
      // Fallback to at least English if asset loading fails
      state = const AsyncValue.data(['English']);
    }
  }

  Future<void> refreshLanguages() async {
    await loadLanguages(forceRefresh: true);
  }

  List<String> get languages {
    return state.whenOrNull(data: (languages) => languages) ?? ['English'];
  }
}

// ============================================================================
// BIBLE BOOKS PROVIDER (FULLY OFFLINE)
// ============================================================================

final bibleBooksProvider = StateNotifierProvider.family<BibleBooksNotifier,
    PaginationState<String>, String>(
  (ref, language) {
    final cacheService = ref.watch(cacheServiceProvider);
    return BibleBooksNotifier(cacheService, language);
  },
);

class BibleBooksNotifier extends StateNotifier<PaginationState<String>> {
  final PersistentCacheService _cacheService;
  final String _language;

  BibleBooksNotifier(this._cacheService, this._language)
      : super(const PaginationState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      state = state.copyWith(
        isLoading: true, 
        error: null,
        isInitialized: false,
      );

      // ✅ OFFLINE ONLY: Always load from local assets
      if (_isLocal(_language)) {
        await _fetchFromAsset();
      } else {
        // Unsupported language - return empty
        state = state.copyWith(
          items: [],
          isLoading: false,
          hasMore: false,
          isFromCache: false,
          isInitialized: true,
          error: 'Language $_language not supported offline',
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
        isInitialized: true,
      );
    }
  }

  Future<void> _fetchFromAsset() async {
    try {
      // Load from cache first
      final cachedBooks = await _loadFromCache();
      if (cachedBooks.isNotEmpty) {
        state = state.copyWith(
          items: cachedBooks,
          isLoading: false,
          isFromCache: true,
          isInitialized: true,
        );
      }

      // Load fresh data from assets
      final books = await _getBooksFromAsset(_language);
      state = state.copyWith(
        items: books,
        isLoading: false,
        hasMore: false,
        isFromCache: false,
        isInitialized: true,
        error: null,
      );

      // Save to cache
      await _saveToCache(books);

      if (kDebugMode) {
        debugPrint('✅ Loaded ${books.length} $_language books from local asset');
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
        isInitialized: true,
      );
    }
  }

  Future<List<String>> _loadFromCache() async {
    try {
      final cached = await _cacheService.get('bible_books_$_language');
      if (cached != null) {
        return cached;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Cache load error: $e');
      }
    }
    return [];
  }

  Future<void> _saveToCache(List<String> books) async {
    try {
      await _cacheService.set(
        'bible_books_$_language',
        books,
        const Duration(days: 30), // Longer cache for offline data
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Cache save error: $e');
      }
    }
  }

  Future<void> refresh() async {
    await _cacheService.delete('bible_books_$_language');
    state = const PaginationState();
    await _loadInitial();
  }

  Future<void> loadNextPage() async {
    // Not needed as we load all books at once from assets
  }
}

// ============================================================================
// BIBLE BOOK SEARCH PROVIDER (FULLY OFFLINE)
// ============================================================================

final bibleBookSearchProvider = StateNotifierProvider.family<
    BibleBookSearchNotifier, AsyncValue<List<String>>, String>(
  (ref, language) => BibleBookSearchNotifier(language),
);

class BibleBookSearchNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final String _language;
  String _lastQuery = '';

  BibleBookSearchNotifier(this._language) : super(const AsyncValue.data([]));

  Future<void> searchBooks(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      _lastQuery = '';
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;

    try {
      state = const AsyncValue.loading();

      // ✅ OFFLINE ONLY: Search in local assets
      if (_isLocal(_language)) {
        final allBooks = await _getBooksFromAsset(_language);
        final matchingBooks = allBooks
            .where((book) => book.toLowerCase().contains(query.toLowerCase()))
            .toList();
        state = AsyncValue.data(matchingBooks);
      } else {
        // Unsupported language
        state = const AsyncValue.data([]);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void clearSearch() {
    state = const AsyncValue.data([]);
    _lastQuery = '';
  }
}

// ============================================================================
// BIBLE CHAPTERS PROVIDER (FULLY OFFLINE)
// ============================================================================

class ChapterParams {
  final String language;
  final String bookName;

  ChapterParams({required this.language, required this.bookName});

  @override
  bool operator ==(Object other) {
    return other is ChapterParams &&
        other.language == language &&
        other.bookName == bookName;
  }

  @override
  int get hashCode => language.hashCode ^ bookName.hashCode;

  @override
  String toString() =>
      'ChapterParams(language: $language, bookName: $bookName)';
}

final bibleChaptersProvider = StateNotifierProvider.family<
    BibleChaptersNotifier, PaginationState<int>, ChapterParams>(
  (ref, params) {
    final cacheService = ref.watch(cacheServiceProvider);
    return BibleChaptersNotifier(cacheService, params);
  },
);

class BibleChaptersNotifier extends StateNotifier<PaginationState<int>> {
  final PersistentCacheService _cacheService;
  final ChapterParams _params;

  BibleChaptersNotifier(this._cacheService, this._params)
      : super(const PaginationState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      state = state.copyWith(
        isLoading: true, 
        error: null,
        isInitialized: false,
      );

      // ✅ OFFLINE ONLY: Always load from local assets
      if (_isLocal(_params.language)) {
        await _fetchFromAsset();
      } else {
        // Unsupported language
        state = state.copyWith(
          items: [],
          isLoading: false,
          hasMore: false,
          isFromCache: false,
          isInitialized: true,
          error: 'Language ${_params.language} not supported offline',
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
        isInitialized: true,
      );
    }
  }

  Future<void> _fetchFromAsset() async {
    try {
      // Load from cache first
      final cachedChapters = await _loadFromCache();
      if (cachedChapters.isNotEmpty) {
        state = state.copyWith(
          items: cachedChapters,
          isLoading: false,
          isFromCache: true,
          isInitialized: true,
        );
      }

      // Load fresh data from assets
      final chapters = await _getChaptersFromAsset(_params.language, _params.bookName);
      state = state.copyWith(
        items: chapters,
        isLoading: false,
        hasMore: false,
        isFromCache: false,
        isInitialized: true,
        error: null,
      );

      // Save to cache
      await _saveToCache(chapters);

      if (kDebugMode) {
        debugPrint(
            '✅ Loaded ${chapters.length} ${_params.language} chapters for ${_params.bookName} from local asset');
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
        isInitialized: true,
      );
    }
  }

  Future<List<int>> _loadFromCache() async {
    try {
      final cacheKey = 'bible_chapters_${_params.language}_${_params.bookName}';
      final cached = await _cacheService.get(cacheKey);
      if (cached != null) {
        return cached.map((e) => int.tryParse(e) ?? 0).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Cache load error: $e');
      }
    }
    return [];
  }

  Future<void> _saveToCache(List<int> chapters) async {
    try {
      final cacheKey = 'bible_chapters_${_params.language}_${_params.bookName}';
      await _cacheService.set(
        cacheKey,
        chapters.map((e) => e.toString()).toList(),
        const Duration(days: 30), // Longer cache for offline data
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Cache save error: $e');
      }
    }
  }

  Future<void> refresh() async {
    final cacheKey = 'bible_chapters_${_params.language}_${_params.bookName}';
    await _cacheService.delete(cacheKey);
    state = const PaginationState();
    await _loadInitial();
  }

  Future<void> loadNextPage() async {
    // Not needed as we load all chapters at once from assets
  }
}

// ============================================================================
// BIBLE VERSES PROVIDERS (FULLY OFFLINE)
// ============================================================================

// Provider for Bible verses by language
final bibleVersesByLanguageProvider =
    StreamProvider.family<List<BibleVerse>, String>((ref, language) {
  // ✅ OFFLINE ONLY: Always return from local data
  return Stream.fromFuture(_getVersesFromAsset(language: language));
});

// Provider for verses by book and language
final bibleVersesByBookProvider =
    StreamProvider.family<List<BibleVerse>, ({String book, String language})>(
        (ref, params) {
  // ✅ OFFLINE ONLY: Always return from local data
  return Stream.fromFuture(_getVersesFromAsset(
    language: params.language,
    book: params.book,
  ));
});

// Provider for verses by chapter, book, and language
final bibleVersesByChapterProvider = FutureProvider.family<List<BibleVerse>,
    ({String language, String book, String chapter})>((ref, params) async {
  try {
    // ✅ OFFLINE ONLY: Always load from local assets
    final chapterNum = int.tryParse(params.chapter);
    if (chapterNum == null) return [];

    return await _getVersesFromAsset(
      language: params.language,
      book: params.book,
      chapter: chapterNum,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Error fetching verses by chapter: $e');
    }
    rethrow;
  }
});

// Provider for single Bible verse by ID
final bibleVerseByIdProvider =
    FutureProvider.family<BibleVerse?, String>((ref, id) async {
  try {
    // ✅ OFFLINE ONLY: Handle local IDs only
    if (id.startsWith('local_')) {
      final parts = id.split('_');
      if (parts.length >= 5) { // local_language_book_chapter_verse
        final language = parts[1];
        final book = parts[2];
        final chapter = int.tryParse(parts as String);
        
        if (chapter != null) {
          final verses = await _getVersesFromAsset(
            language: language,
            book: book, 
            chapter: chapter,
          );
          // Find the specific verse
          for (final v in verses) {
            if (v.id == id) return v;
          }
        }
      }
    }
    return null;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Error fetching verse by ID: $e');
    }
    return null;
  }
});

// Provider for available Bible languages (OFFLINE ONLY)
final availableBibleLanguagesProvider =
    FutureProvider<List<String>>((ref) async {
  // ✅ OFFLINE ONLY: Return supported local languages
  return ['English', 'Hindi', 'Odia'];
});

// ============================================================================
// BIBLE SEARCH PROVIDER (FULLY OFFLINE)
// ============================================================================

final bibleSearchProvider =
    StateNotifierProvider<BibleSearchNotifier, AsyncValue<List<BibleVerse>>>(
  (ref) => BibleSearchNotifier(),
);

class BibleSearchNotifier extends StateNotifier<AsyncValue<List<BibleVerse>>> {
  String _lastQuery = '';

  BibleSearchNotifier() : super(const AsyncValue.data([]));

  Future<void> searchVerses(String query, {String? language}) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      _lastQuery = '';
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;

    try {
      state = const AsyncValue.loading();

      // ✅ OFFLINE ONLY: Search in local assets
      if (language != null && _isLocal(language)) {
        final allVerses = await _getVersesFromAsset(language: language);
        final results = allVerses
            .where((verse) =>
                verse.verse.toLowerCase().contains(query.toLowerCase()))
            .take(50)
            .toList();

        // Sort by relevance
        results.sort((a, b) {
          final aExact = a.verse.toLowerCase() == query.toLowerCase();
          final bExact = b.verse.toLowerCase() == query.toLowerCase();

          if (aExact && !bExact) return -1;
          if (!aExact && bExact) return 1;

          return a.book.compareTo(b.book);
        });

        state = AsyncValue.data(results);
      } else {
        // Unsupported language or no language specified
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error searching verses: $e');
      }
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void clearSearch() {
    state = const AsyncValue.data([]);
    _lastQuery = '';
  }
}

// ============================================================================
// CONVENIENCE PROVIDERS FOR DIRECT ACCESS (FULLY OFFLINE)
// ============================================================================

// Provider to get unique books from verses collection
final bibleBooksFromVersesProvider =
    FutureProvider.family<List<String>, String>((ref, language) async {
  try {
    // ✅ OFFLINE ONLY: Always load from local assets
    return await _getBooksFromAsset(language);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Error fetching books from verses: $e');
    }
    rethrow;
  }
});

// Provider to get unique chapters for a specific book and language
final bibleChaptersFromVersesProvider =
    FutureProvider.family<List<String>, Map<String, String>>(
        (ref, params) async {
  try {
    final String language = params['language']!;
    final String book = params['book']!;

    // ✅ OFFLINE ONLY: Always load from local assets
    final chapters = await _getChaptersFromAsset(language, book);
    return chapters.map((c) => c.toString()).toList();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Error fetching chapters from verses: $e');
    }
    rethrow;
  }
});
