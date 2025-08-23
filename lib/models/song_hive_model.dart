import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'song_models.dart';

part 'song_hive_model.g.dart'; // This will be generated

@HiveType(typeId: 0)
class SongHive extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String songName;

  @HiveField(2)
  String lyrics;

  @HiveField(3)
  String language;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  String changeType;

  @HiveField(7)
  bool isDeleted;

  @HiveField(8)
  bool isSynced;

  @HiveField(9)
  int fetchBatch;

  // ✅ FIXED: Proper constructor with curly braces for named parameters
  SongHive({
    required this.id,
    required this.songName,
    required this.lyrics,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    required this.changeType,
    this.isDeleted = false,
    this.isSynced = true,
    this.fetchBatch = 0,
  });

  // ✅ FIXED: Factory constructor with proper curly braces for named parameters
  factory SongHive.fromSong(Song song, {int fetchBatch = 0}) {
    return SongHive(
      id: song.id,
      songName: song.songName,
      lyrics: song.lyrics,
      language: song.language,
      createdAt: song.createdAt.toDate(),
      updatedAt: song.updatedAt.toDate(),
      changeType: song.changeType,
      isDeleted: song.isDeleted,
      isSynced: true,
      fetchBatch: fetchBatch,
    );
  }

  // ✅ FIXED: Method to convert to Song model
  Song toSong() {
    return Song(
      id: id,
      songName: songName,
      lyrics: lyrics,
      language: language,
      createdAt: Timestamp.fromDate(createdAt),
      updatedAt: Timestamp.fromDate(updatedAt),
      changeType: changeType,
      isDeleted: isDeleted,
    );
  }

  // ✅ FIXED: CopyWith method with proper named parameters
  SongHive copyWith({
    String? id,
    String? songName,
    String? lyrics,
    String? language,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? changeType,
    bool? isDeleted,
    bool? isSynced,
    int? fetchBatch,
  }) {
    return SongHive(
      id: id ?? this.id,
      songName: songName ?? this.songName,
      lyrics: lyrics ?? this.lyrics,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      changeType: changeType ?? this.changeType,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
      fetchBatch: fetchBatch ?? this.fetchBatch,
    );
  }
}

// ✅ FIXED: SyncMetadata with proper Hive annotations
@HiveType(typeId: 1)
class SyncMetadata extends HiveObject {
  @HiveField(0)
  String language;

  @HiveField(1)
  DateTime lastSyncTime;

  @HiveField(2)
  int currentBatch;

  @HiveField(3)
  String? lastFetchedId;

  @HiveField(4)
  bool hasMoreData;

  // ✅ FIXED: Constructor with proper named parameters
  SyncMetadata({
    required this.language,
    required this.lastSyncTime,
    this.currentBatch = 0,
    this.lastFetchedId,
    this.hasMoreData = true,
  });
}
