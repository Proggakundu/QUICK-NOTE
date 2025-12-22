 ************************** Quick Notes App ***************************

A feature-rich mobile note-taking application built with Flutter and Firebase.

---

## App Idea

A cross-platform note-taking app that allows users to:
- Create, edit, and delete notes with rich text
- Attach images from gallery
- Tag notes with GPS location
- Sync notes across devices via Firebase
- Work offline with local storage
- Switch between light and dark themes
- Use guest mode for quick access without account

---

## Device APIs Used

### Photos
- **`image_picker`**: select from gallery
- **Usage**: Attach images to notes
- **Platforms**: iOS, Android, Web

### Location Services
- **`geolocator`**: GPS location tracking
- **Usage**: Auto-tag notes with current location coordinates
- **Permissions**: Location when-in-use
- **Platforms**: iOS, Android

### Local Storage
- **`hive`**: NoSQL local database
- **Usage**: Offline note storage, user-specific data isolation
- **Features**: Fast, lightweight, type-safe

### Notifications (Web)
- **`dart:html` Notification API**: Browser notifications
- **Usage**: Auto-save confirmations, sync status alerts
- **Platforms**: Web only

---

## Offline Strategy

### Local-First Architecture
1. **Primary Storage**: Hive (local NoSQL database)
   - All notes saved locally first
   - User-specific boxes (`notes_{userId}`)
   - Guest mode support with separate storage


2. **Guest Mode**:
   - Fully functional offline
   - Data persists in `notes_guest` box
   - Can convert to registered user later
   - Local data preserved during conversion

3. **Auto-Save**:
   - Saves to local storage every 5 seconds
   - No internet required
   - Prevents data loss

---

## Cloud Function Purpose

### Backend Sync Service
**Endpoint**: `syncNotes` (Dart/Functions Framework)

**Purpose**:
- Sync local notes to PostgreSQL database
- Enable cross-device synchronization
- Backup notes in cloud storage
- Support collaborative features (future)

**Features**:
- User authentication via `x-user-id` header
- Upsert operations (insert or update)
- CORS support for web clients
- Error handling and logging


**Deployment**: Google Cloud Run or Firebase Functions

---
**Toggle in App**: Profile screen → Settings

---
### Firebase Authentication

**Test Account 1**:
- Email: `test11@gmail.com`
- Password: `111111`

### Guest Mode
- No credentials required
- Click "Continue as Guest" on login screen
- Data stored locally only

### Firebase Project
- Project ID: `progga-k-fall-25-final-945bd`
- Region: `us-central1`

---

### Setup
**Configure Firebase**:
   - Download `GoogleService-Info.plist` from Firebase Console
   - Place in `ios/Runner/` directory
   - Update `lib/firebase_options.dart` with your iOS config:
     ```dart
     static const FirebaseOptions ios = FirebaseOptions(
       apiKey: 'YOUR_IOS_API_KEY',
       appId: 'YOUR_IOS_APP_ID',
       messagingSenderId: '459352717528',
       projectId: 'progga-k-fall-25-final-945bd',
       storageBucket: 'progga-k-fall-25-final-945bd.firebasestorage.app',
       iosBundleId: 'com.yourcompany.quicknotesapp',
     );
     ```


## ✨ Features

- ✅ User authentication (Email/Password)
- ✅ Guest mode (no account required)
- ✅ Create/Edit/Delete notes
- ✅ Rich text editing (lists, tables)
- ✅ GPS location tagging
- ✅ Auto-save (every 5 seconds)
- ✅ Offline-first architecture
- ✅ Cloud sync (optional)
- ✅ Dark mode
- ✅ Feature flags
- ✅ User-specific data isolation
- ✅ Cross-platform (iOS, Web)

---


## 👤 Author

**Progga Kundu**
- GitLab: [@progga_kundu] [progga_k_fall_25_final]
---