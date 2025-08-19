import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/songs/song_list_provider.dart';
import '../../models/song_models.dart';

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

bool _isSardariLocal(String language) {
  final lang = language.trim().toLowerCase();
  return lang.startsWith('sa') || lang.contains('sardari');
}

bool _isLocal(String language) =>
    _isEnglishLocal(language) ||
    _isHindiLocal(language) ||
    _isOdiaLocal(language) ||
    _isSardariLocal(language);

class SongLyricsScreen extends ConsumerStatefulWidget {
  final String songId;

  const SongLyricsScreen({
    super.key,
    required this.songId,
  });

  @override
  ConsumerState<SongLyricsScreen> createState() => _SongLyricsScreenState();
}
class _SongLyricsScreenState extends ConsumerState<SongLyricsScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  double _fontSize = 18.0;
  String _searchHighlight = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchHighlight = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchHighlight = '';
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

  void _increaseFontSize() {
    if (_fontSize < 34.0) setState(() => _fontSize += 2.0);
  }

  void _decreaseFontSize() {
    if (_fontSize > 14.0) setState(() => _fontSize -= 2.0);
  }

  Song? _findSong() {
    for (String language in ['English', 'Hindi', 'Odia', 'Sardari']) {
      final songsState = ref.watch(songsPaginationProvider(language));
      final song = songsState.songs.where((s) => s.id == widget.songId).firstOrNull;
      if (song != null) return song;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF23232B) : const Color(0xFFFAF3E7);
    final song = _findSong();

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
            child: _buildScrollableContent(song, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableContent(Song? song, bool isDark) {
    if (song == null) {
      return _buildNotFoundState(isDark);
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        if (mounted) {
          setState(() {});
        }
      },
      color: isDark ? Colors.amber[300] : Colors.brown,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _buildScrollableHeader(song, isDark),
          ),
          if (_isSearching)
            SliverToBoxAdapter(
              child: _buildSearchBar(isDark),
            ),
          SliverToBoxAdapter(
            child: _buildLyricsContent(song, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableHeader(Song song, bool isDark) {
    String subtitle = _isLocal(song.language) 
        ? 'offline • ${song.language}'
        : 'online • ${song.language}';

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
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const Spacer(),
              if (_isLocal(song.language))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
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
              if (_isLocal(song.language)) const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleSearch,
                child: Text(
                  _isSearching ? 'Close' : 'Search',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.amber[200] : Colors.brown,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {});
                },
                child: Text(
                  'Refresh',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.amber[200] : Colors.brown,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            song.songName,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: isDark ? Colors.white : const Color(0xFF2B1810),
              height: 1.2,
              decoration: TextDecoration.none,
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
              decoration: TextDecoration.none,
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
          decoration: TextDecoration.none,
        ),
        decoration: InputDecoration(
          hintText: 'Search lyrics...',
          hintStyle: TextStyle(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white54 : const Color(0xFF6D5742),
            decoration: TextDecoration.none,
          ),
          border: UnderlineInputBorder(
            borderSide: BorderSide(
              color: isDark ? Colors.amber[300]! : Colors.brown,
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: isDark ? Colors.amber : Colors.brown,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onSubmitted: (value) {
          HapticFeedback.selectionClick();
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildLyricsContent(Song song, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _decreaseFontSize,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.amber[300] : Colors.brown)!.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'A⁻',
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.amber[300] : Colors.brown,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.amber[300] : Colors.brown)!.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_fontSize.toInt()}pt',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amber[200] : Colors.brown,
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: _increaseFontSize,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.amber[300] : Colors.brown)!.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'A⁺',
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.amber[300] : Colors.brown,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildLyricsText(song.lyrics, isDark),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildLyricsText(String lyrics, bool isDark) {
    if (_searchHighlight.isEmpty || !_isSearching) {
      return SelectableText(
        lyrics,
        style: TextStyle(
          fontFamily: 'Merriweather',
          fontWeight: FontWeight.bold,
          fontSize: _fontSize,
          color: isDark
              ? Colors.white.withValues(alpha: 0.96)
              : const Color(0xFF2B1810),
          height: 2.0,
          wordSpacing: 1.3,
          letterSpacing: 0.12,
          decoration: TextDecoration.none,
        ),
        textAlign: TextAlign.left,
      );
    }

    return _buildHighlightedText(lyrics, _searchHighlight, isDark);
  }

  Widget _buildHighlightedText(String text, String highlight, bool isDark) {
    if (highlight.isEmpty) {
      return SelectableText(
        text,
        style: TextStyle(
          fontFamily: 'Merriweather',
          fontWeight: FontWeight.bold,
          fontSize: _fontSize,
          color: isDark
              ? Colors.white.withValues(alpha: 0.96)
              : const Color(0xFF2B1810),
          height: 2.0,
          wordSpacing: 1.3,
          letterSpacing: 0.12,
          decoration: TextDecoration.none,
        ),
        textAlign: TextAlign.left,
      );
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerHighlight = highlight.toLowerCase();
    int start = 0;
    int index = lowerText.indexOf(lowerHighlight, start);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.bold,
            fontSize: _fontSize,
            color: isDark
                ? Colors.white.withValues(alpha: 0.96)
                : const Color(0xFF2B1810),
            height: 2.0,
            wordSpacing: 1.3,
            letterSpacing: 0.12,
            decoration: TextDecoration.none,
          ),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + highlight.length),
        style: TextStyle(
          fontFamily: 'Merriweather',
          fontWeight: FontWeight.bold,
          fontSize: _fontSize,
          color: isDark ? Colors.black : Colors.white,
          backgroundColor: isDark ? Colors.amber[300] : Colors.brown,
          height: 2.0,
          wordSpacing: 1.3,
          letterSpacing: 0.12,
          decoration: TextDecoration.none,
        ),
      ));

      start = index + highlight.length;
      index = lowerText.indexOf(lowerHighlight, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(
          fontFamily: 'Merriweather',
          fontWeight: FontWeight.bold,
          fontSize: _fontSize,
          color: isDark
              ? Colors.white.withValues(alpha: 0.96)
              : const Color(0xFF2B1810),
          height: 2.0,
          wordSpacing: 1.3,
          letterSpacing: 0.12,
          decoration: TextDecoration.none,
        ),
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.left,
    );
  }

  Widget _buildNotFoundState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: isDark ? Colors.white54 : const Color(0xFF6D5742),
            ),
            const SizedBox(height: 24),
            Text(
              'Song not found',
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
              'The requested song could not be found',
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
                HapticFeedback.lightImpact();
                context.pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber[300] : Colors.brown,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Go Back',
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
          ],
        ),
      ),
    );
  }
}
