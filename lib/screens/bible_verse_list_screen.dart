import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/pagination_state.dart';
import 'bible_verse_list_provider.dart' as screen_providers;
import '../models/bible_verse_model.dart';

// ============================================================================
// Language Detection Helpers
// ============================================================================

bool _isEnglishLocal(String language) {
  final lang = language.trim().toLowerCase();
  return lang == 'english' || lang == 'en-english';
}

bool _isHindiLocal(String language) {
  final lang = language.trim().toLowerCase();
  return lang.startsWith('hi');
}

bool _isOdiaLocal(String language) {
  final lang = language.trim().toLowerCase();
  return lang.startsWith('or') || lang.startsWith('od');
}

bool _isLocal(String language) =>
    _isEnglishLocal(language) ||
    _isHindiLocal(language) ||
    _isOdiaLocal(language);

// ============================================================================
// Verse Splitting Helper
// ============================================================================

/// Splits a verse field like "1 ... 2 ... 3 ..." into a Map<verseNum, text>
List<MapEntry<int, String>> splitIntoVerses(String combined) {
  final regExp = RegExp(r'(\d+)\s'); // matches number followed by space
  final matches = regExp.allMatches(combined);

  if (matches.isEmpty) {
    // No verse numbers found, treat whole string as one verse
    return [MapEntry(1, combined)];
  }

  List<MapEntry<int, String>> verses = [];
  for (int i = 0; i < matches.length; i++) {
    final current = matches.elementAt(i);
    final verseNum = int.parse(current.group(1)!);

    // Determine start index of verse text
    final start = current.end;
    final end = (i < matches.length - 1)
        ? matches.elementAt(i + 1).start
        : combined.length;

    final text = combined.substring(start, end).trim();
    verses.add(MapEntry(verseNum, text));
  }
  return verses;
}

class BibleVerseListScreen extends ConsumerStatefulWidget {
  final String language;
  final String bookName;
  final String chapterNumber;

  const BibleVerseListScreen({
    super.key,
    required this.language,
    required this.bookName,
    required this.chapterNumber,
  });

  @override
  ConsumerState<BibleVerseListScreen> createState() =>
      _BibleVerseListScreenState();
}

