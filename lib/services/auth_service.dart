import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  Stream<Map<String, dynamic>?> get verifiedUserStream => _auth.authStateChanges().asyncMap((user) async {
    if (user == null) return null;
    
    // Fetch the specific role from Firestore
    final role = await getUserRole(user.email ?? "");
    
    if (role != null) {
      return {
        'user': user,
        'role': role,
      };
    }
    return null;
  });

  Future<String?> getUserRole(String email) async {
    try {
      final doc = await _firestore.collection('admins').doc(email).get();
      if (doc.exists) {
        return doc.data()?['role'] ?? 'admin';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Helper for backward compatibility
  Future<bool> isAdmin(String email) async {
    final role = await getUserRole(email);
    return role != null;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
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
