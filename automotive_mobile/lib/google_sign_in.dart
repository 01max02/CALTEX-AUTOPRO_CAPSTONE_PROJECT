import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Handles Google Sign-In authentication and user management
/// Mirrors the website's Google Sign-In flow for consistency
class GoogleSignInHelper {
  static final _googleSignIn = GoogleSignIn();
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  /// Sign in with Google and return user role
  /// Matches website flow: authenticate → lookup/create user → validate status → return role
  static Future<String?> signInWithGoogle() async {
    try {
      print('=== Starting Google Sign-In ===');
      
      // Step 1: Open Google Sign-In dialog
      print('Step 1: Opening Google Sign-In dialog...');
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('User cancelled Google Sign-In');
        return null;
      }
      print('Step 2: Google user signed in: ${googleUser.email}');

      // Step 2: Get Google credentials
      print('Step 3: Creating Google credential...');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 3: Authenticate with Firebase
      print('Step 4: Authenticating with Firebase...');
      final cred = await _auth.signInWithCredential(credential);
      final uid = cred.user!.uid;
      final email = cred.user!.email ?? '';
      final displayName = cred.user!.displayName ?? '';
      final photoUrl = cred.user!.photoURL ?? '';
      
      print('Step 5: Firebase authentication successful');
      print('  - UID: $uid');
      print('  - Email: $email');
      print('  - Display Name: $displayName');

      // Step 4: Get or create user in Firestore
      print('Step 6: Checking Firestore for user...');
      final userData = await _getOrCreateUser(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
      );

      print('Step 7: User data retrieved');
      print('  - Role: ${userData['role']}');
      print('  - Status: ${userData['status']}');

      // Step 5: Validate user status
      final status = (userData['status'] as String? ?? 'active').toLowerCase();
      if (status == 'inactive') {
        print('Step 8: Account is inactive - signing out');
        await _auth.signOut();
        throw Exception('Account is inactive');
      }

      // Step 6: Return role
      final role = userData['role'] as String? ?? 'customer';
      print('Step 9: Returning role: $role');
      return role;
      
    } catch (e) {
      print('=== Google Sign-In Error ===');
      print('Error: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Get existing user from Firestore
  /// Does NOT auto-register new users - only allows pre-registered users to sign in
  static Future<Map<String, dynamic>> _getOrCreateUser({
    required String uid,
    required String email,
    required String displayName,
    required String photoUrl,
  }) async {
    try {
      // Try to get user by UID first (new accounts)
      print('  - Checking by UID: $uid');
      final uidDoc = await _firestore.collection('users').doc(uid).get();

      if (uidDoc.exists) {
        print('  - User found by UID');
        return uidDoc.data() ?? {};
      }

      // Fallback: check by email (legacy accounts)
      print('  - User not found by UID, checking by email: $email');
      final emailSnap = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailSnap.docs.isNotEmpty) {
        print('  - User found by email');
        final userData = emailSnap.docs.first.data();
        
        // Migrate to UID for faster future lookups
        print('  - Migrating user to UID-based document');
        await _firestore.collection('users').doc(uid).set(userData);
        
        return userData;
      }

      // User not found - reject sign-in (no auto-registration)
      print('  - User not found in Firestore - rejecting sign-in');
      throw Exception('User account not found. Please contact the administrator to register your account.');
      
    } catch (e) {
      print('Error getting user: $e');
      rethrow;
    }
  }

  /// Sign out from Google and Firebase
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      print('Sign out successful');
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  /// Get current user role
  static Future<String?> getCurrentUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['role'] as String?;
    } catch (e) {
      print('Get user role error: $e');
      return null;
    }
  }

  /// Check if user is signed in
  static bool isSignedIn() {
    return _auth.currentUser != null;
  }

  /// Get current user email
  static String? getCurrentUserEmail() {
    return _auth.currentUser?.email;
  }

  /// Get current user data
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      print('Get user data error: $e');
      return null;
    }
  }
}
