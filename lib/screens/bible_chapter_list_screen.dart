import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

final Map<String, String> chapterTranslations = {
  'hindi': 'अध्याय',
  'odia': 'ଅଧ୍ୟାୟ',
};

String toDevanagariNumeral(int number) {
  const devanagariDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
  return number
      .toString()
      .split('')
      .map((c) => int.tryParse(c) == null ? c : devanagariDigits[int.parse(c)])
      .join();
}

String toOdiaNumeral(int number) {
  const odiaDigits = ['୦', '୧', '୨', '୩', '୪', '୫', '୬', '୭', '୮', '୯'];
  return number
      .toString()
      .split('')
      .map((c) => int.tryParse(c) == null ? c : odiaDigits[int.parse(c)])
      .join();
}

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

bool _isLocalLanguage(String language) =>
    _isEnglishLocal(language) ||
    _isHindiLocal(language) ||
    _isOdiaLocal(language);

Future<List<int>> _loadEnglishChaptersFromAsset({
  required String bookName,
}) async {
  try {
    final raw = await rootBundle.loadString('assets/bible/EN-English/asv.json');
    
    final dynamic jsonData = json.decode(raw);
    
    List<dynamic> versesJson;
    if (jsonData is List) {
      versesJson = jsonData;
    } else if (jsonData is Map<String, dynamic>) {
      versesJson = (jsonData['verses'] as List<dynamic>? ?? []);
    } else {
      throw Exception('Unexpected JSON structure: ${jsonData.runtimeType}');
    }
    
    final Set<int> chapterNumbers = {};
    for (final verse in versesJson) {
      if (verse is! Map<String, dynamic>) continue;
      
      final m = verse;
      final vBook = (m['book_name'] ?? m['book'] ?? '').toString();
      final vChapter = m['chapter'];
      
      if (vBook == bookName && vChapter != null) {
        final chapterNum = vChapter is int ? vChapter : int.tryParse(vChapter.toString());
        if (chapterNum != null && chapterNum > 0) {
          chapterNumbers.add(chapterNum);
        }
      }
    }
    
    final chapters = chapterNumbers.toList()..sort();
    debugPrint('✅ Loaded ${chapters.length} chapters for $bookName: ${chapters.take(5).join(', ')}${chapters.length > 5 ? '...' : ''}');
    return chapters;
  } catch (e) {
    debugPrint('❌ Error loading English chapters from asset: $e');
    return [];
  }
}

Future<List<int>> _loadChaptersFromBundledJson({
  required String language,
  required String bookName,
}) async {
  try {
    String code;
    if (_isHindiLocal(language)) {
      code = 'HI-Hindi';
    } else if (_isOdiaLocal(language)) {
      code = 'OD-Odia';
    } else {
      throw Exception('Unsupported language: $language');
    }
    
    debugPrint('📚 Loading $language chapters for $bookName from $code/asv.json...');
    
    final ByteData data = await rootBundle.load('assets/bible/$code/asv.json');
    final List<dynamic> raw = json.decode(utf8.decode(data.buffer.asUint8List()));
    
    final Set<int> chapterNumbers = {};
    for (final verse in raw) {
      if (verse is! Map<String, dynamic>) continue;
      
      final vBook = verse['book'] as String? ?? '';
      final vChapter = verse['chapter'];
      
      if (vBook == bookName && vChapter != null) {
        final chapterNum = vChapter is int ? vChapter : int.tryParse(vChapter.toString());
        if (chapterNum != null && chapterNum > 0) {
          chapterNumbers.add(chapterNum);
        }
      }
    }
    
    final chapters = chapterNumbers.toList()..sort();
    debugPrint('✅ Loaded ${chapters.length} $language chapters for $bookName');
    return chapters;
  } catch (e) {
    debugPrint('❌ Error loading $language chapters from bundled JSON: $e');
    return [];
  }
}

class BibleChapterListScreen extends ConsumerStatefulWidget {
  final String language;
  final String bookName;
  
  const BibleChapterListScreen({
    super.key,
    required this.language,
    required this.bookName,
  });
  
  @override
  ConsumerState<BibleChapterListScreen> createState() => _BibleChapterListScreenState();
}

