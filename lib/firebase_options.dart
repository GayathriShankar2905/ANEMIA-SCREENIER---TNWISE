import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ───────── WEB CONFIG (IMPORTANT) ─────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyB7pruIesBkfWUw01bvnarTCXQOdN-4pRo",
    authDomain: "hemoscan-a-93b02.firebaseapp.com",
    projectId: "hemoscan-a-93b02",
    storageBucket: "hemoscan-a-93b02.firebasestorage.app",
    messagingSenderId: "831637528472",
    appId: "1:831637528472:web:a565a97ba47c9ba5c755ed",
    measurementId: "G-MZSMEXJXKV",
  );

  // ───────── ANDROID (placeholder for now) ─────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyB7pruIesBkfWUw01bvnarTCXQOdN-4pRo",
    appId: "1:831637528472:web:a565a97ba47c9ba5c755ed",
    messagingSenderId: "831637528472",
    projectId: "hemoscan-a-93b02",
    storageBucket: "hemoscan-a-93b02.firebasestorage.app",
  );

  // ───────── IOS (placeholder for now) ─────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyB7pruIesBkfWUw01bvnarTCXQOdN-4pRo",
    appId: "1:831637528472:web:a565a97ba47c9ba5c755ed",
    messagingSenderId: "831637528472",
    projectId: "hemoscan-a-93b02",
    storageBucket: "hemoscan-a-93b02.firebasestorage.app",
    iosBundleId: "com.example.anemiaApp",
  );

  // ───────── WINDOWS (using second web app config) ─────────
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: "AIzaSyB7pruIesBkfWUw01bvnarTCXQOdN-4pRo",
    authDomain: "hemoscan-a-93b02.firebaseapp.com",
    projectId: "hemoscan-a-93b02",
    storageBucket: "hemoscan-a-93b02.firebasestorage.app",
    messagingSenderId: "831637528472",
    appId: "1:831637528472:web:0c54bdaa1c7575ffc755ed",
    measurementId: "G-50YBCEHFKX",
  );
}