import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import '../../models/song_models.dart';
import '../../widgets/app_drawer.dart';
import '../../services/incremental_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void _debugLog(String message) {
  if (kDebugMode) {
    debugPrint('[HomeScreen] $message');
  }
}

final homeSearchQueryProvider = StateProvider<String>((ref) => '');

final appSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('main')
        .get();
    
    if (doc.exists && doc.data() != null) {
      return doc.data()!;
    }
    return <String, dynamic>{};
  } catch (e) {
    return <String, dynamic>{};
  }
});

final todayScheduleTextProvider = FutureProvider<String?>((ref) async {
  try {
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    final doc = await FirebaseFirestore.instance
        .collection('schedules')
        .doc(dateStr)
        .get();
    
    if (doc.exists && doc.data() != null) {
      return doc.data()!['scheduleText'] as String?;
    }
    return null;
  } catch (e) {
    return null;
  }
});

final songsSearchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(homeSearchQueryProvider);
  if (query.trim().isEmpty) return [];
  
  try {
    final syncService = ref.read(incrementalSyncServiceProvider);
    final results = await syncService.searchCachedSongs(query.trim());
    _debugLog('Search completed: ${results.length} songs found for "$query"');
    return results;
  } catch (e) {
    _debugLog('Search error: $e');
    return [];
  }
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  bool _isRefreshing = false;
  bool _showInitialLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(homeSearchQueryProvider.notifier).state = _searchController.text;
    });
    _initializeCache();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeCache() async {
    if (_isInitialized) return;
    
    try {
      _debugLog('Starting cache initialization');
      final syncService = ref.read(incrementalSyncServiceProvider);
      await syncService.initializeSync();
      
      final status = await syncService.getCacheStatus();
      final totalSongs = status['totalSongs'] ?? 0;
      _debugLog('Cache status: $totalSongs total songs');
      
      if (totalSongs == 0) {
        _debugLog('Cache is empty, performing initial sync');
        if (mounted) setState(() => _showInitialLoading = true);
        
        final result = await syncService.forceCompleteRefresh();
        _debugLog('Initial sync completed: ${result.message}');
        
        if (mounted) {
          setState(() => _showInitialLoading = false);
          if (result.success) {
            if (result.newSongs > 0) {
              _showSnackbar('Loaded ${result.newSongs} songs', isError: false);
              ref.invalidate(songsSearchResultsProvider);
            } else {
              _showSnackbar('No songs found. Check your internet connection.', isError: true);
            }
          } else {
            _showSnackbar(result.error ?? 'Failed to load songs');
          }
        }
      } else {
        _debugLog('Cache initialized with $totalSongs songs');
        
        final shouldRefresh = await syncService.shouldRefresh(maxAge: const Duration(minutes: 30));
        if (shouldRefresh) {
          _debugLog('Background refresh needed');
          syncService.performIncrementalSync().then((result) {
            if (mounted && result.success && result.newSongs > 0) {
              _showSnackbar('${result.newSongs} new songs available', isError: false);
              ref.invalidate(songsSearchResultsProvider);
            }
          });
        }
      }
      
      _isInitialized = true;
    } catch (e) {
      _debugLog('Cache initialization failed: $e');
      if (mounted) {
        setState(() => _showInitialLoading = false);
        _showSnackbar('Failed to initialize: $e');
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    _debugLog('Starting manual refresh');
    
    try {
      final syncService = ref.read(incrementalSyncServiceProvider);
      final result = await syncService.pullAllLanguagesManually();

      if (mounted) {
        ref.invalidate(songsSearchResultsProvider);
        ref.invalidate(appSettingsProvider);
        ref.invalidate(todayScheduleTextProvider);
        
        String message = result.message ?? 'Refresh completed';
        if (!result.success) {
          message = result.error ?? 'Refresh failed';
        }
        
        _showSnackbar(message, isError: !result.success);
        _debugLog('Manual refresh completed: $message');
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Refresh failed: $e');
        _debugLog('Manual refresh error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _handleForceRefresh() async {
    final shouldRefresh = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Force Refresh All Data', 
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will:',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('• Clear all cached songs', style: GoogleFonts.inter()),
            Text('• Download fresh content from server', style: GoogleFonts.inter()),
            Text('• May take some time to complete', style: GoogleFonts.inter()),
            const SizedBox(height: 12),
            Text(
              'Continue?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Refresh All'),
          ),
        ],
      ),
    );

    if (shouldRefresh != true) return;

    setState(() => _isRefreshing = true);

    try {
      final syncService = ref.read(incrementalSyncServiceProvider);
      final result = await syncService.forceCompleteRefresh();

      if (mounted) {
        ref.invalidate(songsSearchResultsProvider);
        ref.invalidate(appSettingsProvider);
        ref.invalidate(todayScheduleTextProvider);

        final message = result.message ?? 'Force refresh completed';
        _showSnackbar(message, isError: !result.success);
        _debugLog('Force refresh completed: $message');
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Force refresh failed: $e');
        _debugLog('Force refresh error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _showCacheStatus() async {
    try {
      final syncService = ref.read(incrementalSyncServiceProvider);
      final status = await syncService.getCacheStatus();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cache Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Songs: ${status['totalSongs']}', 
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                      if (status['lastUpdated'] != null)
                        Text('Last Updated: ${DateTime.parse(status['lastUpdated']).toString().substring(0, 16)}',
                            style: GoogleFonts.inter(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...((status['languages'] as Map<String, dynamic>?) ?? {}).entries.map((entry) {
                  final lang = entry.key;
                  final data = entry.value as Map<String, dynamic>;
                  final needsSync = data['needsSync'] ?? false;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: needsSync 
                          ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: needsSync 
                            ? Theme.of(context).colorScheme.error.withOpacity(0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(lang, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (needsSync)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'SYNC NEEDED',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Songs: ${data['songCount']}', style: GoogleFonts.inter(fontSize: 12)),
                        Text('Batch: ${data['currentBatch']}', style: GoogleFonts.inter(fontSize: 12)),
                        if (data['lastSyncTime'] != null)
                          Text('Last Sync: ${DateTime.parse(data['lastSyncTime']).toString().substring(0, 16)}', 
                              style: GoogleFonts.inter(fontSize: 12)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if ((status['languages'] as Map<String, dynamic>?)?.values.any((data) => data['needsSync'] == true) ?? false)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleRefresh();
                },
                child: const Text('Sync Now'),
              ),
          ],
        ),
      );
    } catch (e) {
      _showSnackbar('Failed to get cache status: $e');
    }
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
        if (!_isSearching) ...[
          PopupMenuButton<String>(
            icon: Icon(
              _isRefreshing ? Icons.sync : Icons.more_vert,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
            enabled: !_isRefreshing && !_showInitialLoading,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                enabled: !_isRefreshing,
                child: Row(
                  children: [
                    Icon(_isRefreshing ? Icons.sync : Icons.refresh),
                    const SizedBox(width: 8),
                    Text(_isRefreshing ? 'Refreshing...' : 'Refresh Songs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'force_refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Force Refresh All'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'cache_status',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('Cache Status'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  if (!_isRefreshing) _handleRefresh();
                  break;
                case 'force_refresh':
                  _handleForceRefresh();
                  break;
                case 'cache_status':
                  _showCacheStatus();
                  break;
              }
            },
          ),
        ],
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close : Icons.search,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
          onPressed: () {
            _debugLog("Search button pressed");
            _toggleSearch();
          },
          tooltip: _isSearching ? 'Close search' : 'Search songs',
        ),
      ],
    );
  }

  Widget _buildDefaultContent() {
    if (_showInitialLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading songs from server...',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a moment on first launch',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _handleRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            _buildTodaysGodsWordsSection(),
            const SizedBox(height: 32),
            _buildNavigationList(),
            if (_isRefreshing) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Fetching latest songs from server...',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError 
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        duration: Duration(seconds: isError ? 4 : 3),
        action: isError ? SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: _handleRefresh,
        ) : null,
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
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
              ),
            ),
            _buildBackgroundShapes(),
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
                  .withOpacity(0.7),
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
          hintText: 'Search songs...',
          hintStyle: GoogleFonts.inter(
            color: (isDark ? Colors.white : const Color(0xFF1F2937))
                .withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: (isDark ? Colors.white : const Color(0xFF1F2937))
                .withOpacity(0.6),
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937))
                        .withOpacity(0.6),
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
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
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
          fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (value) {
          ref.read(homeSearchQueryProvider.notifier).state = value;
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchResultsAsync = ref.watch(songsSearchResultsProvider);
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
                        .withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start typing to search songs',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : const Color(0xFF1F2937))
                          .withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search across ${_isInitialized ? 'cached' : 'loading'} songs from all languages',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: (isDark ? Colors.white : const Color(0xFF1F2937))
                          .withOpacity(0.5),
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
                        .withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No songs found',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : const Color(0xFF1F2937))
                          .withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try different keywords or pull to refresh',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: (isDark ? Colors.white : const Color(0xFF1F2937))
                          .withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _handleRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Songs'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final song = results[index];
              return _buildSongSearchResultItem(song, index);
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
                'Searching cached songs...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: (isDark ? Colors.white : const Color(0xFF1F2937))
                      .withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Search error',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.colorScheme.error.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(songsSearchResultsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongSearchResultItem(Song song, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final query = _searchController.text.toLowerCase();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/song/${song.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: _buildHighlightedText(song.songName, query, isDark),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              song.language,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RichText(
                  text: _buildHighlightedText(
                    song.lyrics.length > 100 
                        ? '${song.lyrics.substring(0, 100)}...'
                        : song.lyrics,
                    query,
                    isDark,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _buildHighlightedText(String text, String query, bool isDark) {
    if (query.isEmpty) {
      return TextSpan(
        text: text,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: (isDark ? Colors.white : const Color(0xFF1F2937))
              .withOpacity(0.7),
        ),
      );
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    
    int start = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index >= 0) {
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: (isDark ? Colors.white : const Color(0xFF1F2937))
                .withOpacity(0.7),
          ),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          color: Theme.of(context).colorScheme.primary,
        ),
      ));

      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: (isDark ? Colors.white : const Color(0xFF1F2937))
              .withOpacity(0.7),
        ),
      ));
    }

    return TextSpan(children: spans);
  }

  Widget _buildTodaysGodsWordsSection() {
    final scheduleTextAsync = ref.watch(todayScheduleTextProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_stories,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Today's God's Words",
                  textAlign: TextAlign.left,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          scheduleTextAsync.when(
            data: (scheduleText) {
              if (scheduleText == null || scheduleText.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: (isDark ? Colors.white : const Color(0xFF1F2937))
                            .withOpacity(0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "No God's words scheduled for today.",
                          textAlign: TextAlign.left,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: (isDark ? Colors.white : const Color(0xFF1F2937))
                                .withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return GestureDetector(
                onTap: () => _showFullScreenGodsWordsDialog(scheduleText),
                child: Column(
                  children: [
                    Text(
                      scheduleText,
                      textAlign: TextAlign.left,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: (isDark ? Colors.white : const Color(0xFF1F2937))
                            .withOpacity(0.9),
                        height: 1.5,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tap to expand',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading today\'s message...',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            error: (e, s) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Failed to load schedule',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.colorScheme.error,
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

  Widget _buildNavigationList() {
    final appSettingsAsync = ref.watch(appSettingsProvider);

    return appSettingsAsync.when(
      data: (settings) {
        final buttons = <Map<String, dynamic>>[];

        buttons.add({
          'title': 'Bible',
          'icon': Icons.menu_book_outlined,
          'onTap': () => context.push('/bible_languages'),
          'enabled': true,
          'description': 'Read Bible verses in multiple languages',
        });

        buttons.add({
          'title': 'Songs',
          'icon': Icons.music_note_outlined,
          'onTap': () => context.push('/song_languages'),
          'enabled': true,
          'description': 'Browse worship songs by language',
        });

        final isDonateUsEnabled = settings['isDonateUsEnabled'] ?? false;
        final donateUsText = settings['donateUsText'] ?? '';
        final donateUsQrCodeUrl = settings['donateUsQrCodeUrl'] ?? '';

        if (isDonateUsEnabled &&
            (donateUsText.isNotEmpty || donateUsQrCodeUrl.isNotEmpty)) {
          buttons.add({
            'title': 'Donate Us',
            'icon': Icons.favorite,
            'onTap': () => _showDonateUsDialog(settings),
            'enabled': true,
            'description': 'Support our ministry',
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
            'icon': Icons.share,
            'onTap': () => _showSocialOptions(settings),
            'enabled': true,
            'description': 'Connect with us on social media',
          });
        }
        
        buttons.add({
          'title': 'About',
          'icon': Icons.info_outline,
          'onTap': () => _showAboutDialog(settings),
          'enabled': true,
          'description': 'Learn more about our app',
        });

        return Column(
          children: buttons
              .where((button) => button['enabled'] as bool)
              .map((button) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: _buildNavButton(
                      title: button['title'] as String,
                      icon: button['icon'] as IconData? ?? Icons.circle,
                      onTap: button['onTap'] as VoidCallback,
                      description: button['description'] as String?,
                    ),
                  ))
              .toList(),
        );
      },
      loading: () => Column(
        children: [
          _buildNavButton(
            title: 'Bible', 
            icon: Icons.menu_book_outlined,
            onTap: () => context.push('/bible_languages'),
            description: 'Read Bible verses in multiple languages',
          ),
          const SizedBox(height: 12),
          _buildNavButton(
            title: 'Songs', 
            icon: Icons.music_note_outlined,
            onTap: () => context.push('/song_languages'),
            description: 'Browse worship songs by language',
          ),
          const SizedBox(height: 12),
          _buildNavButton(
            title: 'Social', 
            icon: Icons.share,
            onTap: () => _showSocialOptions({}),
            description: 'Connect with us',
          ),
          const SizedBox(height: 12),
          _buildNavButton(
            title: 'About', 
            icon: Icons.info_outline,
            onTap: () => _showAboutDialog({}),
            description: 'Learn more about our app',
          ),
        ],
      ),
      error: (err, stack) => Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load navigation',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(appSettingsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required String title, 
    required IconData icon, 
    required VoidCallback onTap,
    String? description,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: (isDark ? Colors.white : const Color(0xFF1F2937))
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: (isDark ? Colors.white : const Color(0xFF1F2937))
                      .withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Donate Us',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
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
                      
                      if (qrCodeUrl != null && qrCodeUrl.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.2),
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
                                    color: theme.colorScheme.errorContainer.withOpacity(0.3),
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
                                        'Failed to load QR Code',
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
                        Container(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No donation information available',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
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

  void _showFullScreenGodsWordsDialog(String scheduleText) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.9),
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
                        return Icon(
                          Icons.church,
                          size: 200,
                          color: Colors.white.withOpacity(0.2),
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
                                color: Colors.white.withOpacity(0.2),
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
                                color: Colors.white.withOpacity(0.2),
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
                                .withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
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
                                      .withOpacity(0.9),
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
                                      .withOpacity(0.9),
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
                theme.colorScheme.primary.withOpacity(0.1),
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
                      theme.colorScheme.primary.withOpacity(0.8),
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
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                                Icon(Icons.church, size: 40, color: theme.colorScheme.primary),
                          ),
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
                        color: Colors.white.withOpacity(0.9),
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
                              'Offline access with automatic sync',
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
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
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
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareApp() async {
    try {
      await Share.share(
        'Check out Dayasagar Praise & Worship app! 🎵✨\n\n'
        'Discover beautiful worship songs in multiple languages including Hindi, English, Odia, and Sardari.\n\n'
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
      final Uri whatsappUrl = Uri.parse(phoneNumber);


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
}
