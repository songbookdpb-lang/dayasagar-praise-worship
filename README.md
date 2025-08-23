📖 Dayasagar Praise & Worship
A comprehensive offline-first Flutter application for spiritual worship, featuring multi-language Bible access, song management, and administrative capabilities.

[
[
🌟 Overview
Dayasagar Praise & Worship is a feature-rich spiritual companion app that provides offline access to Bible content, worship songs, and daily God's words. Built with Flutter and powered by Firebase, it offers seamless offline functionality with intelligent data synchronization.

✨ Key Features
📚 Multi-Language Bible Support
Languages: Hindi, English, Odia, Sardari

Offline Access: Complete Bible content cached locally

Search: Fast text search across all languages

Bookmarks: Save and organize favorite verses

🎵 Song Management System
Multi-Language Songs: Hindi, English, Odia, Sardari worship songs

Offline Playback: Songs cached for offline access

Search & Filter: Advanced search by title, lyrics, or language

Real-time Sync: Incremental updates from server

📅 Daily God's Words
Scheduled Content: Daily spiritual messages

Share Feature: Copy and share God's words

Full-Screen Reading: Immersive reading experience

Offline Storage: Access without internet connection

🛠️ Admin Dashboard
Content Management: Add, edit, delete songs and Bible content

Schedule Management: Set daily God's words

User Analytics: Track app usage and engagement

Social Media Integration: Manage links and contact information

🌐 Social Features
Share App: Built-in app sharing functionality

Social Links: YouTube, Instagram, WhatsApp integration

Rate App: Direct Google Play Store rating

Donation System: QR code-based donation support

🔄 Advanced Sync System
Incremental Sync: Only fetch changed content

Hive Caching: Persistent local storage

Background Updates: Silent content synchronization

Conflict Resolution: Smart merge strategies

🏗️ Technical Architecture
Tech Stack
text
Frontend:     Flutter 3.0+ (Dart)
State Mgmt:   Riverpod 2.0
Database:     Cloud Firestore + Hive (Local)
Storage:      Firebase Storage
Auth:         Firebase Authentication
Caching:      Hive + Incremental Sync Service
UI:           Material Design 3.0
Fonts:        Google Fonts (Inter)
Project Structure
text
lib/
├── features/
│   ├── bible/           # Bible reading functionality
│   ├── songs/           # Song management & playback
│   ├── home/           # Main dashboard
│   └── admin/          # Administrative features
├── services/
│   ├── incremental_sync_service.dart  # Smart sync logic
│   ├── persistent_cache_service.dart  # Hive operations
│   └── firestore_service.dart         # Firebase operations
├── models/
│   ├── song_models.dart      # Song data models
│   ├── bible_models.dart     # Bible content models
│   └── schedule_model.dart   # Daily schedule models
├── widgets/
│   └── shared/         # Reusable UI components
└── providers/          # Riverpod state management
🚀 Getting Started
Prerequisites
Flutter 3.0 or higher

Dart SDK 2.19+

Firebase project setup

Android Studio / VS Code

Installation
Clone the repository

bash
git clone https://github.com/your-username/dayasagar-praise-worship.git
cd dayasagar-praise-worship
Install dependencies

bash
flutter pub get
flutter pub run build_runner build
Firebase Setup

bash
# Add your Firebase configuration files
# android/app/google-services.json
# ios/Runner/GoogleService-Info.plist
Generate Hive Adapters

bash
flutter pub run build_runner build --delete-conflicting-outputs
Run the application

bash
flutter run
📱 Screenshots
Home Screen	Bible Reading	Songs Library	Admin Dashboard
Daily Words	Search Results	Social Features	Settings
🔧 Configuration
Firebase Collections Structure
javascript
// Firestore Collections
songs: {
  songId: {
    songName: "string",
    lyrics: "string", 
    language: "string",
    createdAt: "timestamp",
    updatedAt: "timestamp",
    isDeleted: "boolean"
  }
}

schedules: {
  "YYYY-MM-DD": {
    scheduleText: "string",
    createdAt: "timestamp"
  }
}

app_settings: {
  main: {
    aboutUs: "string",
    isYoutubeEnabled: "boolean",
    youtubeUrl: "string",
    isInstagramEnabled: "boolean", 
    instagramUrl: "string",
    isWhatsappEnabled: "boolean",
    whatsappNumber: "string",
    isDonateUsEnabled: "boolean",
    donateUsText: "string",
    donateUsQrCodeUrl: "string"
  }
}
Environment Variables
Create a .env file in the root directory:

text
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_APP_ID=your_app_id
🔄 Sync System Architecture
Incremental Sync Process
Timestamp Tracking: Store last sync timestamp locally

Differential Queries: Fetch only changed content since last sync

Conflict Resolution: Smart merge for concurrent updates

Background Sync: Periodic updates without user intervention

Offline First: App functions fully without internet

Hive Cache Strategy
dart
// Cache Structure
songsBox: Map<String, Song>           // Song content cache
bibleBooksBox: Map<String, BibleBook> // Bible content cache  
prefsBox: Map<String, dynamic>        // User preferences & sync timestamps
🎨 UI/UX Features
Material Design 3.0 with dynamic theming

Dark/Light Mode automatic switching

Responsive Design for tablets and phones

Smooth Animations using Flutter's animation framework

Accessibility Support with semantic labels

Offline Indicators showing sync status

📊 Admin Dashboard Features
Content Management
✅ Add/Edit/Delete Songs

✅ Schedule Daily God's Words

✅ Upload Bible Content

✅ Manage User Feedback

Analytics Dashboard
📈 User Engagement Metrics

📊 Content Usage Statistics

🔄 Sync Status Monitoring

💬 User Feedback Management

Settings Management
🔗 Social Media Links

💰 Donation Configuration

🎨 App Theme Settings

📱 Push Notification Setup

