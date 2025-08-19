import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import '../../models/search_result_model.dart';
import '../../widgets/app_drawer.dart';
import 'home_provider.dart';

void _debugLog(String message) {
  if (kDebugMode) {
    debugPrint('[HomeScreen] $message');
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(homeSearchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        ref.read(homeSearchQueryProvider.notifier).state = '';
        _searchFocusNode.unfocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      }
    });
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exit App?',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: Text(
                'Are you sure you want to close Dayasagar praise and worship?',
                style: GoogleFonts.inter()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // NEW: Show Donate Us dialog (same as AppDrawer)
  void _showDonateUsDialog(Map<String, dynamic> settings) {
  final donateText = settings['donateUsText'] ?? '';
  final qrCodeUrl = settings['donateUsQrCodeUrl'];
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Simple Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Text(
                'Donate Usz',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Donate message (only if exists)
                    if (donateText.isNotEmpty) ...[
                      Text(
                        donateText,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.5,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // QR Code (only if exists)
                    if (qrCodeUrl != null && qrCodeUrl.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            qrCodeUrl,
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                width: 180,
                                height: 180,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: theme.colorScheme.primary,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 32,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Failed to load',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ] else if (donateText.isEmpty) ...[
                      // No content available
                      Container(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No donation information available',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Close button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (_isSearching) {
          _toggleSearch();
        } else {
          final shouldPop = await _showExitDialog(context);
          if (shouldPop) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        drawer: const AppDrawer(),
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
                  errorBuilder: (context, error, stackTrace) => Container(
                    child: Icon(
                      Icons.church,
                      size: 100,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
            ),
            // Background shapes
            _buildBackgroundShapes(),
            // Main content
            Column(
              children: [
                if (_isSearching) _buildSearchBar(),
                if (!_isSearching) _buildHeader(),
                Expanded(
                  child: _isSearching
                      ? _buildSearchResults()
                      : _buildDefaultContent(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  // Header matching image design
  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              color: (isDark ? Colors.white : const Color(0xFF1F2937))
                  .withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dayasagar\nPraise & Worship',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          ),
          onPressed: () {
            _debugLog("Search button pressed");
            _toggleSearch();
          },
          tooltip: _isSearching ? 'Close search' : 'Search',
        )
      ],
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          hintText: 'Search songs and Bible verses...',
          hintStyle: GoogleFonts.inter(
            color: (isDark ? Colors.white : const Color(0xFF1F2937))
                .withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: (isDark ? Colors.white : const Color(0xFF1F2937))
                .withValues(alpha: 0.6),
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937))
                        .withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(homeSearchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
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
          fillColor:
              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (value) {
          ref.read(homeSearchQueryProvider.notifier).state = value;
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildDefaultContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ListView(
        children: [
          _buildTodaysGodsWordsSection(),
          const SizedBox(height: 32),
          _buildNavigationList(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchResultsAsync = ref.watch(homeSearchResultsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: searchResultsAsync.when(
        data: (results) {
          if (_searchController.text.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937))
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start typing to search',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : const Color(0xFF1F2937))
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937))
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : const Color(0xFF1F2937))
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return _buildSearchResultItem(result);
            },
          );
        },
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Searching...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: (isDark ? Colors.white : const Color(0xFF1F2937))
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Search Error',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? Colors.white : const Color(0xFF1F2937))
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(SearchResult result) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content;
    VoidCallback onTap;

    if (result is SongSearchResult) {
      final song = result.song;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song.songName,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            song.lyrics,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: (isDark ? Colors.white : const Color(0xFF1F2937))
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      );
      onTap = () => context.push('/song/${song.id}');
    } else if (result is BibleSearchResult) {
      final verse = result.verse;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${verse.book} ${verse.chapter}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            verse.verse,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: (isDark ? Colors.white : const Color(0xFF1F2937))
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      );
      onTap = () => context.push('/bible/${verse.id}');
    } else {
      return const SizedBox.shrink();
    }

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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationList() {
    final appSettingsAsync = ref.watch(appSettingsProvider);

    return appSettingsAsync.when(
      data: (settings) {
        final buttons = <Map<String, dynamic>>[];

        buttons.add({
          'title': 'Songs',
          'onTap': () => context.push('/song_languages'),
          'enabled': true,
        });
        buttons.add({
          'title': 'Bible',
          'onTap': () => context.push('/bible_languages'),
          'enabled': true,
        });

        // UPDATED: Check if donate feature is enabled AND has content
        final isDonateUsEnabled = settings['isDonateUsEnabled'] ?? false;
        final donateUsText = settings['donateUsText'] ?? '';
        final donateUsQrCodeUrl = settings['donateUsQrCodeUrl'] ?? '';

        if (isDonateUsEnabled &&
            (donateUsText.isNotEmpty || donateUsQrCodeUrl.isNotEmpty)) {
          buttons.add({
            'title': 'Donate us',
            'onTap': () => _showDonateUsDialog(settings),
            'enabled': true,
          });
        }

        final isYoutubeEnabled = settings['isYoutubeEnabled'] ?? false;
        final isInstagramEnabled = settings['isInstagramEnabled'] ?? false;
        final isWhatsappEnabled = settings['isWhatsappEnabled'] ?? false;
        final isShareEnabled = settings['isShareEnabled'] ?? true;
        final isRateUsEnabled = settings['isRateUsEnabled'] ?? true;
        final hasSocialFeatures = isYoutubeEnabled ||
            isInstagramEnabled ||
            isWhatsappEnabled ||
            isShareEnabled ||
            isRateUsEnabled;

        if (hasSocialFeatures) {
          buttons.add({
            'title': 'Social',
            'onTap': () => _showSocialOptions(settings),
            'enabled': true,
          });
        }
        buttons.add({
          'title': 'About',
          'onTap': () => _showAboutDialog(settings),
          'enabled': true,
        });

        return Column(
          children: buttons
              .where((button) => button['enabled'] as bool)
              .map((button) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: _buildNavButton(
                      title: button['title'] as String,
                      onTap: button['onTap'] as VoidCallback,
                    ),
                  ))
              .toList(),
        );
      },
      loading: () => Column(
        children: [
          _buildNavButton(
              title: 'Songs', onTap: () => context.push('/song_languages')),
          const SizedBox(height: 12),
          _buildNavButton(
              title: 'Bible', onTap: () => context.push('/bible_languages')),
          const SizedBox(height: 12),
          _buildNavButton(title: 'Social', onTap: () => _showSocialOptions({})),
          const SizedBox(height: 12),
          _buildNavButton(title: 'About', onTap: () => _showAboutDialog({})),
        ],
      ),
      error: (err, stack) => Column(
        children: [
          _buildNavButton(
              title: 'Songs', onTap: () => context.push('/song_languages')),
          const SizedBox(height: 12),
          _buildNavButton(
              title: 'Bible', onTap: () => context.push('/bible_languages')),
          const SizedBox(height: 12),
          _buildNavButton(title: 'About', onTap: () => _showAboutDialog({})),
        ],
      ),
    );
  }

  // Simple button matching image design
  Widget _buildNavButton({required String title, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // DYNAMIC Today's God's Words section with tap to expand
  Widget _buildTodaysGodsWordsSection() {
    final scheduleTextAsync = ref.watch(todayScheduleTextProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            "Today's God's Words",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          scheduleTextAsync.when(
            data: (scheduleText) {
              if (scheduleText == null || scheduleText.isEmpty) {
                return Text(
                  "No God's words scheduled for today.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937))
                        .withValues(alpha: 0.7),
                  ),
                );
              }
              return GestureDetector(
                onTap: () => _showFullScreenGodsWordsDialog(scheduleText),
                child: Column(
                  children: [
                    Text(
                      scheduleText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: (isDark ? Colors.white : const Color(0xFF1F2937))
                            .withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to expand',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
            error: (e, s) => Text(
              "Could not load God's words for today.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Keep all remaining methods unchanged (all the dialog methods and social functions)
  void _showFullScreenGodsWordsDialog(String scheduleText) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
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
                              const Color(0xFF1E293B),
                              const Color(0xFF334155),
                              const Color(0xFF0F172A),
                            ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.3,
                    child: Image.asset(
                      'assets/images/cross_light.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          child: Icon(
                            Icons.church,
                            size: 200,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                _buildPopupBackgroundShapes(),
                SafeArea(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.auto_stories,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                "Today's God's Words",
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 24),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface
                                .withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              scheduleText,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                height: 1.8,
                                color: theme.colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: scheduleText));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            const Text('Copied to clipboard'),
                                        backgroundColor:
                                            theme.colorScheme.primary,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.copy,
                                      color: theme.colorScheme.primary),
                                  label: Text(
                                    'Copy',
                                    style: GoogleFonts.inter(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    side: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Share.share(
                                      "Today's God's Words:\n\n$scheduleText\n\nShared from Dayasagar Praise and Worship App",
                                      subject: "Today's God's Words",
                                    );
                                  },
                                  icon: Icon(Icons.share,
                                      color: theme.colorScheme.primary),
                                  label: Text(
                                    'Share',
                                    style: GoogleFonts.inter(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    side: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupBackgroundShapes() {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned(
          top: 100,
          right: -100,
          child: Opacity(
            opacity: 0.15,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(150),
                  topLeft: Radius.circular(150),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 400,
          left: -150,
          child: Opacity(
            opacity: 0.12,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(200),
                  bottomRight: Radius.circular(200),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 150,
          right: -80,
          child: Opacity(
            opacity: 0.1,
            child: Container(
              width: 200,
              height: 200,
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

  void _showAboutDialog(Map<String, dynamic> settings) {
    final aboutUs = settings['aboutUs'] ??
        'Dayasagar Praise and Worship is a dedicated platform for spiritual growth and worship. Join us in celebrating faith through music and scripture.';
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.1),
                theme.colorScheme.surface,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const CircleAvatar(
                          radius: 30,
                          backgroundImage: AssetImage('assets/images/logo.png'),
                        )),
                    const SizedBox(height: 16),
                    Text(
                      'Dayasagar Praise and Worship',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        aboutUs,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.6,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Multilingual worship songs',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Daily God's words",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Bible verses in multiple languages',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Offline access with caching',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSocialOptions(Map<String, dynamic> settings) {
    final isYoutubeEnabled = settings['isYoutubeEnabled'] ?? false;
    final isInstagramEnabled = settings['isInstagramEnabled'] ?? false;
    final isWhatsappEnabled = settings['isWhatsappEnabled'] ?? false;
    final isShareEnabled = settings['isShareEnabled'] ?? true;
    final isRateUsEnabled = settings['isRateUsEnabled'] ?? true;

    final socialOptions = <Widget>[];

    if (isShareEnabled) {
      socialOptions.addAll([
        _buildSocialOption('Share App', Icons.share, Colors.blue, () {
          Navigator.pop(context);
          _shareApp();
        }),
        const SizedBox(height: 12),
      ]);
    }

    if (isYoutubeEnabled) {
      socialOptions.addAll([
        _buildSocialOption(
            'YouTube Channel', Icons.play_circle_fill, Colors.red, () {
          Navigator.pop(context);
          _openYouTube(settings['youtubeUrl'] ?? '');
        }),
        const SizedBox(height: 12),
      ]);
    }

    if (isInstagramEnabled) {
      socialOptions.addAll([
        _buildSocialOption('Instagram', Icons.camera_alt, Colors.purple, () {
          Navigator.pop(context);
          _openInstagram(settings['instagramUrl'] ?? '');
        }),
        const SizedBox(height: 12),
      ]);
    }

    if (isWhatsappEnabled) {
      socialOptions.addAll([
        _buildSocialOption('WhatsApp', Icons.message, Colors.green, () {
          Navigator.pop(context);
          _openWhatsApp(settings['whatsappNumber'] ?? '');
        }),
        const SizedBox(height: 12),
      ]);
    }

    if (isRateUsEnabled) {
      socialOptions.addAll([
        _buildSocialOption('Rate Us', Icons.star, Colors.orange, () {
          Navigator.pop(context);
          _rateApp();
        }),
      ]);
    }

    if (socialOptions.isNotEmpty && socialOptions.last is SizedBox) {
      socialOptions.removeLast();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Connect With Us',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              ...socialOptions,
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSocialOption(
      String title, IconData icon, Color color, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  // Keep all original social functionality methods unchanged
  Future<void> _shareApp() async {
    try {
      await Share.share(
        'Check out Dayasagar Praise & Worship app! 🎵✨\n\n'
        'Discover beautiful worship songs and Bible verses in multiple languages including Hindi, English, Odia, and Sadri.\n\n'
        'Download now: [Your Play Store Link]',
        subject: 'Dayasagar Praise & Worship App',
      );
    } catch (e) {
      _showSnackbar('Failed to share app');
    }
  }

  Future<void> _openYouTube(String adminYouTubeUrl) async {
    final youtubeUrl = adminYouTubeUrl.isNotEmpty
        ? adminYouTubeUrl
        : 'https://youtube.com/@dayasagarchurch';

    try {
      final Uri webUrl = Uri.parse(youtubeUrl);
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackbar('Failed to open YouTube');
    }
  }

  Future<void> _openInstagram(String adminInstagramUrl) async {
    final instagramUrl = adminInstagramUrl.isNotEmpty
        ? adminInstagramUrl
        : 'https://instagram.com/dayasagarchurch';

    try {
      final Uri webUrl = Uri.parse(instagramUrl);
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackbar('Failed to open Instagram');
    }
  }

  Future<void> _openWhatsApp(String adminWhatsAppNumber) async {
    final phoneNumber =
        adminWhatsAppNumber.isNotEmpty ? adminWhatsAppNumber : '+1234567890';
    const message =
        'Hello! I found you through the Dayasagar Praise & Worship app. ';

    try {
      final Uri whatsappUrl = Uri.parse(
          'https://wa.me/${phoneNumber.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'WhatsApp not installed';
      }
    } catch (e) {
      _showSnackbar(
          'WhatsApp not available. Please install WhatsApp or contact us directly at $phoneNumber');
    }
  }

  Future<void> _rateApp() async {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.example.app';

    try {
      final Uri playStoreUri = Uri.parse(playStoreUrl);
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Play Store not available';
      }
    } catch (e) {
      _showSnackbar('Unable to open app store for rating');
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
