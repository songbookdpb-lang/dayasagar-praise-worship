// lib/features/songs/song_language_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/home_provider.dart';

class SongLanguageScreen extends ConsumerStatefulWidget {
  const SongLanguageScreen({super.key});

  @override
  ConsumerState<SongLanguageScreen> createState() => _SongLanguageScreenState();
}

class _SongLanguageScreenState extends ConsumerState<SongLanguageScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  // Language list with English and regional names
  final List<Map<String, String>> _songLanguages = [
    {
      'name': 'English',
      'regional': '',
    },
    {
      'name': 'Hindi', 
      'regional': 'हिंदी',
    },
    {
      'name': 'Odia',
      'regional': 'ଓଡ଼ିଆ',
    },
    {
      'name': 'Sadri',
      'regional': 'सादरी',
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(globalSongSearchProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        ref.read(globalSongSearchProvider.notifier).state = '';
        _searchFocusNode.unfocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      }
    });
  }

  Widget _buildBackgroundShapes() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Stack(
      children: [
        Positioned(
          top: 80,
          right: -50,
          child: Opacity(
            opacity: isDark ? 0.08 : 0.04,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(75),
                  topLeft: Radius.circular(75),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 200,
          left: -80,
          child: Opacity(
            opacity: isDark ? 0.06 : 0.03,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(100),
                  bottomRight: Radius.circular(100),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: -60,
          child: Opacity(
            opacity: isDark ? 0.05 : 0.025,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _isSearching) {
          _toggleSearch();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: _buildAppBar(theme, isDark),
        body: Stack(
          children: [
            // Same gradient background as image
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
            // Same background cross image
            Positioned.fill(
              child: Opacity(
                opacity: isDark ? 0.12 : 0.06,
                child: Image.asset(
                  'assets/images/cross_light.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.church,
                      size: 100,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    );
                  },
                ),
              ),
            ),
            _buildBackgroundShapes(),
            Column(
              children: [
                if (_isSearching) _buildSearchBar(theme, isDark),
                _buildHeader(theme, isDark),
                Expanded(
                  child: _isSearching ? _buildSearchResults() : _buildLanguageList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      iconTheme: IconThemeData(
        color: isDark ? Colors.white : const Color(0xFF1F2937),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close : Icons.search,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
            size: 24,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            _toggleSearch();
          },
          tooltip: _isSearching ? 'Close search' : 'Search songs',
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search songs across all languages...',
          hintStyle: GoogleFonts.inter(
            color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _searchController.clear();
                    ref.read(globalSongSearchProvider.notifier).state = '';
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (value) {
          HapticFeedback.selectionClick();
          ref.read(globalSongSearchProvider.notifier).state = value;
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }
  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        children: [
          Text(
            '',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Worship Songs',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: _songLanguages.map((language) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/songs/${language['name']}');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        language['name']!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      if (language['regional']!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          language['regional']!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchResultsAsync = ref.watch(globalSongSearchResultsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return searchResultsAsync.when(
      data: (songs) {
        if (_searchController.text.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search,
                  size: 64,
                  color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Search across all song languages',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Type to find songs in Hindi, English, Odia, or Sadri',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }
        
        if (songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No songs found',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try different keywords or check spelling',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return _buildSearchResultCard(song, theme, isDark);
            },
          ),
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Searching songs...',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Search Error',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(song, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/song/${song.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              children: [
                Text(
                  song.songName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (song.lyrics.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    song.lyrics,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Song • ${song.language}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
