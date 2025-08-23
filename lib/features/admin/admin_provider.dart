import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/incremental_sync_service.dart';
import '../../models/song_models.dart';
import '../../models/schedule_model.dart';

final adminSongSearchProvider = StateProvider<String>((ref) => '');
final adminScheduleSearchProvider = StateProvider<String>((ref) => '');

final adminSongsProvider = StreamProvider<List<Song>>((ref) {
  return FirebaseFirestore.instance
      .collection('songs')
      .snapshots()
      .asyncMap((snapshot) async {
    
    final songs = <Song>[];
    
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final song = Song(
          id: doc.id,
          songName: data['songName'] ?? '',
          lyrics: data['lyrics'] ?? '',
          language: data['language'] ?? '',
          createdAt: data['createdAt'] ?? Timestamp.now(),
          updatedAt: data['updatedAt'] ?? Timestamp.now(),
          changeType: data['changeType'] ?? 'unchanged',
          isDeleted: data['isDeleted'] ?? false,
        );
        songs.add(song);
      } catch (e) {
        print('Error parsing song ${doc.id}: $e');
      }
    }
    
    final syncService = ref.read(incrementalSyncServiceProvider);
    syncService.updateLocalCache(songs);
    
    return songs;
  });
});

final adminSchedulesProvider = StreamProvider<List<Schedule>>((ref) {
  return FirebaseFirestore.instance
      .collection('schedules')
      .orderBy('scheduleDate', descending: true)
      .snapshots()
      .map((snapshot) {
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Schedule(
        id: doc.id,
        scheduleDate: data['scheduleDate'] ?? Timestamp.now(),
        scheduleText: data['scheduleText'],
        songIds: List<String>.from(data['songIds'] ?? []),
        bibleIds: List<String>.from(data['bibleIds'] ?? []),
      );
    }).toList();
  });
});

final adminFilteredSongsProvider = Provider<List<Song>>((ref) {
  final songs = ref.watch(adminSongsProvider).value ?? [];
  final q = ref.watch(adminSongSearchProvider).toLowerCase().trim();
  
  return q.isEmpty ? songs : AdminSongListExtensions(songs).search(q);
});

final adminActiveSongsProvider = Provider<List<Song>>((ref) {
  final songs = ref.watch(adminSongsProvider).value ?? [];
  return AdminSongListExtensions(songs).activeSongs;
});

final adminSongsByChangeTypeProvider = Provider<Map<String, List<Song>>>((ref) {
  final songs = ref.watch(adminSongsProvider).value ?? [];
  return {
    for (final s in songs) (s.changeType ?? 'unchanged') : [
      ...(songs.where((t) => (t.changeType ?? 'unchanged') == (s.changeType ?? 'unchanged')))
    ]
  };
});

final adminSyncStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final songs = ref.watch(adminSongsProvider).value ?? [];
  final activeSongs = AdminSongListExtensions(songs).activeSongs;
  final deletedSongs = AdminSongListExtensions(songs).deletedSongs;
  final groupedByLang = AdminSongListExtensions(songs).groupByLanguage();
  
  return {
    'total': songs.length,
    'active': activeSongs.length,
    'deleted': deletedSongs.length,
    'created': songs.where((s) => (s.changeType ?? 'unchanged') == 'created').length,
    'edited': songs.where((s) => (s.changeType ?? 'unchanged') == 'edited').length,
    'byLanguage': groupedByLang,
  };
});

final adminFilteredSchedulesProvider = Provider<List<Schedule>>((ref) {
  final schedules = ref.watch(adminSchedulesProvider).value ?? [];
  final query = ref.watch(adminScheduleSearchProvider).trim().toLowerCase();

  if (query.isEmpty) return schedules;

  return schedules.where((schedule) {
    final text = schedule.scheduleText ?? '';
    final dateStr = schedule.scheduleDate.toDate().toIso8601String().substring(0, 10);
    return text.toLowerCase().contains(query) || dateStr.contains(query);
  }).toList();
});

final adminUpcomingSchedulesProvider = Provider<List<Schedule>>((ref) {
  final schedules = ref.watch(adminSchedulesProvider).value ?? [];
  final now = DateTime.now();
  
  return schedules.where((schedule) {
    final scheduleDateTime = schedule.scheduleDate.toDate();
    return scheduleDateTime.isAfter(now) || scheduleDateTime.isAtSameMomentAs(now);
  }).toList()
  ..sort((a, b) => a.scheduleDate.toDate().compareTo(b.scheduleDate.toDate()));
});

final adminTodayScheduleProvider = Provider<Schedule?>((ref) {
  final schedules = ref.watch(adminSchedulesProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));

  try {
    return schedules.firstWhere((schedule) {
      final scheduleDateTime = schedule.scheduleDate.toDate();
      return scheduleDateTime.isAfter(today) && scheduleDateTime.isBefore(tomorrow);
    });
  } catch (e) {
    return null;
  }
});

