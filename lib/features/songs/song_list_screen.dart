import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/songs/song_list_provider.dart';
import '../../models/song_models.dart';

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
  final _scrollController = ScrollController();
  double _fontSize = 18.0;
  List<Song> _filteredSongs = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        _filterSongs(_searchController.text);
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(songsPaginationProvider(widget.language).notifier);
      notifier.fetchNextPage();
    }
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredSongs.clear();
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

  void _filterSongs(String query) {
    if (!mounted) return;
    final songsState = ref.read(songsPaginationProvider(widget.language));

    if (query.isEmpty) {
      setState(() => _filteredSongs.clear());
    } else {
      final songs = songsState.songs;
      setState(() {
        _filteredSongs = songs
            .where(
              (song) =>
                  song.songName.toLowerCase().contains(query.toLowerCase()) ||
                  song.lyrics.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      });
    }
  }

  void _increaseFontSize() {
    if (_fontSize < 34.0) setState(() => _fontSize += 2.0);
  }

  void _decreaseFontSize() {
    if (_fontSize > 14.0) setState(() => _fontSize -= 2.0);
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
    final songsState = ref.watch(songsPaginationProvider(widget.language));

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _isSearching && mounted) _toggleSearch();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(theme, isDark),
        body: Stack(
          children: [
            // Gradient background
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
            // Cross image overlay
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
            SafeArea(
              child: _buildScrollableContent(songsState, isDark),
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
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
            size: 24,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            ref.read(songsPaginationProvider(widget.language).notifier).refresh();
          },
          tooltip: 'Refresh songs',
        ),
      ],
    );
  }

  Widget _buildScrollableContent(SongsPaginationState songsState, bool isDark) {
    if (songsState.isLoading && songsState.songs.isEmpty) {
      return _buildLoadingState(isDark);
    } else if (songsState.error != null && songsState.songs.isEmpty) {
      return _buildErrorState(songsState.error!, isDark);
    } else if (songsState.songs.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        if (mounted) {
          await ref.read(songsPaginationProvider(widget.language).notifier).refresh();
        }
      },
      color: isDark ? Colors.amber[300] : Colors.brown,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _buildScrollableHeader(songsState, isDark),
          ),
          if (_isSearching)
            SliverToBoxAdapter(
              child: _buildSearchBar(isDark),
            ),
          SliverToBoxAdapter(
            child: _isSearching
                ? _buildSearchResults(isDark)
                : _buildSongsList(songsState.songs, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableHeader(SongsPaginationState songsState, bool isDark) {
    String title = widget.language == 'Sadri' ? 'Sadri Songs' : '${widget.language} Songs';
    String subtitle;
    if (songsState.isLoading) {
      subtitle = 'Loading ${widget.language} songs from offline data...';
    } else if (songsState.error != null) {
      subtitle = 'Browse ${widget.language} songs';
    } else {
      subtitle = '${songsState.songs.length} songs • offline • ${widget.language}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'WORSHIP COLLECTION',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search ${widget.language} songs by name or lyrics...',
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
                    _filteredSongs.clear();
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
          _filterSongs(value);
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_searchController.text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            'Enter search terms to find ${widget.language} songs',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    if (_filteredSongs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Text(
                'No ${widget.language} songs found',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try different search terms',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_filteredSongs.length} result${_filteredSongs.length == 1 ? '' : 's'} for "${_searchController.text}"',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._filteredSongs.map((song) => _buildSongCard(song, isDark)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSongsList(List<Song> songs, bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _decreaseFontSize,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'A⁻',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_fontSize.toInt()}pt',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: _increaseFontSize,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'A⁺',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ...songs.map((song) => _buildSongCard(song, isDark)),
          const SizedBox(height: 50),
        ],
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
            HapticFeedback.selectionClick();
            context.push('/song/${song.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Center(
              child: Text(
                song.songName,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: _fontSize,
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

  Widget _buildLoadingState(bool isDark) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading ${widget.language} songs from offline data...',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reading ${widget.language} songs from local storage',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.offline_pin,
              size: 64,
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No ${widget.language} songs found',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No ${widget.language} songs available in local data',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                if (mounted) {
                  ref.read(songsPaginationProvider(widget.language).notifier).refresh();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Reload Local Data',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading ${widget.language} songs',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load ${widget.language} songs from local data\n$error',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (mounted) {
                      ref.read(songsPaginationProvider(widget.language).notifier).refresh();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Retry',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Go Back',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
