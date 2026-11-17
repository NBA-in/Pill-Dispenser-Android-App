import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthHelper {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential?> signIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('popup_closed') || errorString.contains('canceled') || errorString.contains('cancelled')) {
        return null; // User cancelled the sign-in flow
      }
      throw Exception("Google Sign In Failed: $e");
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
