
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About', style: GoogleFonts.hind(fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/image/logo.png'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dayasagar Praise & Worship',
                    style: GoogleFonts.hind(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: GoogleFonts.hind(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'About This App',
              style: GoogleFonts.hind(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This app provides access to worship songs and Bible verses in multiple languages including Hindi, English, Odia, and Sadri. It helps the church community stay connected with daily spiritual content and worship materials.',
              style: GoogleFonts.hind(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Features',
              style: GoogleFonts.hind(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem('Daily God\'s Words'),
            _buildFeatureItem('Multilingual Songs'),
            _buildFeatureItem('Bible Verses'),
            _buildFeatureItem('Search Functionality'),
            _buildFeatureItem('Offline Access'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text(
            feature,
            style: GoogleFonts.hind(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