class _BibleVerseListScreenState extends ConsumerState<BibleVerseListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  double _fontSize = 18.0;
  List<BibleVerse> _filteredVerses = [];

  late final screen_providers.VerseScreenListParams _params;

  @override
  void initState() {
    super.initState();
    _params = screen_providers.VerseScreenListParams(
      language: widget.language,
      book: widget.bookName,
      chapter: widget.chapterNumber,
    );
    _searchController.addListener(() {
      if (mounted) {
        _filterVerses(_searchController.text);
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(
          screen_providers.screenBibleVerseListProvider(_params).notifier);
      if (notifier.canLoadMore) {
        notifier.loadNextPage();
      }
    }
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredVerses.clear();
        _searchFocusNode.unfocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _searchFocusNode.canRequestFocus) {
            _searchFocusNode.requestFocus();
          }
        });
      }
    });
  }

  void _filterVerses(String query) {
    if (!mounted) return;
    final versesState =
        ref.read(screen_providers.screenBibleVerseListProvider(_params));

    if (query.isEmpty) {
      setState(() => _filteredVerses.clear());
    } else {
      final verses = versesState.items;
      setState(() {
        _filteredVerses = verses
            .where(
              (verse) =>
                  verse.verse.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      });
    }
  }

  void _increaseFontSize() {
    if (_fontSize < 34.0) setState(() => _fontSize += 2.0);
  }

  void _decreaseFontSize() {
    if (_fontSize > 14.0) setState(() => _fontSize -= 2.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF23232B) : const Color(0xFFFAF3E7);
    final versesState =
        ref.watch(screen_providers.screenBibleVerseListProvider(_params));

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _isSearching && mounted) _toggleSearch();
      },
      child: ColoredBox(
        color: bgColor,
        child: Theme(
          data: Theme.of(context).copyWith(
            textTheme:
                Theme.of(context).textTheme.apply(fontFamily: 'Merriweather'),
            // ✅ FORCE NO UNDERLINES ANYWHERE
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(decoration: TextDecoration.none),
              ),
            ),
            cardTheme: const CardThemeData(
              color: Colors.transparent,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              shadowColor: Colors.transparent,
            ),
            listTileTheme: const ListTileThemeData(
              tileColor: Colors.transparent,
              selectedTileColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            scaffoldBackgroundColor: Colors.transparent,
            canvasColor: Colors.transparent,
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: SafeArea(
            child: _buildScrollableContent(versesState, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableContent(
      PaginationState<BibleVerse> versesState, bool isDark) {
    if (versesState.isLoading && versesState.items.isEmpty) {
      return _buildLoadingState(isDark);
    } else if (versesState.error != null && versesState.items.isEmpty) {
      return _buildErrorState(versesState.error!, isDark);
    } else if (versesState.items.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        if (mounted) {
          await ref
              .read(screen_providers
                  .screenBibleVerseListProvider(_params)
                  .notifier)
              .refresh();
        }
      },
      color: isDark ? Colors.amber[300] : Colors.brown,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _buildScrollableHeader(versesState, isDark),
          ),
          if (_isSearching)
            SliverToBoxAdapter(
              child: _buildSearchBar(isDark),
            ),
          SliverToBoxAdapter(
            child: _isSearching
                ? _buildSearchResults(isDark)
                : _buildVersesList(versesState.items, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableHeader(
      PaginationState<BibleVerse> versesState, bool isDark) {
    String subtitle;
    if (versesState.isLoading) {
      subtitle = _isLocal(widget.language)
          ? 'Loading verses from local data...'
          : 'Loading verses from server...';
    } else if (versesState.error != null) {
      subtitle = 'Browse verses in ${widget.bookName}';
    } else {
      final source = _isLocal(widget.language) ? 'offline' : 'online';
      subtitle = '${versesState.items.length} verses • $source • ${widget.language}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
                child: Text(
                  '← Back',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.amber[200] : Colors.brown,
                    decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
                  ),
                ),
              ),
              const Spacer(),
              // ✅ ADDED: Offline indicator for local languages
              if (_isLocal(widget.language))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2), // ✅ FIXED: withValues
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OFFLINE',
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Colors.green,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              if (_isLocal(widget.language)) const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleSearch,
                child: Text(
                  _isSearching ? 'Close' : 'Search',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.amber[200] : Colors.brown,
                    decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
                  ),
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(screen_providers
                          .screenBibleVerseListProvider(_params)
                          .notifier)
                      .refresh();
                },
                child: Text(
                  'Refresh',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.amber[200] : Colors.brown,
                    decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            '${widget.bookName} ${widget.chapterNumber}',
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: isDark ? Colors.white : const Color(0xFF2B1810),
              height: 1.2,
              decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF6D5742),
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: TextStyle(
          fontFamily: 'Merriweather',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF2B1810),
          decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
        ),
        decoration: InputDecoration(
          hintText: 'Search verses in this chapter...',
          hintStyle: TextStyle(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white54 : const Color(0xFF6D5742),
            decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
          ),
          border: UnderlineInputBorder(
            borderSide: BorderSide(
              color: isDark ? Colors.amber[300]! : Colors.brown,
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: isDark ? Colors.amber[200]! : Colors.brown,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onSubmitted: (value) {
          HapticFeedback.selectionClick();
          _filterVerses(value);
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_searchController.text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            'Enter search terms to find verses',
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white70 : const Color(0xFF6D5742),
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
            ),
          ),
        ),
      );
    }

    if (_filteredVerses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Text(
                'No verses found',
                style: TextStyle(
                  fontFamily: 'Merriweather',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white70 : const Color(0xFF6D5742),
                  decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try different search terms',
                style: TextStyle(
                  fontFamily: 'Merriweather',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white54 : const Color(0xFF6D5742),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ ENHANCED: Search results header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.amber[300] : Colors.brown)!.withValues(alpha: 0.1), // ✅ FIXED: withValues
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: isDark ? Colors.amber[300] : Colors.brown,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_filteredVerses.length} result${_filteredVerses.length == 1 ? '' : 's'} for "${_searchController.text}"',
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF2B1810),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Split and display each verse on separate lines
          ..._filteredVerses.asMap().entries.expand((entry) {
            final verseEntries = splitIntoVerses(entry.value.verse);
            
            return verseEntries.map((ve) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.amber[300] : Colors.deepPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${ve.key}',
                      style: const TextStyle(
                        fontFamily: 'Merriweather',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SelectableText(
                      ve.value,
                      style: TextStyle(
                        fontFamily: 'Merriweather',
                        fontWeight: FontWeight.bold,
                        fontSize: _fontSize,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.96) // ✅ FIXED: withValues
                            : const Color(0xFF2B1810),
                        height: 2.0,
                        wordSpacing: 1.3,
                        letterSpacing: 0.12,
                        decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ));
          }),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildVersesList(List<BibleVerse> verses, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ✅ ENHANCED: Better font control styling
              GestureDetector(
                onTap: _decreaseFontSize,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.amber[300] : Colors.brown)!.withValues(alpha: 0.1), // ✅ FIXED: withValues
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'A⁻',
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.amber[300] : Colors.brown,
                      decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.amber[300] : Colors.brown)!.withValues(alpha: 0.15), // ✅ FIXED: withValues
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_fontSize.toInt()}pt',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amber[200] : Colors.brown,
                    fontSize: 14,
                    decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
                  ),
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: _increaseFontSize,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.amber[300] : Colors.brown)!.withValues(alpha: 0.1), // ✅ FIXED: withValues
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'A⁺',
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.amber[300] : Colors.brown,
                      decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          // Split and display each verse on separate lines
          ...verses.asMap().entries.expand((entry) {
            final verseEntries = splitIntoVerses(entry.value.verse);
            
            return verseEntries.map((ve) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.amber[300] : Colors.deepPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${ve.key}',
                      style: const TextStyle(
                        fontFamily: 'Merriweather',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                        decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SelectableText(
                      ve.value,
                      style: TextStyle(
                        fontFamily: 'Merriweather',
                        fontWeight: FontWeight.bold,
                        fontSize: _fontSize,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.96) // ✅ FIXED: withValues
                            : const Color(0xFF2B1810),
                        height: 2.0,
                        wordSpacing: 1.3,
                        letterSpacing: 0.12,
                        decoration: TextDecoration.none, // ✅ EXPLICIT NO UNDERLINE
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ));
          }),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: isDark ? Colors.amber[300] : Colors.brown,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              _isLocal(widget.language)
                  ? 'Loading verses from local data...'
                  : 'Loading verses from server...',
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF2B1810),
                decoration: TextDecoration.none, 
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLocal(widget.language)
                  ? 'Reading ${widget.bookName} ${widget.chapterNumber} from offline data'
                  : 'Fetching ${widget.bookName} ${widget.chapterNumber} from server',
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF6D5742),
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isLocal(widget.language) ? Icons.offline_pin : Icons.cloud_off,
              size: 64,
              color: isDark ? Colors.white54 : const Color(0xFF6D5742),
            ),
            const SizedBox(height: 24),
            Text(
              'No verses found',
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isDark ? Colors.white : const Color(0xFF2B1810),
                decoration: TextDecoration.none, 
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isLocal(widget.language)
                  ? 'No verses available for ${widget.bookName} chapter ${widget.chapterNumber} in local data'
                  : 'No verses available for ${widget.bookName} chapter ${widget.chapterNumber} on server',
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF6D5742),
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                if (mounted) {
                  ref
                      .read(screen_providers
                          .screenBibleVerseListProvider(_params)
                          .notifier)
                      .refresh();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber[300] : Colors.brown,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isLocal(widget.language) ? 'Reload Local Data' : 'Retry Server',
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                    decoration: TextDecoration.none, 
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isLocal(widget.language) ? Icons.error_outline : Icons.cloud_off,
              size: 64,
              color: isDark ? Colors.red[300] : Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading verses',
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isDark ? Colors.white : const Color(0xFF2B1810),
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isLocal(widget.language)
                  ? 'Unable to load verses from local data\n${error.toString()}'
                  : 'Unable to load verses from server\n${error.toString()}',
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF6D5742),
                decoration: TextDecoration.none, 
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (mounted) {
                      ref
                          .read(screen_providers
                              .screenBibleVerseListProvider(_params)
                              .notifier)
                          .refresh();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red[300] : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontFamily: 'Merriweather',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.white54 : const Color(0xFF6D5742),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Go Back',
                      style: TextStyle(
                        fontFamily: 'Merriweather',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white54 : const Color(0xFF6D5742),
                        decoration: TextDecoration.none, 
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
