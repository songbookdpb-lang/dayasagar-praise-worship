import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bible_verse_model.dart';
import '../services/firestore_service.dart';

// Provider for a single verse (unchanged)
final bibleVerseByIdProvider = FutureProvider.family<BibleVerse?, String>((ref, id) async {
  if (id.isEmpty) return null;
  final firestoreService = ref.read(firestoreServiceProvider);
  final verses = await firestoreService.getBibleVersesByIds([id]);
  return verses.isNotEmpty ? verses.first : null;
});

class BibleVerseScreen extends ConsumerStatefulWidget {
  final String verseId;
  const BibleVerseScreen({super.key, required this.verseId});

  @override
  ConsumerState<BibleVerseScreen> createState() => _BibleVerseScreenState();
}

class _BibleVerseScreenState extends ConsumerState<BibleVerseScreen> {
  double _fontSize = 18.0;

  void _increaseFontSize() {
    if (_fontSize < 34.0) setState(() => _fontSize += 2.0);
  }

  void _decreaseFontSize() {
    if (_fontSize > 14.0) setState(() => _fontSize -= 2.0);
  }

  @override
  Widget build(BuildContext context) {
    final verseAsync = ref.watch(bibleVerseByIdProvider(widget.verseId));

    // Outer: soft parchment background, and a Theme that forcibly neuters Card, ListTile, all boxes
    return ColoredBox(
      color: const Color(0xFFFAF3E7), // Soft parchment (change if you want)
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
        child: verseAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text(
              'Error loading verse\n$err',
              style: const TextStyle(fontFamily: 'Merriweather', fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          data: (verse) => _buildVerseContent(verse),
        ),
      ),
    );
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
            // Book-like "heading"
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
            // Main verse content (no card, no border, pure text)
            SelectableText(
              verse.verse.trim().isEmpty ? 'No verse text available.' : 'verse.verse',
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
