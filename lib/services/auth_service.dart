import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  Stream<User?> get verifiedUserStream => _auth.authStateChanges().asyncMap((user) async {
    if (user == null) return null;
    // We check admin status here so the AuthWrapper knows for sure 
    // before it decides which screen to show.
    final admin = await isAdmin(user.email ?? "");
    return admin ? user : null;
  });

  Future<bool> isAdmin(String email) async {
    try {
      final doc = await _firestore.collection('admins').doc(email).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Disconnect to force account selection
      try { await _googleSignIn.disconnect(); } catch (_) {}
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    await _auth.signOut();
  }
}
