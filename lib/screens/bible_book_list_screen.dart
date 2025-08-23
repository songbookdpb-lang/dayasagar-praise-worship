import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pagination_state.dart';

final List<String> oldTestamentBooksOrdered = [
  'Genesis','Exodus','Leviticus','Numbers','Deuteronomy',
  'Joshua','Judges','Ruth','1 Samuel','2 Samuel','1 Kings','2 Kings',
  '1 Chronicles','2 Chronicles','Ezra','Nehemiah','Esther','Job',
  'Psalms','Proverbs','Ecclesiastes','Song of Solomon','Isaiah','Jeremiah',
  'Lamentations','Ezekiel','Daniel','Hosea','Joel','Amos','Obadiah',
  'Jonah','Micah','Nahum','Habakkuk','Zephaniah','Haggai','Zechariah','Malachi'
];

final List<String> newTestamentBooksOrdered = [
  'Matthew','Mark','Luke','John','Acts',
  'Romans','1 Corinthians','2 Corinthians','Galatians','Ephesians',
  'Philippians','Colossians','1 Thessalonians','2 Thessalonians','1 Timothy',
  '2 Timothy','Titus','Philemon','Hebrews','James','1 Peter','2 Peter',
  '1 John','2 John','3 John','Jude','Revelation'
];
final Map<String, String> hindiBookNames = {
  'Genesis': 'उत्पत्ति',
  'Exodus': 'निर्गमन',
  'Leviticus': 'लैव्यव्यवस्था',
  'Numbers': 'गिनती',
  'Deuteronomy': 'व्यवस्थाविवरण',
  'Joshua': 'यहोशू',
  'Judges': 'न्यायियों',
  'Ruth': 'रूत',
  '1 Samuel': '1 शमूएल',
  '2 Samuel': '2 शमूएल',
  '1 Kings': '1 राजा',
  '2 Kings': '2 राजा',
  '1 Chronicles': '1 इतिहास',
  '2 Chronicles': '2 इतिहास',
  'Ezra': 'एज्रा',
  'Nehemiah': 'नहेमायाह',
  'Esther': 'एस्तेर',
  'Job': 'अय्यूब',
  'Psalms': 'भजन संहिता',
  'Proverbs': 'नीतिवचन',
  'Ecclesiastes': 'सभोपदेशक',
  'Song of Solomon': 'श्रेष्ठगीत',
  'Isaiah': 'यशायाह',
  'Jeremiah': 'यिर्मयाह',
  'Lamentations': 'विलापगीत',
  'Ezekiel': 'यहेजकेल',
  'Daniel': 'दानिय्येल',
  'Hosea': 'होशे',
  'Joel': 'योएल',
  'Amos': 'आमोस',
  'Obadiah': 'ओबद्याह',
  'Jonah': 'योना',
  'Micah': 'मीका',
  'Nahum': 'नहूम',
  'Habakkuk': 'हबक्कूक',
  'Zephaniah': 'सपन्याह',
  'Haggai': 'हाग्गै',
  'Zechariah': 'जकर्याह',
  'Malachi': 'मलाकी',
  'Matthew': 'मत्ती',
  'Mark': 'मरकुस',
  'Luke': 'लूका',
  'John': 'यूहन्ना',
  'Acts': 'प्रेरितों के काम',
  'Romans': 'रोमियों',
  '1 Corinthians': '1 कुरिन्थियों',
  '2 Corinthians': '2 कुरिन्थियों',
  'Galatians': 'गलातियों',
  'Ephesians': 'इफिसियों',
  'Philippians': 'फिलिप्पियों',
  'Colossians': 'कुलुस्सियों',
  '1 Thessalonians': '1 थिस्सलुनीकियों',
  '2 Thessalonians': '2 थिस्सलुनीकियों',
  '1 Timothy': '1 तीमुथियुस',
  '2 Timothy': '2 तीमुथियुस',
  'Titus': 'तीतुस',
  'Philemon': 'फिलेमोन',
  'Hebrews': 'इब्रानियों',
  'James': 'याकूब',
  '1 Peter': '1 पतरस',
  '2 Peter': '2 पतरस',
  '1 John': '1 यूहन्ना',
  '2 John': '2 यूहन्ना',
  '3 John': '3 यूहन्ना',
  'Jude': 'यहूदा',
  'Revelation': 'प्रकाशितवाक्य',
};