final adminThisWeekSchedulesProvider = Provider<List<Schedule>>((ref) {
  final schedules = ref.watch(adminSchedulesProvider).value ?? [];
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 7));

  return schedules.where((schedule) {
    final scheduleDateTime = schedule.scheduleDate.toDate();
    return scheduleDateTime.isAfter(startOfWeek) && scheduleDateTime.isBefore(endOfWeek);
  }).toList()
  ..sort((a, b) => a.scheduleDate.toDate().compareTo(b.scheduleDate.toDate()));
});

final adminSchedulesByDateProvider = Provider<Map<String, List<Schedule>>>((ref) {
  final schedules = ref.watch(adminSchedulesProvider).value ?? [];
  final Map<String, List<Schedule>> grouped = {};

  for (final schedule in schedules) {
    final dateKey = schedule.scheduleDate.toDate().toIso8601String().substring(0, 10);
    grouped.putIfAbsent(dateKey, () => []).add(schedule);
  }

  final sortedKeys = grouped.keys.toList()..sort();
  return Map.fromEntries(
    sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
  );
});

final adminDeletedSongsProvider = Provider<List<Song>>((ref) {
  final songs = ref.watch(adminSongsProvider).value ?? [];
  return AdminSongListExtensions(songs).deletedSongs;
});

final adminSongsByLanguageProvider = Provider<Map<String, List<Song>>>((ref) {
  final songs = ref.watch(adminSongsProvider).value ?? [];
  return AdminSongListExtensions(songs).groupByLanguage();
});

final adminRecentSongsProvider = Provider<List<Song>>((ref) {
  final songs = ref.watch(adminSongsProvider).value ?? [];
  return AdminSongListExtensions(songs).recentSongs(days: 7);
});

final adminTopLanguagesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final songs = ref.watch(adminSongsProvider).value ?? [];
  return AdminSongListExtensions(songs).topLanguages();
});

final adminAnalyticsProvider = Provider<Map<String, dynamic>>((ref) {
  final songs = ref.watch(adminSongsProvider).value ?? [];
  final schedules = ref.watch(adminSchedulesProvider).value ?? [];
  final syncStatus = ref.watch(adminSyncStatusProvider);

  final now = DateTime.now();
  final upcomingSchedules = schedules.where((s) => s.scheduleDate.toDate().isAfter(now)).length;
  final todaySchedule = schedules.where((s) {
    final scheduleDate = s.scheduleDate.toDate();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return scheduleDate.isAfter(today) && scheduleDate.isBefore(tomorrow);
  }).length;

  return {
    'songs': {
      'total': songs.length,
      'byStatus': syncStatus,
      'byLanguage': AdminSongListExtensions(songs).groupByLanguage().map((k, v) => MapEntry(k, v.length)),
      'recentlyAdded': AdminSongListExtensions(songs).recentSongs(days: 7).length,
      'averagePerLanguage': songs.isNotEmpty 
          ? (songs.length / AdminSongListExtensions(songs).groupByLanguage().length).round()
          : 0,
    },
    'schedules': {
      'total': schedules.length,
      'upcoming': upcomingSchedules,
      'today': todaySchedule,
      'thisWeek': ref.watch(adminThisWeekSchedulesProvider).length,
      'totalSongs': schedules.fold<int>(0, (currentSum, s) => currentSum + s.songIds.length),
      'totalBibleVerses': schedules.fold<int>(0, (currentSum, s) => currentSum + s.bibleIds.length),
    },
    'performance': {
      'cacheHitRate': _calculateCacheHitRate(songs),
      'syncEfficiency': _calculateSyncEfficiency(syncStatus),
    },
    'lastUpdated': DateTime.now().toIso8601String(),
  };
});

final adminActionsProvider = Provider<AdminActions>((ref) {
  return AdminActions(ref);
});

class AdminActions {
  final Ref _ref;
  
  AdminActions(this._ref);
  
  void updateSongSearch(String query) {
    _ref.read(adminSongSearchProvider.notifier).state = query;
  }
  
  void updateScheduleSearch(String query) {
    _ref.read(adminScheduleSearchProvider.notifier).state = query;
  }
  
  void clearAllSearches() {
    _ref.read(adminSongSearchProvider.notifier).state = '';
    _ref.read(adminScheduleSearchProvider.notifier).state = '';
  }
  
