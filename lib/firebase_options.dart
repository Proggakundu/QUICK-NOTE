import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  // Web configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBIOn2osArsok0HhOXEozzQTx-AGoRT5Q0',
    appId: '1:459352717528:web:4dc3758fe9e3be15d83fad',
    messagingSenderId: '459352717528',
    projectId: 'progga-k-fall-25-final-945bd',
    authDomain: 'progga-k-fall-25-final-945bd.firebaseapp.com',
    storageBucket: 'progga-k-fall-25-final-945bd.firebasestorage.app',
    measurementId: 'G-K49CK3QW5X',
  );
// iOS configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY_FROM_PLIST',
    appId: 'YOUR_IOS_APP_ID_FROM_PLIST',
    messagingSenderId: '459352717528',
    projectId: 'progga-k-fall-25-final-945bd',
    storageBucket: 'progga-k-fall-25-final-945bd.firebasestorage.app',
    iosBundleId: 'com.yourcompany.quicknotesapp',
  );

  // Android configuration (for future use)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: '459352717528',
    projectId: 'progga-k-fall-25-final-945bd',
    storageBucket: 'progga-k-fall-25-final-945bd.firebasestorage.app',
  );
}