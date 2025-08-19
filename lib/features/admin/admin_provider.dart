
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firestore_service.dart';
import '../../models/song_models.dart';
import '../../models/schedule_model.dart';

// Search providers
final adminSongSearchProvider = StateProvider<String>((ref) => '');
final adminScheduleSearchProvider = StateProvider<String>((ref) => '');

// Data providers
final adminSongsProvider = StreamProvider<List<Song>>((ref) {
  return ref.read(firestoreServiceProvider).getSongs();
});

final adminSchedulesProvider = StreamProvider<List<Schedule>>((ref) {
  return ref.read(firestoreServiceProvider).getSchedules();
});
