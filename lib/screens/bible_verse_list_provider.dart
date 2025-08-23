import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pagination_state.dart';
import '../../models/bible_verse_model.dart';
class VerseScreenListParams {
  final String language;
  final String book;
  final String chapter;

  VerseScreenListParams({
    required this.language,
    required this.book,
    required this.chapter,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VerseScreenListParams &&
        other.language == language &&
        other.book == book &&
        other.chapter == chapter;
  }

  @override
  int get hashCode => language.hashCode ^ book.hashCode ^ chapter.hashCode;

  @override
  String toString() => 'VerseParams($language, $book, $chapter)';
}

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
  return lang.startsWith('od') || lang == 'odia';
}

bool _isLocal(String language) =>
    _isEnglishLocal(language) ||
    _isHindiLocal(language) ||
    _isOdiaLocal(language);
class BibleVerseListNotifier extends StateNotifier<PaginationState<BibleVerse>> {
  BibleVerseListNotifier(this._params)
      : super(const PaginationState(
          items: [],
          isLoading: true,
          hasMore: false,
          isFromCache: true,
          error: null,
        )) {
    _loadVerses();
  }

  final VerseScreenListParams _params;

  bool get canLoadMore => false; 
  Future<void> _loadVerses() async {
    try {
      final verses = await _fetchLocalVerses();

      if (mounted) {
        state = PaginationState(
          items: verses,
          isLoading: false,
          hasMore: false,
          isFromCache: true,
          error: null,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadVerses();
  }

  Future<List<BibleVerse>> _fetchLocalVerses() async {
    try {
      final assetPath = _getAssetPath(_params.language);
      final jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonData = json.decode(jsonString);

      final verses = <BibleVerse>[];

      for (final item in jsonData) {
        if (item is Map<String, dynamic>) {
          final book = item['book']?.toString() ?? '';
          final chapter = item['chapter']?.toString() ?? '';
          final verseText = item['verse']?.toString() ?? '';
          final language = item['language']?.toString() ?? '';
          final createdAtStr = item['createdAt']?.toString() ?? '';

          if (book == _params.book && chapter == _params.chapter) {
            if (verseText.isNotEmpty) {
              verses.add(BibleVerse(
                id: '${language}_${book}_$chapter',
                book: book,
                chapter: chapter,
                verse: verseText,
                language: language,
                createdAt: createdAtStr.isNotEmpty 
                    ? DateTime.parse(createdAtStr)
                    : DateTime.now(),
              ));
            }
          }
        }
      }

      return verses;
    } catch (e) {
      throw Exception('Failed to load verses from ${_getAssetPath(_params.language)}: $e');
    }
  }

  String _getAssetPath(String language) {
    if (_isEnglishLocal(language)) {
      return 'assets/bible/EN-English/asv.json';
    } else if (_isHindiLocal(language)) {
      return 'assets/bible/HI-Hindi/asv.json';
    } else if (_isOdiaLocal(language)) {
      return 'assets/bible/OD-Odia/asv.json';
    } else {
      return 'assets/bible/EN-English/asv.json';
    }
  }

  Future<void> loadNextPage() async {
    return;
  }
}
final screenBibleVerseListProvider = StateNotifierProvider.family<
    BibleVerseListNotifier, PaginationState<BibleVerse>, VerseScreenListParams>(
  (ref, params) => BibleVerseListNotifier(params),
);

final isSupportedLanguageProvider = Provider.family<bool, String>((ref, language) {
  return _isLocal(language);
});

final assetPathProvider = Provider.family<String, String>((ref, language) {
  if (_isEnglishLocal(language)) {
    return 'assets/bible/EN-English/asv.json';
  } else if (_isHindiLocal(language)) {
    return 'assets/bible/HI-Hindi/asv.json';
  } else if (_isOdiaLocal(language)) {
    return 'assets/bible/OD-Odia/asv.json';
  } else {
    return 'assets/bible/EN-English/asv.json';
  }
});
