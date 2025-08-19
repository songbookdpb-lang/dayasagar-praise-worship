import 'song_models.dart';
import 'bible_verse_model.dart';

abstract class SearchResult {}

class SongSearchResult extends SearchResult {
  final Song song;
  SongSearchResult(this.song);
}

class BibleSearchResult extends SearchResult {
  final BibleVerse verse;
  BibleSearchResult(this.verse);
}
