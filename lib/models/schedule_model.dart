import 'package:cloud_firestore/cloud_firestore.dart';

class Schedule {
  final String id;
  final Timestamp scheduleDate;
  final String? scheduleText;
  final List<String> songIds;
  final List<String> bibleIds;

  Schedule({
    required this.id,
    required this.scheduleDate,
    this.scheduleText,
    required this.songIds,
    required this.bibleIds,
  });

  // For your firestore_service.dart fromFirestore calls
  static Schedule fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Schedule(
      id: doc.id,
      scheduleDate: data['scheduleDate'] ?? Timestamp.now(),
      scheduleText: data['scheduleText'],
      songIds: List<String>.from(data['songIds'] ?? []),
      bibleIds: List<String>.from(data['bibleIds'] ?? []),
    );
  }

  // For your firestore_service.dart toFirestore calls
  Map<String, dynamic> toFirestore() {
    return {
      'scheduleDate': scheduleDate,
      'scheduleText': scheduleText,
      'songIds': songIds,
      'bibleIds': bibleIds,
    };
  }

  // Keep existing methods for compatibility
  factory Schedule.fromMap(Map<String, dynamic> map, String documentId) {
    return Schedule(
      id: documentId,
      scheduleDate: map['scheduleDate'] ?? Timestamp.now(),
      scheduleText: map['scheduleText'],
      songIds: List<String>.from(map['songIds'] ?? []),
      bibleIds: List<String>.from(map['bibleIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduleDate': scheduleDate,
      'scheduleText': scheduleText,
      'songIds': songIds,
      'bibleIds': bibleIds,
    };
  }
}
