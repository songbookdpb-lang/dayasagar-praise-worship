import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/song_models.dart';
import '../../services/incremental_sync_service.dart';

final globalSongSearchProvider = StateProvider<String>((ref) => '');

final globalSongSearchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(globalSongSearchProvider);
  if (query.trim().isEmpty) return [];
  
  try {
    final syncService = ref.read(incrementalSyncServiceProvider);
    return await syncService.searchCachedSongs(query.trim());
  } catch (e) {
    return [];
  }
});

class SongLanguageScreen extends ConsumerStatefulWidget {
  const SongLanguageScreen({super.key});

  @override
  ConsumerState<SongLanguageScreen> createState() => _SongLanguageScreenState();
}

class _SongLanguageScreenState extends ConsumerState<SongLanguageScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  final List<Map<String, String>> _songLanguages = [
    {
      'name': 'English',
      'display': 'English',
    },
    {
      'name': 'Hindi', 
      'display': 'हिन्दी',
    },
    {
      'name': 'Odia',
      'display': 'ଓଡିଆ',
    },
    {
      'name': 'Sardari',
      'display': 'सादरी',
    },
    {
      'name': 'Mundari',
      'display': 'ମୁଣ୍ଡାରୀ',
    }
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
          title: Text(
            'Worship Songs',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          actions: [
            Center(
              child: IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  size: 24,
                ),
                onPressed: _toggleSearch,
              ),
            ),
          ],
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

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search songs in all languages',
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
          ref.read(globalSongSearchProvider.notifier).state = value;
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Text(
        'Worship Songs',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildLanguageList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 40), 
          ..._songLanguages.map((language) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton(
                onPressed: () {
                  print('Navigating to: /songs/${language['name']}');
                  context.push('/songs/${language['name']}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                  foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                ),
                child: Text(
                  language['display']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
        ],
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
                  'Search in all languages',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
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
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/song/${song.id}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                    foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                  ),
                  child: Text(
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
                ),
              );
            },
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
      error: (err, stack) => Center(
        child: Text(
          'Search error',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}
