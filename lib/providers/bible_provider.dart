import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/bible_verse_model.dart';

class LocalBibleService {
  static final LocalBibleService _instance = LocalBibleService._internal();
  factory LocalBibleService() => _instance;
  LocalBibleService._internal();

  final Map<String, List<BibleVerse>> _cache = {};

  String _getAssetPath(String language) {
    final lang = language.toLowerCase();
    if (lang == 'english' || lang == 'en-english') {
      return 'assets/bible/EN-English/asv.json';
    } else if (lang.startsWith('hi') || lang == 'hindi') {
      return 'assets/bible/HI-Hindi/asv.json';
    } else if (lang.startsWith('od') || lang.startsWith('or') || lang == 'odia') {
      return 'assets/bible/OD-Odia/asv.json';
    } else {
      return 'assets/bible/EN-English/asv.json';
    }
  }

  Future<List<BibleVerse>> loadBible(String language) async {
    final langKey = language.toLowerCase();
    
    if (_cache.containsKey(langKey)) {
      return _cache[langKey]!;
    }

    try {
      final assetPath = _getAssetPath(language);
      final jsonString = await rootBundle.loadString(assetPath);
      final dynamic jsonData = json.decode(jsonString);

      List<dynamic> versesJson;
      if (jsonData is List) {
        versesJson = jsonData;
      } else if (jsonData is Map<String, dynamic>) {
        versesJson = (jsonData['verses'] as List<dynamic>? ?? []);
      } else {
        return [];
      }

      final List<BibleVerse> verses = [];
      for (final verse in versesJson) {
        if (verse is! Map<String, dynamic>) continue;
        
        final book = (verse['book_name'] ?? verse['book'] ?? '').toString();
        final chapter = (verse['chapter'] ?? '').toString();
        final verseText = (verse['text'] ?? verse['verse_text'] ?? verse['verse'] ?? '').toString();
        final verseNum = (verse['verse'] ?? verse['verse_number'] ?? '1').toString();
        
        final id = 'local_${language}_${book}_${chapter}_$verseNum';

        verses.add(BibleVerse.fromMap({
          'id': id,
          'book': book,
          'chapter': chapter,
          'verse': verseText,
          'language': language,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        }, id));
      }

      _cache[langKey] = verses;
      return verses;
    } catch (e) {
      debugPrint('Error loading bible for $language: $e');
      return [];
    }
  }

  Future<BibleVerse?> getBibleVerseById(String id) async {
    if (!id.startsWith('local_')) return null;

    final parts = id.split('_');
    if (parts.length < 5) return null;

    final language = parts[1];
    final verses = await loadBible(language);
    
    try {
      return verses.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }
}

class BibleVerseScreen extends StatefulWidget {
  final String verseId;
  const BibleVerseScreen({super.key, required this.verseId});

  @override
  State<BibleVerseScreen> createState() => _BibleVerseScreenState();
}

class _BibleVerseScreenState extends State<BibleVerseScreen> {
  double _fontSize = 18.0;
  BibleVerse? _verse;
  bool _isLoading = true;
  String? _error;
  
  final LocalBibleService _bibleService = LocalBibleService();

  @override
  void initState() {
    super.initState();
    _loadVerse();
  }

  Future<void> _loadVerse() async {
    if (widget.verseId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid verse ID';
      });
      return;
    }

    try {
      final verse = await _bibleService.getBibleVerseById(widget.verseId);
      setState(() {
        _verse = verse;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading verse: $e';
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
    return ColoredBox(
      color: const Color(0xFFFAF3E7), 
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Merriweather'),
          cardTheme: const CardThemeData(
            color: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            clipBehavior: Clip.none,
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
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6D5742),
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Text(
          'Error loading verse\n$_error',
          style: const TextStyle(fontFamily: 'Merriweather', fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return _buildVerseContent(_verse);
  }

  Widget _buildVerseContent(BibleVerse? verse) {
    if (verse == null) {
      return const Center(
        child: Text(
          'Bible verse not found',
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${verse.book} ${verse.chapter}  ${verse.language}',
              style: const TextStyle(
                fontFamily: 'Merriweather',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontStyle: FontStyle.italic,
                color: Color(0xFF6D5742), // subtle brown ink
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: _decreaseFontSize,
                  icon: const Icon(Icons.text_decrease, size: 22),
                  color: Colors.brown[400],
                  splashRadius: 22,
                  tooltip: 'Decrease font size',
                ),
                Text(
                  '${_fontSize.toInt()}',
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF947B60),
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  onPressed: _increaseFontSize,
                  icon: const Icon(Icons.text_increase, size: 22),
                  color: Colors.brown[600],
                  splashRadius: 22,
                  tooltip: 'Increase font size',
                ),
              ],
            ),
            const SizedBox(height: 30),
            SelectableText(
              verse.verse.trim().isEmpty ? 'No verse text available.' : verse.verse,
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontSize: _fontSize,
                color: const Color(0xFF3A2B1E), // deep brown
                height: 2.0,
                wordSpacing: 1.6,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }
}
