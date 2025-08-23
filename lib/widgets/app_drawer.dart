import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';

// ✅ ADDED: Missing appSettingsProvider
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

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  int _adminTapCount = 0;
  DateTime? _firstTap;
  bool _showAdminButton = false;

  void _handleAdminAccess() {
    final now = DateTime.now();

    if (_firstTap == null || now.difference(_firstTap!).inSeconds > 3) {
      _adminTapCount = 1;
      _firstTap = now;
    } else {
      _adminTapCount++;
    }

    if (_adminTapCount >= 5) {
      HapticFeedback.mediumImpact();
      _showAdminLogin();
      _adminTapCount = 0;
      _firstTap = null;
    }
  }

  void _handleLongPress() {
    HapticFeedback.selectionClick();
    setState(() {
      _showAdminButton = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Admin access enabled',
          style: GoogleFonts.hind(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showAdminButton = false;
        });
      }
    });
  }

  void _showAdminLogin() {
    setState(() {
      _showAdminButton = false;
    });

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Admin Access',
                  style: GoogleFonts.hind(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter admin credentials to continue.',
                style: GoogleFonts.hind(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/admin_login');
                  },
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text('Admin Login',
                      style: GoogleFonts.hind(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.grey[300] : Colors.grey,
              ),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Donate Us dialog
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
                  'Donate Us', // ✅ FIXED: Removed 'z' typo
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

  Widget _sectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.hind(
          fontSize: 12,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconBg,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBg ?? theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor ?? theme.colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.hind(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      trailing: Icon(Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _footerInfo() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.08)))),
      child: Column(
        children: [
          Text(
            'Dayasagar Praise & Worship', // ✅ FIXED: HTML entity
            style: GoogleFonts.hind(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Version 1.0.0',
            style: GoogleFonts.hind(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Social functions
  Future<void> _shareApp() async {
    try {
      await Share.share(
        'Check out Dayasagar Praise & Worship app! 🎵✨\n\n'
        'Discover beautiful worship songs and Bible verses in multiple languages including Hindi, English, Odia, and Sardari.\n\n'
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
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dayasagar Praise and Worship',
                      style: GoogleFonts.hind(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: GoogleFonts.hind(
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
                        style: GoogleFonts.hind(
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
                              style: GoogleFonts.hind(
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
                              style: GoogleFonts.hind(
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
                              style: GoogleFonts.hind(
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
                              style: GoogleFonts.hind(
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
                    style: GoogleFonts.hind(
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

  // Get theme-aware colors for social icons
  Color _getYouTubeColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? Colors.red.shade400
        : Colors.red.shade600;
  }

  Color _getInstagramColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? Colors.purple.shade400
        : Colors.purple.shade600;
  }

  Color _getWhatsAppColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? Colors.green.shade400
        : Colors.green.shade600;
  }

  Color _getShareColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? Colors.blue.shade400
        : Colors.blue.shade600;
  }

  Color _getRateColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? Colors.orange.shade400
        : Colors.orange.shade600;
  }

  // Get donate us color
  Color _getDonateColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? Colors.red.shade400
        : Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appSettingsAsync = ref.watch(appSettingsProvider);

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ]
                : [
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                  ],
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: DrawerHeader(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const Positioned(
                      top: -40,
                      right: -40,
                      child: Opacity(
                        opacity: 0.08,
                        child: Icon(Icons.music_note,
                            size: 140, color: Colors.white),
                      ),
                    ),
                    const Positioned(
                      bottom: -30,
                      left: -30,
                      child: Opacity(
                        opacity: 0.06,
                        child: Icon(Icons.menu_book,
                            size: 120, color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      alignment: Alignment.bottomLeft,
                      child: GestureDetector(
                        onTap: _handleAdminAccess,
                        onLongPress: _handleLongPress,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const CircleAvatar(
                              radius: 25,
                              backgroundImage:
                                  AssetImage('assets/images/logo.png'),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Dayasagar',
                                    style: GoogleFonts.hind(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Praise & Worship', // ✅ FIXED: HTML entity
                                    style: GoogleFonts.hind(
                                      color:
                                          Colors.white.withValues(alpha: 0.92),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: appSettingsAsync.when(
                data: (settings) => ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _sectionHeader('Navigation'),
                    _navTile(
                      icon: Icons.home_outlined,
                      title: 'Home',
                      onTap: () => context.go('/'),
                    ),
                    _navTile(
                      icon: Icons.music_note_outlined,
                      title: 'Songs',
                      onTap: () => context.push('/song_languages'),
                      iconBg:
                          theme.colorScheme.secondary.withValues(alpha: 0.12),
                    ),
                    _navTile(
                      icon: Icons.menu_book_outlined,
                      title: 'Bible',
                      onTap: () => context.push('/bible_languages'),
                      iconBg:
                          theme.colorScheme.tertiary.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 6),

                    // HIDDEN: Admin button only shows when secret method is triggered
                    if (_showAdminButton)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ElevatedButton.icon(
                          onPressed: _showAdminLogin,
                          icon: const Icon(Icons.admin_panel_settings),
                          label: Text('Admin Access',
                              style: GoogleFonts.hind(
                                  fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),

                    // Social & Community Section
                    _sectionHeader('Social & Community'), // ✅ FIXED: HTML entity

                    // FIXED: Donate Us - proper if statement syntax
                    if ((settings['isDonateUsEnabled'] ?? false) && 
                        ((settings['donateUsText'] ?? '').isNotEmpty || 
                         (settings['donateUsQrCodeUrl'] ?? '').isNotEmpty))
                      _navTile(
                        icon: Icons.favorite,
                        title: 'Donate Us',
                        onTap: () => _showDonateUsDialog(settings),
                        iconBg: _getDonateColor(theme).withValues(alpha: 0.12),
                        iconColor: _getDonateColor(theme),
                      ),

                    // Share App (always visible)
                    if (settings['isShareEnabled'] ?? true)
                      _navTile(
                        icon: Icons.share,
                        title: 'Share App',
                        onTap: _shareApp,
                        iconBg: _getShareColor(theme).withValues(alpha: 0.12),
                        iconColor: _getShareColor(theme),
                      ),

                    // YouTube
                    if (settings['isYoutubeEnabled'] ?? false)
                      _navTile(
                        icon: Icons.play_circle_fill,
                        title: 'YouTube Channel',
                        onTap: () => _openYouTube(settings['youtubeUrl'] ?? ''),
                        iconBg: _getYouTubeColor(theme).withValues(alpha: 0.12),
                        iconColor: _getYouTubeColor(theme),
                      ),

                    // Instagram
                    if (settings['isInstagramEnabled'] ?? false)
                      _navTile(
                        icon: Icons.camera_alt,
                        title: 'Instagram',
                        onTap: () =>
                            _openInstagram(settings['instagramUrl'] ?? ''),
                        iconBg:
                            _getInstagramColor(theme).withValues(alpha: 0.12),
                        iconColor: _getInstagramColor(theme),
                      ),

                    // WhatsApp
                    if (settings['isWhatsappEnabled'] ?? false)
                      _navTile(
                        icon: Icons.message,
                        title: 'WhatsApp',
                        onTap: () =>
                            _openWhatsApp(settings['whatsappNumber'] ?? ''),
                        iconBg:
                            _getWhatsAppColor(theme).withValues(alpha: 0.12),
                        iconColor: _getWhatsAppColor(theme),
                      ),

                    // Rate Us
                    if (settings['isRateUsEnabled'] ?? true)
                      _navTile(
                        icon: Icons.star,
                        title: 'Rate Us',
                        onTap: _rateApp,
                        iconBg: _getRateColor(theme).withValues(alpha: 0.12),
                        iconColor: _getRateColor(theme),
                      ),

                    // About Us (always visible)
                    _navTile(
                      icon: Icons.info_outline,
                      title: 'About Us',
                      onTap: () => _showAboutDialog(settings),
                      iconBg: theme.colorScheme.surface.withValues(alpha: 0.12),
                      iconColor: theme.colorScheme.onSurface,
                    ),

                    // HIDDEN: Account section only shows when user is authenticated
                    StreamBuilder<User?>(
                      stream: FirebaseAuth.instance.authStateChanges(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Column(
                            children: [
                              _sectionHeader('Account'),
                              _navTile(
                                icon: Icons.admin_panel_settings,
                                title: 'Admin Panel',
                                onTap: () => context.push('/admin'),
                                iconBg: Colors.orange.withValues(alpha: 0.15),
                                iconColor: Colors.orange,
                              ),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.logout,
                                      color: theme.colorScheme.error),
                                ),
                                title: Text(
                                  'Logout',
                                  style: GoogleFonts.hind(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                trailing: Icon(Icons.chevron_right,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4)),
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  await ref.read(authServiceProvider).signOut();
                                },
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
                loading: () => ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _sectionHeader('Navigation'),
                    _navTile(
                      icon: Icons.home_outlined,
                      title: 'Home',
                      onTap: () => context.go('/'),
                    ),
                    _navTile(
                      icon: Icons.music_note_outlined,
                      title: 'Songs',
                      onTap: () => context.push('/song_languages'),
                      iconBg:
                          theme.colorScheme.secondary.withValues(alpha: 0.12),
                    ),
                    _navTile(
                      icon: Icons.menu_book_outlined,
                      title: 'Bible',
                      onTap: () => context.push('/bible_languages'),
                      iconBg:
                          theme.colorScheme.tertiary.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
                error: (error, stack) => ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _sectionHeader('Navigation'),
                    _navTile(
                      icon: Icons.home_outlined,
                      title: 'Home',
                      onTap: () => context.go('/'),
                    ),
                    _navTile(
                      icon: Icons.music_note_outlined,
                      title: 'Songs',
                      onTap: () => context.push('/song_languages'),
                      iconBg:
                          theme.colorScheme.secondary.withValues(alpha: 0.12),
                    ),
                    _navTile(
                      icon: Icons.menu_book_outlined,
                      title: 'Bible',
                      onTap: () => context.push('/bible_languages'),
                      iconBg:
                          theme.colorScheme.tertiary.withValues(alpha: 0.12),
                    ),
                    _sectionHeader('Social & Community'), // ✅ FIXED: HTML entity
                    _navTile(
                      icon: Icons.share,
                      title: 'Share App',
                      onTap: _shareApp,
                      iconBg: _getShareColor(theme).withValues(alpha: 0.12),
                      iconColor: _getShareColor(theme),
                    ),
                    _navTile(
                      icon: Icons.info_outline,
                      title: 'About Us',
                      onTap: () => _showAboutDialog({}),
                      iconBg: theme.colorScheme.surface.withValues(alpha: 0.12),
                      iconColor: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _footerInfo(),
          ],
        ),
      ),
    );
  }
}