final Map<String, String> odiaBookNames = {
  'Genesis': 'ଆଦିପୁସ୍ତକ',
  'Exodus': 'ନିର୍ଗମନ',
  'Leviticus': 'ଲେବୀୟ',
  'Numbers': 'ଗଣନା',
  'Deuteronomy': 'ଦ୍ବିତୀୟ ବିବରଣ',
  'Joshua': 'ଯିହୋଶୂୟ',
  'Judges': 'ବିଚାରକର୍ତ୍ତା',
  'Ruth': 'ରୂତ',
  '1 Samuel': '୧ ଶାମୁୟେଲ',
  '2 Samuel': '୨ ଶାମୁୟେଲ',
  '1 Kings': '୧ ରାଜାବଳୀ',
  '2 Kings': '୨ ରାଜାବଳୀ',
  '1 Chronicles': '୧ ବଂଶାବଳୀ',
  '2 Chronicles': '୨ ବଂଶାବଳୀ',
  'Ezra': 'ଏଜ୍ରା',
  'Nehemiah': 'ନିହିମୀୟା',
  'Esther': 'ଏଷ୍ଟର',
  'Job': 'ଯୀଶୁ',
  'Psalms': 'ଗୀତସଂହିତା',
  'Proverbs': 'ହିତୋପଦେଶ',
  'Ecclesiastes': 'ଉପଦେଶକ',
  'Song of Solomon': 'ପରମଗୀତ',
  'Isaiah': 'ଯିଶାଇୟ',
  'Jeremiah': 'ଯିରିମୀୟ',
  'Lamentations': 'ବିଳାପ',
  'Ezekiel': 'ଯିହିଜକେଲ',
  'Daniel': 'ଦାନିୟେଲ',
  'Hosea': 'ହୋଶେୟ',
  'Joel': 'ଯୋୟେଲ',
  'Amos': 'ଆମୋସ',
  'Obadiah': 'ଓବଦୀୟ',
  'Jonah': 'ଯୂନସ',
  'Micah': 'ମୀଖା',
  'Nahum': 'ନହୂମ',
  'Habakkuk': 'ହବକ୍କୂକ',
  'Zephaniah': 'ସଫନୀୟ',
  'Haggai': 'ହାଗ୍ଗୟ',
  'Zechariah': 'ଜିଖରୀୟ',
  'Malachi': 'ମାଲାଖୀ',
  'Matthew': 'ମଥି',
  'Mark': 'ମାର୍କ',
  'Luke': 'ଲୂକ',
  'John': 'ଯୋହନ',
  'Acts': 'ପ୍ରେରିତ',
  'Romans': 'ରୋମୀୟ',
  '1 Corinthians': '୧ କରିନ୍ଥୀୟ',
  '2 Corinthians': '୨ କରିନ୍ଥୀୟ',
  'Galatians': 'ଗାଲାତୀୟ',
  'Ephesians': 'ଏଫିସୀୟ',
  'Philippians': 'ଫିଲିପ୍ପୀୟ',
  'Colossians': 'କଲସୀୟ',
  '1 Thessalonians': '୧ ଥେସଲନୀକୀୟ',
  '2 Thessalonians': '୨ ଥେସଲନୀକୀୟ',
  '1 Timothy': '୧ ତୀମଥିୟ',
  '2 Timothy': '୨ ତୀମଥିୟ',
  'Titus': 'ତୀତସ',
  'Philemon': 'ଫିଲୀମୋନ',
  'Hebrews': 'ଇବ୍ରୀୟ',
  'James': 'ଯାକୁବ',
  '1 Peter': '୧ ପିତର',
  '2 Peter': '୨ ପିତର',
  '1 John': '୧ ଯୋହନ',
  '2 John': '୨ ଯୋହନ',
  '3 John': '୩ ଯୋହନ',
  'Jude': 'ଯିହୂଦା',
  'Revelation': 'ପ୍ରକାଶିତ',
};