  Future<void> addSong(Song song) async {
    try {
      final firestore = _ref.read(firestoreServiceProvider);
      await firestore.addSong(song);
      
      final syncService = _ref.read(incrementalSyncServiceProvider);
      await syncService.performIncrementalSync();
      
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> updateSong(String id, Song updatedSong) async {
    try {
      final firestore = _ref.read(firestoreServiceProvider);
      await firestore.updateSong(id, updatedSong);
      
      final syncService = _ref.read(incrementalSyncServiceProvider);
      await syncService.performIncrementalSync();
      
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> deleteSong(String songId) async {
    try {
      final firestore = _ref.read(firestoreServiceProvider);
      await firestore.deleteSong(songId);
      
      final syncService = _ref.read(incrementalSyncServiceProvider);
      await syncService.performIncrementalSync();
      
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> addSchedule(Schedule schedule) async {
    try {
      final firestore = _ref.read(firestoreServiceProvider);
      await firestore.saveSchedule(schedule);
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> updateSchedule(String id, Schedule schedule) async {
    try {
      final firestore = _ref.read(firestoreServiceProvider);
      await firestore.updateSchedule(id, schedule);
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      final firestore = _ref.read(firestoreServiceProvider);
      await firestore.deleteSchedule(scheduleId);
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> refreshSongs() async {
    _ref.invalidate(adminSongsProvider);
    final syncService = _ref.read(incrementalSyncServiceProvider);
    await syncService.pullAllLanguagesManually();
  }
  
  Future<void> refreshSchedules() async {
    _ref.invalidate(adminSchedulesProvider);
  }
  
  Future<void> refreshAll() async {
    _ref.invalidate(adminSongsProvider);
    _ref.invalidate(adminSchedulesProvider);
    
    final syncService = _ref.read(incrementalSyncServiceProvider);
    await syncService.pullAllLanguagesManually();
  }
  
  Future<void> forceSyncSongs() async {
    final syncService = _ref.read(incrementalSyncServiceProvider);
    await syncService.forceCompleteRefresh();
    _ref.invalidate(adminSongsProvider);
  }
  
  Map<String, dynamic> getQuickStats() {
    final analytics = _ref.read(adminAnalyticsProvider);
    return {
      'totalSongs': analytics['songs']['total'],
      'totalSchedules': analytics['schedules']['total'],
      'recentSongs': analytics['songs']['recentlyAdded'],
      'upcomingSchedules': analytics['schedules']['upcoming'],
      'todaySchedule': analytics['schedules']['today'],
    };
  }
}

class AdminSongListExtensions {
  final List<Song> _songs;
  
  AdminSongListExtensions(this._songs);
  
  List<Song> search(String query) {
    if (query.isEmpty) return _songs;
    final lowerQuery = query.toLowerCase();
    return _songs.where((song) {
      return song.songName.toLowerCase().contains(lowerQuery) ||
             song.lyrics.toLowerCase().contains(lowerQuery) ||
             song.language.toLowerCase().contains(lowerQuery) ||
             song.id.toLowerCase().contains(lowerQuery);
    }).toList();
  }
  
  List<Song> get activeSongs => _songs.where((s) => !s.isDeleted).toList();
  List<Song> get deletedSongs => _songs.where((s) => s.isDeleted).toList();
  
  List<Song> recentSongs({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _songs.where((s) => s.createdAt.toDate().isAfter(cutoff)).toList();
  }
  
  Map<String, List<Song>> groupByLanguage() {
    final Map<String, List<Song>> grouped = {};
    for (final song in _songs) {
      grouped.putIfAbsent(song.language, () => []).add(song);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
  }
  
  List<Map<String, dynamic>> topLanguages() {
    final languageGroups = groupByLanguage();
    return languageGroups.entries
        .map((e) => {
          'language': e.key,
          'count': e.value.length,
          'percentage': _songs.isEmpty ? 0 : (e.value.length / _songs.length * 100).round(),
        })
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }
}

extension ScheduleExtensions on Schedule {
  DateTime get dateTime => scheduleDate.toDate();
  
  String get formattedDate => dateTime.toIso8601String().substring(0, 10);
  
  String get formattedDateTime => dateTime.toString().substring(0, 16);
  
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return dateTime.isAfter(today) && dateTime.isBefore(tomorrow);
  }
  
  bool get isUpcoming => dateTime.isAfter(DateTime.now());
  
  bool get isPast => dateTime.isBefore(DateTime.now());
  
  int get totalItems => songIds.length + bibleIds.length;
  
  String get statusDisplay {
    if (isToday) return 'Today';
    if (isUpcoming) return 'Upcoming';
    return 'Past';
  }
}

extension AdminSongExtensions on Song {
  String get changeType => (this as dynamic).changeType ?? 'unchanged';
  
  bool get isNew => changeType == 'created';
  bool get isEdited => changeType == 'edited';
  bool get isUnchanged => changeType == 'unchanged';
  
  String get statusDisplay {
    if (isDeleted) return 'Deleted';
    if (isNew) return 'New';
    if (isEdited) return 'Modified';
    return 'Active';
  }
  
  bool get isRecentlyAdded {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return createdAt.toDate().isAfter(weekAgo);
  }
  
  bool get isRecentlyUpdated {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return updatedAt.toDate().isAfter(weekAgo);
  }
}

double _calculateCacheHitRate(List<Song> songs) {
  if (songs.isEmpty) return 0.0;
  final cached = songs.where((s) => !s.isDeleted).length;
  return (cached / songs.length * 100);
}

double _calculateSyncEfficiency(Map<String, dynamic> syncStatus) {
  final total = syncStatus['total'] as int;
  if (total == 0) return 100.0;
  
  final active = syncStatus['active'] as int;
  return (active / total * 100);
}

extension ListExtensions<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
