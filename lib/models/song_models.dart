import 'package:cloud_firestore/cloud_firestore.dart';

class Song {
  final String id;
  final String songName;
  final String lyrics;
  final String language;
  final Timestamp createdAt;

  Song({
    required this.id,
    required this.songName,
    required this.lyrics,
    required this.language,
    required this.createdAt,
  });

  // For your firestore_service.dart fromFirestore calls
  static Song fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Song(
      id: doc.id,
      songName: data['songName'] ?? '',
      lyrics: data['lyrics'] ?? '',
      language: data['language'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // For your firestore_service.dart toFirestore calls
  Map<String, dynamic> toFirestore() {
    return {
      'songName': songName,
      'lyrics': lyrics,
      'language': language,
      'createdAt': createdAt,
    };
  }

  // Keep existing methods for compatibility
  factory Song.fromMap(Map<String, dynamic> map, String documentId) {
    return Song(
      id: documentId,
      songName: map['songName'] ?? '',
      lyrics: map['lyrics'] ?? '',
      language: map['language'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'songName': songName,
      'lyrics': lyrics,
      'language': language,
      'createdAt': createdAt,
    };
  }
}