final Map<String, String> hindiTestamentNames = {
  'Old Testament': 'पुराना नियम',
  'New Testament': 'नया नियम',
};

final Map<String, String> odiaTestamentNames = {
  'Old Testament': 'ପୁରାତନ ନିୟମ',
  'New Testament': 'ନୂତନ ନିୟମ',
};
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

String _getLocalizedBookName(String bookName, String language) {
  if (_isHindiLocal(language)) {
    return hindiBookNames[bookName] ?? bookName;
  } else if (_isOdiaLocal(language)) {
    return odiaBookNames[bookName] ?? bookName;
  } else {
    return bookName;
  }
}

String _getLocalizedTestamentName(String testamentName, String language) {
  if (_isHindiLocal(language)) {
    return hindiTestamentNames[testamentName] ?? testamentName;
  } else if (_isOdiaLocal(language)) {
    return odiaTestamentNames[testamentName] ?? testamentName;
  } else {
    return testamentName;
  }
}
Future<List<String>> _loadBooksFromBundledJson(String language) async {
  try {
    final code = _isEnglishLocal(language)
        ? 'EN-English'
        : _isHindiLocal(language)
            ? 'HI-Hindi'
            : 'OD-Odia'; 

    debugPrint('📚 Loading $language books from $code/asv.json...');
    
    final ByteData data = await rootBundle.load('assets/bible/$code/asv.json');
    final List<dynamic> raw = json.decode(utf8.decode(data.buffer.asUint8List()));

    final books = raw.map((e) => e['book'] as String).toSet().toList()..sort();
    debugPrint('✅ Loaded ${books.length} $language books from bundled JSON');
    return books;
  } catch (e) {
    debugPrint('❌ Error loading $language books from bundled JSON: $e');
    return [];
  }
}

class BibleBookListScreen extends ConsumerStatefulWidget {
  final String language;
  const BibleBookListScreen({super.key, required this.language});

  @override
  ConsumerState<BibleBookListScreen> createState() => _BibleBookListScreenState();
}

