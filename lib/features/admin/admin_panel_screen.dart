import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/cloudinary_service.dart'; 
import '../../models/song_models.dart';
import '../../models/schedule_model.dart';
import 'admin_provider.dart';
import '../../services/firestore_service.dart';
import '../../auth/auth_service.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTime _selectedScheduleDate = DateTime.now();
  final TextEditingController _scheduleTextController = TextEditingController();

  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _aboutUsController = TextEditingController();
  final TextEditingController _donateUsTextController = TextEditingController();
  String? _donateUsQrCodeUrl;
  bool _isUploadingQr = false;
  bool _isDonateUsEnabled = false; 
  bool _isYoutubeEnabled = true;
  bool _isInstagramEnabled = true;
  bool _isWhatsappEnabled = true;
  bool _isShareEnabled = true;
  bool _isRateUsEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAppSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scheduleTextController.dispose();
    _youtubeController.dispose();
    _instagramController.dispose();
    _whatsappController.dispose();
    _aboutUsController.dispose();
    _donateUsTextController.dispose();
    super.dispose();
  }

  Future<void> _loadAppSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('main')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _youtubeController.text = data['youtubeUrl'] ?? '';
            _instagramController.text = data['instagramUrl'] ?? '';
            _whatsappController.text = data['whatsappNumber'] ?? '';
            _aboutUsController.text = data['aboutUs'] ?? '';
            _isYoutubeEnabled = data['isYoutubeEnabled'] ?? true;
            _isInstagramEnabled = data['isInstagramEnabled'] ?? true;
            _isWhatsappEnabled = data['isWhatsappEnabled'] ?? true;
            _isShareEnabled = data['isShareEnabled'] ?? true;
            _isRateUsEnabled = data['isRateUsEnabled'] ?? true;
            _donateUsTextController.text = data['donateUsText'] ?? '';
            _donateUsQrCodeUrl = data['donateUsQrCodeUrl'];
            _isDonateUsEnabled = data['isDonateUsEnabled'] ?? false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to load settings: $e');
      }
    }
  }

  Future<void> _saveAppSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('main')
          .set({
        'youtubeUrl': _youtubeController.text.trim(),
        'instagramUrl': _instagramController.text.trim(),
        'whatsappNumber': _whatsappController.text.trim(),
        'aboutUs': _aboutUsController.text.trim(),
        'isYoutubeEnabled': _isYoutubeEnabled,
        'isInstagramEnabled': _isInstagramEnabled,
        'isWhatsappEnabled': _isWhatsappEnabled,
        'isShareEnabled': _isShareEnabled,
        'isRateUsEnabled': _isRateUsEnabled,
        'donateUsText': _donateUsTextController.text.trim(),
        'donateUsQrCodeUrl': _donateUsQrCodeUrl,
        'isDonateUsEnabled': _isDonateUsEnabled,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackbar('Settings saved successfully!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to save settings: $e');
      }
    }
  }

  Future<void> _uploadQrCode() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingQr = true);

      final fileName = 'qr_code_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File imageFile = File(image.path);
      
      final String? downloadUrl = await CloudinaryService.uploadImageUnsigned(imageFile, fileName);
      
      if (downloadUrl != null) {
        if (mounted) {
          setState(() {
            _donateUsQrCodeUrl = downloadUrl;
          });
          _showSnackbar('QR Code uploaded successfully!', isError: false);
        }
      } else {
        throw Exception('Upload returned null URL');
      }

    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to upload QR Code: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingQr = false);
      }
    }
  }

  void _saveSchedule() async {
    if (_scheduleTextController.text.trim().isEmpty) {
      _showSnackbar('Please enter schedule content');
      return;
    }

    final schedule = Schedule(
      id: _formatDate(_selectedScheduleDate),
      scheduleDate: Timestamp.fromDate(_selectedScheduleDate),
      scheduleText: _scheduleTextController.text.trim(),
      songIds: [],
      bibleIds: [],
    );

    try {
      await ref.read(firestoreServiceProvider).saveSchedule(schedule);

      if (!mounted) return;

      setState(() {
        _scheduleTextController.clear();
      });
      _showSnackbar('Schedule Saved Successfully!', isError: false);
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to save schedule: $e');
      }
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          isError ? Theme.of(context).colorScheme.error : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Text(
            'Admin Panel',
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
            onPressed: () => context.go('/'),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.logout,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
              onPressed: _showLogoutConfirmation,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48.0),
            child: Container(
              color: theme.colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
                tabAlignment: TabAlignment.fill,
                tabs: const [
                  Tab(icon: Icon(Icons.library_music, size: 20), text: 'Songs'),
                  Tab(icon: Icon(Icons.schedule, size: 20), text: 'Schedule'),
                  Tab(icon: Icon(Icons.settings, size: 20), text: 'Settings'),
                ],
              ),
            ),
          ),
        ),
        body: Container(
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
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSongsTab(),
              _buildScheduleTab(),
              _buildSettingsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonateUsSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Donate Us',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
                Switch(
                  value: _isDonateUsEnabled,
                  onChanged: (value) => setState(() => _isDonateUsEnabled = value),
                  activeColor: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isDonateUsEnabled) ...[
              TextField(
                controller: _donateUsTextController,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
                decoration: InputDecoration(
                  labelText: 'Donation Message',
                  hintText: 'Enter message to display on Home Screen...',
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
                  prefixIcon: Icon(
                    Icons.message,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                  ),
                  labelStyle: GoogleFonts.inter(
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                  ),
                  hintStyle: GoogleFonts.inter(
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'QR Code for Donations:',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _donateUsQrCodeUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _donateUsQrCodeUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: theme.colorScheme.primary,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error,
                                          size: 48,
                                          color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Failed to load QR Code',
                                          style: GoogleFonts.inter(
                                            color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code,
                                    size: 48,
                                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No QR Code Uploaded',
                                    style: GoogleFonts.inter(
                                      color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isUploadingQr ? null : _uploadQrCode,
                        icon: _isUploadingQr
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(_isUploadingQr ? 'Uploading...' : 'Upload QR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isUploadingQr 
                              ? Colors.grey 
                              : theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      if (_donateUsQrCodeUrl != null && !_isUploadingQr) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _donateUsQrCodeUrl = null);
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text('Remove', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Note: This QR code and message will be displayed on the Home Screen for donations.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enable donate feature to configure donation settings',
                        style: GoogleFonts.inter(
                          color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDonateUsSection(),
            
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Social Media Links',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildSocialLinkSetting(
                      'YouTube Channel',
                      _youtubeController,
                      _isYoutubeEnabled,
                      (value) => setState(() => _isYoutubeEnabled = value),
                      'https://youtube.com/@yourchannel',
                      Icons.play_circle_fill,
                      Colors.red,
                    ),

                    const SizedBox(height: 20),

                    _buildSocialLinkSetting(
                      'Instagram Profile',
                      _instagramController,
                      _isInstagramEnabled,
                      (value) => setState(() => _isInstagramEnabled = value),
                      'https://instagram.com/yourprofile',
                      Icons.camera_alt,
                      Colors.purple,
                    ),

                    const SizedBox(height: 20),

                    _buildSocialLinkSetting(
                      'WhatsApp Number',
                      _whatsappController,
                      _isWhatsappEnabled,
                      (value) => setState(() => _isWhatsappEnabled = value),
                      '+1234567890',
                      Icons.message,
                      Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Features',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildFeatureToggle(
                      'Share App Feature',
                      _isShareEnabled,
                      (value) => setState(() => _isShareEnabled = value),
                      Icons.share,
                      Colors.blue,
                    ),

                    const SizedBox(height: 16),

                    _buildFeatureToggle(
                      'Rate Us Feature',
                      _isRateUsEnabled,
                      (value) => setState(() => _isRateUsEnabled = value),
                      Icons.star,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About Us Content',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _aboutUsController,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                      decoration: InputDecoration(
                        labelText: 'About Us Text',
                        hintText: 'Enter about us content...',
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
                        labelStyle: GoogleFonts.inter(
                          color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                        ),
                        hintStyle: GoogleFonts.inter(
                          color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
                        ),
                      ),
                      maxLines: 6,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAppSettings,
                icon: const Icon(Icons.save),
                label: Text(
                  'Save All Settings',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinkSetting(
    String title,
    TextEditingController controller,
    bool isEnabled,
    ValueChanged<bool> onToggle,
    String hintText,
    IconData icon,
    Color iconColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ),
            Switch(
              value: isEnabled,
              onChanged: onToggle,
              activeColor: theme.colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          enabled: isEnabled,
          style: GoogleFonts.inter(
            color: isEnabled 
                ? (isDark ? Colors.white : const Color(0xFF1F2937))
                : (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
          ),
          decoration: InputDecoration(
            labelText: '$title URL',
            hintText: hintText,
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              ),
            ),
            filled: true,
            fillColor: isEnabled 
                ? (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)
                : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            labelStyle: GoogleFonts.inter(
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(
                alpha: isEnabled ? 0.7 : 0.4,
              ),
            ),
            hintStyle: GoogleFonts.inter(
              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(
                alpha: isEnabled ? 0.5 : 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureToggle(
    String title,
    bool isEnabled,
    ValueChanged<bool> onToggle,
    IconData icon,
    Color iconColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ),
        Switch(
          value: isEnabled,
          onChanged: onToggle,
          activeColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  // UPDATED: Songs Tab with FloatingActionButton
  Widget _buildSongsTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final songsAsync = ref.watch(adminSongsProvider);
    final searchQuery = ref.watch(adminSongSearchProvider);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: TextField(
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
                decoration: InputDecoration(
                  hintText: 'Search all songs...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
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
                  hintStyle: GoogleFonts.inter(
                    color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                  ),
                ),
                onChanged: (value) =>
                    ref.read(adminSongSearchProvider.notifier).state = value,
              ),
            ),
            Expanded(
              child: songsAsync.when(
                data: (songs) {
                  final filteredSongs = songs.where((song) {
                    final query = searchQuery.toLowerCase();
                    return song.songName.toLowerCase().contains(query) ||
                        song.lyrics.toLowerCase().contains(query);
                  }).toList();
                  
                  if (filteredSongs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_off,
                            size: 64,
                            color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No songs found',
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
                  
                  return ListView.builder(
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            song.songName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                          subtitle: Text(
                            song.language,
                            style: GoogleFonts.inter(
                              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                            ),
                          ),
                          trailing: _buildItemPopupMenu('song', song),
                        ),
                      );
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: theme.colorScheme.primary),
                ),
                error: (e, s) => Center(
                  child: Text(
                    'Error: $e',
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSongDialog(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildScheduleTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allSchedules = ref.watch(adminSchedulesProvider);
    final searchQuery = ref.watch(adminScheduleSearchProvider);

    return Container(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedScheduleDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030));
                          if (date != null) {
                            setState(() => _selectedScheduleDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Schedule Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                              ),
                            ),
                            filled: true,
                            fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                            labelStyle: GoogleFonts.inter(
                              color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                            ),
                          ),
                          child: Text(
                            _formatDate(_selectedScheduleDate),
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _scheduleTextController.text.trim().isEmpty
                          ? null
                          : _saveSchedule,
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _scheduleTextController,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Schedule Content',
                    hintText: 'Enter schedule details...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
                    labelStyle: GoogleFonts.inter(
                      color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                    ),
                    hintStyle: GoogleFonts.inter(
                      color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
                    ),
                  ),
                  maxLines: 5,
                  onChanged: (value) => setState(() {}),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
              decoration: InputDecoration(
                hintText: 'Search schedules by date...',
                prefixIcon: Icon(
                  Icons.search,
                  color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
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
                hintStyle: GoogleFonts.inter(
                  color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.6),
                ),
              ),
              onChanged: (value) =>
                  ref.read(adminScheduleSearchProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: allSchedules.when(
              data: (schedules) {
                final filteredSchedules = schedules
                    .where((s) => _formatDate(s.scheduleDate.toDate())
                        .contains(searchQuery))
                    .toList();
                    
                if (filteredSchedules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 64,
                          color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No schedules found',
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
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSchedules.length,
                  itemBuilder: (context, index) {
                    final schedule = filteredSchedules[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          _formatDate(schedule.scheduleDate.toDate()),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                        subtitle: Text(
                          schedule.scheduleText?.isNotEmpty == true 
                              ? schedule.scheduleText!.length > 50
                                  ? '${schedule.scheduleText!.substring(0, 50)}...'
                                  : schedule.scheduleText!
                              : 'No content',
                          style: GoogleFonts.inter(
                            color: (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: 0.7),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _loadScheduleForEditing(schedule),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirmationForSchedule(schedule),
                            ),
                          ],
                        ),
                        children: [
                          if (schedule.scheduleText?.isNotEmpty == true)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                schedule.scheduleText!,
                                style: GoogleFonts.inter(
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: theme.colorScheme.primary),
              ),
              error: (e, s) => Center(
                child: Text(
                  'Error: $e',
                  style: GoogleFonts.inter(color: theme.colorScheme.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSongDialog({Song? song}) {
    showDialog(
      context: context,
      builder: (dContext) => _SongFormDialog(song: song),
    );
  }

  PopupMenuButton<String> _buildItemPopupMenu(String type, dynamic item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: isDark ? Colors.white : const Color(0xFF1F2937),
      ),
      color: theme.colorScheme.surface,
      onSelected: (value) {
        if (value == 'edit') {
          if (type == 'song') _showSongDialog(song: item as Song);
        } else if (value == 'delete') {
          _showDeleteConfirmation(type, item);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Edit',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: GoogleFonts.inter(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(String type, dynamic item) {
    showDialog(
      context: context,
      builder: (dContext) => AlertDialog(
        title: Text('Delete $type?'),
        content: Text(
            'Are you sure you want to delete "${item is Song ? item.songName : 'this item'}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dContext).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final firestore = ref.read(firestoreServiceProvider);
                if (type == 'song') await firestore.deleteSong(item.id);
                if (!context.mounted) return;
                Navigator.of(dContext).pop();
                _showSnackbar('$type deleted successfully!', isError: false);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(dContext).pop();
                _showSnackbar('Failed to delete $type: $e');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _loadScheduleForEditing(Schedule schedule) {
    setState(() {
      _selectedScheduleDate = schedule.scheduleDate.toDate();
      _scheduleTextController.text = schedule.scheduleText ?? '';
    });
    _showSnackbar(
        'Loaded schedule for ${_formatDate(schedule.scheduleDate.toDate())}.',
        isError: false);
  }

  void _showDeleteConfirmationForSchedule(Schedule schedule) {
    showDialog(
      context: context,
      builder: (dContext) => AlertDialog(
        title: const Text('Delete Schedule?'),
        content: Text(
            'Are you sure you want to delete the schedule for ${_formatDate(schedule.scheduleDate.toDate())}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dContext).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref
                    .read(firestoreServiceProvider)
                    .deleteSchedule(schedule.id);
                if (!context.mounted) return;
                Navigator.of(dContext).pop();
                _showSnackbar('Schedule deleted successfully!', isError: false);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(dContext).pop();
                _showSnackbar('Failed to delete schedule: $e');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      await ref.read(authServiceProvider).signOut();
      if (mounted) context.go('/');
    }
  }
}

// UPDATED: Song Form Dialog with supported languages
class _SongFormDialog extends ConsumerStatefulWidget {
  final Song? song;
  const _SongFormDialog({this.song});

  @override
  ConsumerState<_SongFormDialog> createState() => _SongFormDialogState();
}

class _SongFormDialogState extends ConsumerState<_SongFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _lyricsController;
  String? _selectedLanguage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song?.songName ?? '');
    _lyricsController = TextEditingController(text: widget.song?.lyrics ?? '');
    _selectedLanguage = widget.song?.language ?? 'Hindi';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _saveSong() async {
    if (!_formKey.currentState!.validate() || _selectedLanguage == null) return;

    setState(() => _isLoading = true);

    final newSong = Song(
      id: widget.song?.id ?? '',
      songName: _titleController.text,
      lyrics: _lyricsController.text,
      language: _selectedLanguage!,
      createdAt: widget.song?.createdAt ?? Timestamp.now(),
    );

    try {
      final firestore = ref.read(firestoreServiceProvider);
      if (widget.song != null) {
        await firestore.updateSong(newSong.id, newSong);
      } else {
        await firestore.addSong(newSong);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Song saved successfully!'),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save song: $e'),
          backgroundColor: Colors.red));
    }
  }
  @override
  Widget build(BuildContext context) {
    const List<String> songLanguages = [
      'Hindi',
      'English', 
      'Odia',
      'Sadri'
    ];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.song == null ? 'Add Song' : 'Edit Song',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Song Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lyricsController,
                decoration: InputDecoration(
                  labelText: 'Lyrics',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 5,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                onChanged: (val) => setState(() => _selectedLanguage = val),
                items: songLanguages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                decoration: InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSong,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
