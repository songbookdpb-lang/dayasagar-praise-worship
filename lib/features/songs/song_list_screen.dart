import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/song_models.dart';
import 'song_list_provider.dart'; 

bool _isSadriLocal(String language) {
  final lang = language.trim().toLowerCase();
  return lang.startsWith('sad') || lang.contains('sadri');
}

bool _isLocal(String language) => _isSadriLocal(language);

class SongListScreen extends ConsumerStatefulWidget {
  final String language;

  const SongListScreen({
    super.key,
    required this.language,
  });

  @override
  ConsumerState<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends ConsumerState<SongListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        ref.read(songSearchQueryProvider(widget.language).notifier).state = _searchController.text;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (!mounted) return;
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        ref.read(songSearchQueryProvider(widget.language).notifier).state = '';
        _searchFocusNode.unfocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _searchFocusNode.canRequestFocus) {
            _searchFocusNode.requestFocus();
          }
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
        if (!didPop && _isSearching && mounted) _toggleSearch();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          title: Text(
            '${widget.language} Songs',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
              onPressed: _toggleSearch,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                children: [
                  if (_isSearching) _buildSearchBar(),
                  if (_isSearching) const SizedBox(height: 8),
                  Expanded(
                    child: _isSearching
                        ? _buildSearchResults()
                        : _buildSongsList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search ${widget.language} songs...',
          hintStyle: GoogleFonts.inter(
            color: (isDark ? Colors.white : const Color(0xFF1F2937))
                .withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildSearchResults() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final searchResultsAsync = ref.watch(songSearchResultsProvider(widget.language));

    if (_searchController.text.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Start typing to search songs',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : const Color(0xFF1F2937))
                  .withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return searchResultsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return Center(
            child: Padding(
              // ✅ ADDED: Padding around empty state
              padding: const EdgeInsets.all(32),
              child: Text(
                'No songs found',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : const Color(0xFF1F2937))
                      .withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(songSearchResultsProvider(widget.language));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return _buildSongCard(song, isDark);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Error: $error',
            style: GoogleFonts.inter(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }

  Widget _buildSongsList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final songsAsync = ref.watch(cachedSongsProvider(widget.language));

    return songsAsync.when(
      data: (songs) {
        final activeSongs = songs.where((song) => !song.isDeleted).toList();
        
        if (activeSongs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No ${widget.language} songs available',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : const Color(0xFF1F2937))
                      .withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(cachedSongsProvider(widget.language));
            final syncNotifier = ref.read(syncStatusProvider.notifier);
            await syncNotifier.performSync();
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
            itemCount: activeSongs.length,
            itemBuilder: (context, index) {
              final song = activeSongs[index];
              return _buildSongCard(song, isDark);
            },
          ),
        );
      },
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading songs',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(cachedSongsProvider(widget.language));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongCard(Song song, bool isDark) {
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
            ref.read(recentlyPlayedProvider.notifier).addRecentSong(song.id);
            context.push('/song/${song.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
            child: Center(
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
          ),
        ),
      ),
    );
  }
}