class _BibleBookListScreenState extends ConsumerState<BibleBookListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _pageController = PageController();
  int _activeTestament = 0;
  List<String> _localBooks = [];
  bool _isLoadingLocal = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadBooksData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBooksData() async {
    setState(() => _isLoadingLocal = true);
    try {
      final books = await _loadBooksFromBundledJson(widget.language);
      if (mounted) {
        setState(() {
          _localBooks = books;
          _isLoadingLocal = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading local books: $e');
      if (mounted) setState(() => _isLoadingLocal = false);
    }
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {}); 
  }

  void _onScroll() {
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
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

  void _onTestamentChanged(int testament) {
    HapticFeedback.selectionClick();
    if (_activeTestament != testament) {
      setState(() => _activeTestament = testament);
      _pageController.animateToPage(
        testament,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int page) {
    if (_activeTestament != page) {
      HapticFeedback.lightImpact();
      setState(() => _activeTestament = page);
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    await _loadBooksData();
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final booksState = PaginationState<String>(
      items: _localBooks,
      isLoading: _isLoadingLocal,
      hasMore: false,
      isFromCache: true,
      error: null,
    );

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
                _buildTestamentToggle(theme, isDark),
                Expanded(
                  child: _isSearching 
                    ? _buildSearchResults(booksState, theme, isDark) 
                    : _buildSwipeableBooksList(booksState, theme, isDark),
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
          tooltip: _isSearching ? 'Close search' : 'Search books',
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    String searchHint;
    if (_isHindiLocal(widget.language)) {
      searchHint = 'किताबें खोजें...';
    } else if (_isOdiaLocal(widget.language)) {
      searchHint = 'ପୁସ୍ତକ ଖୋଜନ୍ତୁ...';
    } else {
      searchHint = 'Search ${widget.language} books...';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: searchHint,
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
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    String headerText;
    if (_isHindiLocal(widget.language)) {
      headerText = 'Dayasagar \nPraise and Worship';
    } else if (_isOdiaLocal(widget.language)) {
      headerText = 'Dayasagar \nPraise and Worship';
    } else {
      headerText = 'Dayasagar \nPraise and Worship';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          Text(
            '',
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
            headerText,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestamentToggle(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _onTestamentChanged(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _activeTestament == 0
                      ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getLocalizedTestamentName("Old Testament", widget.language),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _activeTestament == 0
                        ? (isDark ? Colors.white : const Color(0xFF1F2937))
                        : (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _onTestamentChanged(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _activeTestament == 1
                      ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getLocalizedTestamentName("New Testament", widget.language),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _activeTestament == 1
                        ? (isDark ? Colors.white : const Color(0xFF1F2937))
                        : (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeableBooksList(PaginationState<String> booksState, ThemeData theme, bool isDark) {
    final bookSet = booksState.items.toSet();
    
    if (booksState.items.isEmpty && booksState.isLoading) {
      return _buildLoadingState(theme, isDark);
    }
    if (booksState.items.isEmpty && !booksState.isLoading) {
      return _buildEmptyState(theme, isDark);
    }
    if (booksState.error != null) {
      return _buildErrorState(booksState.error!, theme, isDark);
    }

    return PageView(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      children: [
        _buildTestamentBooksList(bookSet, 0, theme, isDark),
        _buildTestamentBooksList(bookSet, 1, theme, isDark),
      ],
    );
  }

  Widget _buildTestamentBooksList(Set<String> bookSet, int testament, ThemeData theme, bool isDark) {
    final books = _filteredBooksForTestament(bookSet, testament);

    if (books.isEmpty) {
      String noBookMessage;
      String swipeMessage;
      if (_isHindiLocal(widget.language)) {
        noBookMessage = "${testament == 0 ? 'पुराने' : 'नए'} नियम में कोई किताब नहीं मिली";
        swipeMessage = "← ${testament == 0 ? 'नए' : 'पुराने'} नियम के लिए स्वाइप करें →";
      } else if (_isOdiaLocal(widget.language)) {
        noBookMessage = "${testament == 0 ? 'ପୁରାତନ' : 'ନୂତନ'} ନିୟମରେ କୌଣସି ପୁସ୍ତକ ମିଳିଲା ନାହିଁ";
        swipeMessage = "← ${testament == 0 ? 'ନୂତନ' : 'ପୁରାତନ'} ନିୟମ ପାଇଁ ସ୍ୱାଇପ୍ କରନ୍ତୁ →";
      } else {
        noBookMessage = "No books found in ${testament == 0 ? 'Old' : 'New'} Testament";
        swipeMessage = "← Swipe to ${testament == 0 ? 'New' : 'Old'} Testament →";
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              noBookMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              swipeMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: books.length,
          itemBuilder: (context, index) => _buildBookButton(books[index], theme, isDark),
        ),
      ),
    );
  }

  Widget _buildSearchResults(PaginationState<String> booksState, ThemeData theme, bool isDark) {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _buildSearchEmptyState(theme, isDark);
    }
    
    final filteredBooks = _localBooks.where((book) {
      final localizedName = _getLocalizedBookName(book, widget.language);
      return localizedName.toLowerCase().contains(query);
    }).toSet();
    
    final books = _filteredBooks(filteredBooks);
    
    if (books.isEmpty) {
      return _buildSearchNoResultsState(theme, isDark);
    }
    
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) => _buildBookButton(books[index], theme, isDark),
        ),
      ),
    );
  }
  Widget _buildBookButton(String bookName, ThemeData theme, bool isDark) {
    String displayName;
    if (_isHindiLocal(widget.language)) {
      displayName = hindiBookNames[bookName] ?? bookName; 
    } else if (_isOdiaLocal(widget.language)) {
      displayName = odiaBookNames[bookName] ?? bookName; 
    } else {
      displayName = bookName; 
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
            if (mounted) context.push('/bible/${widget.language}/$bookName/chapters');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Text(
              displayName, 
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

  List<String> _filteredBooks(Set<String> sourceSet) {
    final refList = _activeTestament == 0 ? oldTestamentBooksOrdered : newTestamentBooksOrdered;
    return refList.where((b) => sourceSet.contains(b)).toList();
  }

  List<String> _filteredBooksForTestament(Set<String> sourceSet, int testament) {
    final refList = testament == 0 ? oldTestamentBooksOrdered : newTestamentBooksOrdered;
    return refList.where((b) => sourceSet.contains(b)).toList();
  }

  Widget _buildSearchEmptyState(ThemeData theme, bool isDark) {
    String searchPrompt;
    if (_isHindiLocal(widget.language)) {
      searchPrompt = 'बाइबल की किताबें खोजें';
    } else if (_isOdiaLocal(widget.language)) {
      searchPrompt = 'ବାଇବଲ ପୁସ୍ତକ ଖୋଜନ୍ତୁ';
    } else {
      searchPrompt = 'Search ${widget.language} Bible books';
    }

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
            searchPrompt,
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

  Widget _buildSearchNoResultsState(ThemeData theme, bool isDark) {
    String noResultsMessage;
    if (_isHindiLocal(widget.language)) {
      noResultsMessage = 'कोई किताब नहीं मिली';
    } else if (_isOdiaLocal(widget.language)) {
      noResultsMessage = 'କୌଣସି ପୁସ୍ତକ ମିଳିଲା ନାହିଁ';
    } else {
      noResultsMessage = 'No books found';
    }

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
            noResultsMessage,
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

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    String loadingMessage;
    if (_isHindiLocal(widget.language)) {
      loadingMessage = 'किताबें लोड हो रही हैं...';
    } else if (_isOdiaLocal(widget.language)) {
      loadingMessage = 'ପୁସ୍ତକ ଲୋଡ୍ ହେଉଛି...';
    } else {
      loadingMessage = 'Loading books...';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            loadingMessage,
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
    String emptyMessage;
    String reloadText;
    if (_isHindiLocal(widget.language)) {
      emptyMessage = 'कोई किताब नहीं मिली';
      reloadText = 'डेटा दोबारा लोड करें';
    } else if (_isOdiaLocal(widget.language)) {
      emptyMessage = 'କୌଣସି ପୁସ୍ତକ ମିଳିଲା ନାହିଁ';
      reloadText = 'ଡାଟା ପୁନଃଲୋଡ କରନ୍ତୁ';
    } else {
      emptyMessage = 'No books found';
      reloadText = 'Reload Data';
    }

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
            emptyMessage,
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
            child: Text(reloadText),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, ThemeData theme, bool isDark) {
    String errorTitle;
    String retryText;
    String goBackText;
    if (_isHindiLocal(widget.language)) {
      errorTitle = 'किताबें लोड करने में त्रुटि';
      retryText = 'पुनः प्रयास';
      goBackText = 'वापस जाएं';
    } else if (_isOdiaLocal(widget.language)) {
      errorTitle = 'ପୁସ୍ତକ ଲୋଡ୍ କରିବାରେ ତ୍ରୁଟି';
      retryText = 'ପୁନଃଚେଷ୍ଟା';
      goBackText = 'ଫେରିଯାଆନ୍ତୁ';
    } else {
      errorTitle = 'Error loading books';
      retryText = 'Retry';
      goBackText = 'Go Back';
    }

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
            errorTitle,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _handleRefresh();
                },
                child: Text(retryText),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: Text(goBackText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
