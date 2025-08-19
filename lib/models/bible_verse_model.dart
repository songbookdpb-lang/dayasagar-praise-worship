// lib/models/bible_verse_model.dart
class BibleVerse {
  final String id;
  final String book;
  final String chapter;
  final String verse;
  final String language;
  final DateTime createdAt;

  BibleVerse({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.language,
    required this.createdAt,
  });

  // ✅ ADDED: Missing fromMap factory method
  factory BibleVerse.fromMap(Map<String, dynamic> map, String id) {
    return BibleVerse(
      id: id,
      book: map['book']?.toString() ?? '',
      chapter: map['chapter']?.toString() ?? '',
      verse: map['verse']?.toString() ?? '',
      language: map['language']?.toString() ?? '',
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is int 
              ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
              : DateTime.parse(map['createdAt'].toString()))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'language': language,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