class _BibleChapterListScreenState extends ConsumerState<BibleChapterListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  
  List<int> _filteredChapters = [];
  List<int> _allChapters = [];
  bool _isLoading = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        _filterChapters(_searchController.text);
      }
    });
    _loadChaptersData();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadChaptersData() async {
    if (!_isLocalLanguage(widget.language)) {
      setState(() {
        _error = 'Language ${widget.language} is not available offline';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final chapters = _isEnglishLocal(widget.language)
          ? await _loadEnglishChaptersFromAsset(bookName: widget.bookName)
          : await _loadChaptersFromBundledJson(
              language: widget.language,
              bookName: widget.bookName,
            );
      
      if (mounted) {
        setState(() {
          _allChapters = chapters;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading local chapters: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load chapters: $e';
        });
      }
    }
  }
  
  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    await _loadChaptersData();
  }
  
  void _toggleSearch() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredChapters.clear();
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
  
  void _filterChapters(String query) {
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        _filteredChapters.clear();
      } else {
        _filteredChapters = _allChapters.where(
          (chapter) => chapter.toString().contains(query),
        ).toList();
      }
    });
  }
  
  Widget _buildBackgroundShapes() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned(
          top: 80,
          right: -50,
          child: Opacity(
            opacity: isDark ? 0.08 : 0.04,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(75),
                  topLeft: Radius.circular(75),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 200,
          left: -80,
          child: Opacity(
            opacity: isDark ? 0.06 : 0.03,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(100),
                  bottomRight: Radius.circular(100),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: -60,
          child: Opacity(
            opacity: isDark ? 0.05 : 0.025,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _isSearching && mounted) _toggleSearch();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: _buildAppBar(theme, isDark),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                    ? [
                        const Color(0xFF0F172A),
                        const Color(0xFF1E293B),
                        const Color(0xFF334155),
                      ]
                    : [
                        const Color(0xFFE2E8F0),
                        const Color(0xFF94A3B8),
                        const Color(0xFF475569),
                      ],
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: isDark ? 0.12 : 0.06,
                child: Image.asset(
                  'assets/images/cross_light.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.church,
                      size: 100,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    );
                  },
                ),
              ),
            ),
            _buildBackgroundShapes(),
            Column(
              children: [
                if (_isSearching) _buildSearchBar(theme, isDark),
                _buildHeader(theme, isDark),
                Expanded(
                  child: _isSearching
                      ? _buildSearchResults(theme, isDark)
                      : _buildChapterContent(theme, isDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  AppBar _buildAppBar(ThemeData theme, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      iconTheme: IconThemeData(
        color: isDark ? Colors.white : const Color(0xFF1F2937),
      ),
      actions: [
        IconButton(
          onPressed: _toggleSearch,
          icon: Icon(
            _isSearching ? Icons.close : Icons.search,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
            size: 24,
          ),
          tooltip: _isSearching ? 'Close search' : 'Search chapters',
        ),
      ],
    );
  }
  
  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        keyboardType: TextInputType.number,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search chapter number...',
          hintStyle: GoogleFonts.inter(
            color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _searchController.clear();
                    _filterChapters('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (value) {
          HapticFeedback.selectionClick();
          _filterChapters(value);
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }
  
  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          Text(
            'OFFLINE BIBLE',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose Chapter',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.bookName,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildChapterContent(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return _buildLoadingState(theme, isDark);
    }
    if (_error != null) {
      return _buildErrorState(_error!, theme, isDark);
    }
    if (_allChapters.isEmpty) {
      return _buildEmptyState(theme, isDark);
    }
    return _buildChaptersList(_allChapters, theme, isDark);
  }
  
  Widget _buildSearchResults(ThemeData theme, bool isDark) {
    if (_filteredChapters.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No chapters found',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search chapters',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ListView.builder(
        itemCount: _filteredChapters.length,
        itemBuilder: (context, index) {
          return _buildChapterButton(_filteredChapters[index], theme, isDark);
        },
      ),
    );
  }
  
  Widget _buildChaptersList(List<int> chapters, ThemeData theme, bool isDark) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            final chapterNumber = chapters[index];
            return _buildChapterButton(chapterNumber, theme, isDark);
          },
        ),
      ),
    );
  }
  
  Widget _buildChapterButton(int chapterNumber, ThemeData theme, bool isDark) {
    String displayText;
    
    if (_isEnglishLocal(widget.language)) {
      displayText = 'Chapter $chapterNumber';
    } else if (_isHindiLocal(widget.language)) {
      displayText = '${chapterTranslations['hindi']} ${toDevanagariNumeral(chapterNumber)}';
    } else if (_isOdiaLocal(widget.language)) {
      displayText = '${chapterTranslations['odia']} ${toOdiaNumeral(chapterNumber)}';
    } else {
      displayText = 'Chapter $chapterNumber';
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/bible/${widget.language}/${widget.bookName}/chapter/$chapterNumber');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Text(
              displayText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading chapters...',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 64,
            color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No chapters found',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _handleRefresh();
            },
            child: const Text('Reload Data'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState(String error, ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading chapters',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _handleRefresh();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
