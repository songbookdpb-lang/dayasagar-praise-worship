import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dayasagar_praise_worship/screens/bible_verse_list_screen.dart';
import 'package:dayasagar_praise_worship/features/admin/admin_login_screen.dart';

import 'features/home/home_screen.dart';
import 'features/songs/song_language_screen.dart';
import 'features/songs/song_list_screen.dart' as song_features;
import 'features/songs/song_lyrics_screen.dart' as song_screens;
import 'screens/bible_language_screen.dart';
import 'screens/bible_book_list_screen.dart';
import 'screens/bible_chapter_list_screen.dart';
import 'features/admin/admin_panel_screen.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isGoingToAdmin = state.uri.toString().startsWith('/admin');
      final isGoingToAdminLogin = state.uri.toString() == '/admin_login';

      if (isGoingToAdmin && !isGoingToAdminLogin && user == null) {
        return '/admin_login';
      }

      if (isGoingToAdminLogin && user != null) {
        return '/admin';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      GoRoute(
        path: '/song_languages',
        name: 'song_languages',
        builder: (context, state) => const SongLanguageScreen(),
      ),
      GoRoute(
        path: '/songs/:language',
        name: 'songs_by_language',
        builder: (context, state) {
          final language = state.pathParameters['language']!;
          print('Songs route - Language: $language'); // Debug print
          return song_features.SongListScreen(language: language);
        },
      ),

      GoRoute(
        path: '/bible_languages',
        name: 'bible_languages',
        builder: (context, state) => const BibleLanguageScreen(),
      ),
      GoRoute(
        path: '/bible/:language/books',
        name: 'bible_books',
        builder: (context, state) {
          final language = state.pathParameters['language']!;
          return BibleBookListScreen(language: language);
        },
      ),
      GoRoute(
        path: '/bible/:language/:bookName/chapters',
        name: 'bible_chapters',
        builder: (context, state) {
          final language = state.pathParameters['language']!;
          final bookName = state.pathParameters['bookName']!;
          return BibleChapterListScreen(language: language, bookName: bookName);
        },
      ),
      GoRoute(
        path: '/bible/:language/:bookName/chapter/:chapterNumber',
        name: 'bible_verses',
        builder: (context, state) {
          final language = state.pathParameters['language']!;
          final bookName = state.pathParameters['bookName']!;
          final chapterNumber = state.pathParameters['chapterNumber']!;
          return BibleVerseListScreen(
            language: language,
            bookName: bookName,
            chapterNumber: chapterNumber,
          );
        },
      ),

      GoRoute(
        path: '/song/:songId',
        name: 'song_detail',
        builder: (context, state) {
          final songId = state.pathParameters['songId']!;
          print('Song detail route - SongId: $songId'); // Debug print
          return song_screens.SongLyricsScreen(songId: songId);
        },
      ),
      GoRoute(
        path: '/bible/:verseId',
        name: 'bible_verse_detail',
        builder: (context, state) {
          final verseId = state.pathParameters['verseId']!;
          return _PlaceholderScreen(
            title: 'Bible Verse',
            message:
                'Verse ID: $verseId\n\nBibleVerseDetailScreen needs to be implemented',
            icon: Icons.auto_stories,
          );
        },
      ),
      GoRoute(
        path: '/admin_login',
        name: 'admin_login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin_panel',
        builder: (context, state) => const AdminPanelScreen(),
      ),
    ],

    errorBuilder: (context, state) =>
        _ErrorScreen(location: state.uri.toString()),
  );
});

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _PlaceholderScreen({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF0F172A),
                        const Color(0xFF1E293B),
                        const Color(0xFF334155),
                      ]
                    : [
                        const Color(0xFFE2E8F0),
                        const Color(0xFF94A3B8),
                        const Color(0xFF475569),
                      ],
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.12 : 0.06,
              child: Image.asset(
                'assets/images/cross_light.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.church,
                  size: 100,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.1,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, size: 64, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 32),
                Text(
                  'Screen Not Implemented',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: (isDark ? Colors.white : const Color(0xFF1F2937))
                          .withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String location;

  const _ErrorScreen({required this.location});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF0F172A),
                        const Color(0xFF1E293B),
                        const Color(0xFF334155),
                      ]
                    : [
                        const Color(0xFFE2E8F0),
                        const Color(0xFF94A3B8),
                        const Color(0xFF475569),
                      ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '404 - Page Not Found',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'The page "$location" does not exist.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: (isDark ? Colors.white : const Color(0xFF1F2937))
                          .withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home),
                    label: const Text('Go Home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
