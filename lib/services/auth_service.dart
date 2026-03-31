import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Universal Google Sign-In (Web + Android)
  static Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // 🌐 WEB LOGIN
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();

        final userCredential =
            await _auth.signInWithPopup(googleProvider);

        return userCredential.user;
      } else {
        // 📱 MOBILE LOGIN (Android/iOS)
        final GoogleSignInAccount? googleUser =
            await GoogleSignIn().signIn();

        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential =
            await _auth.signInWithCredential(credential);

        return userCredential.user;
      }
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  // ✅ Sign out (works for both)
  Future<void> signOut() async {
    await _auth.signOut();

    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
  }
}