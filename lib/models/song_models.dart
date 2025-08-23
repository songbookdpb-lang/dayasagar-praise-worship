import 'package:cloud_firestore/cloud_firestore.dart';

class Song {
  final String id;
  final String songName;
  final String lyrics;
  final String language;
  final Timestamp createdAt;
  final Timestamp updatedAt;   
  final String changeType;     
  final bool isDeleted;        

  Song({
    required this.id,
    required this.songName,
    required this.lyrics,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    required this.changeType,
    required this.isDeleted,
  });

  // ✅ FIXED: Added single-parameter fromMap for cache compatibility
  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] ?? '',
      songName: map['songName'] ?? '',
      lyrics: map['lyrics'] ?? '',
      language: map['language'] ?? '',
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']) ?? _parseTimestamp(map['createdAt']),
      changeType: map['changeType'] ?? 'created',
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  // ✅ KEPT: Two-parameter version for Firestore compatibility
  factory Song.fromMapWithId(Map<String, dynamic> map, String documentId) {
    return Song(
      id: documentId,
      songName: map['songName'] ?? '',
      lyrics: map['lyrics'] ?? '',
      language: map['language'] ?? '',
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']) ?? _parseTimestamp(map['createdAt']),
      changeType: map['changeType'] ?? 'created',
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  // ✅ ADDED: Helper method to parse timestamps safely
  static Timestamp _parseTimestamp(dynamic value) {
    if (value == null) return Timestamp.now();
    if (value is Timestamp) return value;
    if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        final dateTime = DateTime.parse(value);
        return Timestamp.fromDate(dateTime);
      } catch (e) {
        return Timestamp.now();
      }
    }
    return Timestamp.now();
  }

  // ✅ UPDATED: Include id in toMap for cache storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'songName': songName,
      'lyrics': lyrics,
      'language': language,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'changeType': changeType,
      'isDeleted': isDeleted,
    };
  }

  // ✅ KEPT: Firestore methods (without id since Firestore handles it)
  static Song fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Song(
      id: doc.id,
      songName: data['songName'] ?? '',
      lyrics: data['lyrics'] ?? '',
      language: data['language'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? data['createdAt'] ?? Timestamp.now(),
      changeType: data['changeType'] ?? 'created',
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'songName': songName,
      'lyrics': lyrics,
      'language': language,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'changeType': changeType,
      'isDeleted': isDeleted,
    };
  }

  // ✅ ADDED: Convenience methods
  Song copyWith({
    String? id,
    String? songName,
    String? lyrics,
    String? language,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? changeType,
    bool? isDeleted,
  }) {
    return Song(
      id: id ?? this.id,
      songName: songName ?? this.songName,
      lyrics: lyrics ?? this.lyrics,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      changeType: changeType ?? this.changeType,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String toString() {
    return 'Song(id: $id, songName: $songName, language: $language, changeType: $changeType, isDeleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // ✅ ADDED: Validation methods
  bool get isValid {
    return id.isNotEmpty && 
           songName.trim().isNotEmpty && 
           lyrics.trim().isNotEmpty && 
           language.isNotEmpty;
  }

  bool get isNewSong => changeType == 'created';
  bool get isEditedSong => changeType == 'edited';
  bool get isDeletedSong => changeType == 'deleted' || isDeleted;
}

// ✅ ADDED: Extension for list operations
extension SongListExtensions on List<Song> {
  List<Song> get activeSongs => where((song) => !song.isDeleted).toList();
  List<Song> get deletedSongs => where((song) => song.isDeleted).toList();
  
  List<Song> byLanguage(String language) => 
      where((song) => song.language == language).toList();
  
  List<Song> search(String query) {
    final queryLower = query.toLowerCase();
    return where((song) => 
      song.songName.toLowerCase().contains(queryLower) ||
      song.lyrics.toLowerCase().contains(queryLower)
    ).toList();
  }
  
  Map<String, List<Song>> groupByLanguage() {
    final Map<String, List<Song>> grouped = {};
    for (final song in this) {
      grouped.putIfAbsent(song.language, () => []).add(song);
    }
    return grouped;
  }
}
