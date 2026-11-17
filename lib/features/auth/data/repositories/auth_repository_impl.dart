import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../../../../core/utils/google_auth_helper.dart';
import '../../../../core/utils/notification_service.dart';
import 'package:rxdart/rxdart.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<UserEntity?> get authStateChanges {
    return _firebaseAuth.authStateChanges().switchMap((firebaseUser) {
      if (firebaseUser == null) return Stream.value(null);
      
      return _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .map((userDoc) {
            if (userDoc.exists) {
              return UserModel.fromFirestore(userDoc);
            }
            // If the document doesn't exist (i.e. partial Google Auth login without registration), return null.
            return null;
          });
    });
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;
    
    final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    if (userDoc.exists) {
      return UserModel.fromFirestore(userDoc);
    }
    return null;
  }

  @override
  Future<UserEntity> signInWithEmail({required String email, required String password}) async {
    try {
      // First check if the email exists in our Firestore database to bypass Firebase Auth's 
      // consolidated 'invalid-credential' error that hides 'user-not-found' vs 'wrong-password'.
      final querySnapshot = await _firestore.collection('users').where('email', isEqualTo: email).limit(1).get();
      if (querySnapshot.docs.isEmpty) {
        throw Exception('ACCOUNT_NOT_FOUND');
      }

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      final user = await getCurrentUser();
      if (user == null) throw Exception("User data not found in Firestore");
      
      // Request permission and save FCM token for Push Notifications
      await NotificationService.requestPermission();
      await NotificationService.saveTokenToDatabase(user.uid);
      
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('ACCOUNT_NOT_FOUND');
      } else if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        // Because we already verified the user's email exists in our database above,
        // a subsequent invalid-credential error must mean the password is wrong!
        throw Exception('WRONG_PASSWORD');
      } else if (e.code == 'user-disabled') {
        throw Exception('This account has been disabled. Please contact support.');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address is badly formatted.');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many login attempts. Please try again later.');
      }
      throw Exception(e.message ?? "Authentication Failed. Please try again.");
    } catch (e) {
      if (e.toString().contains('ACCOUNT_NOT_FOUND')) {
        throw Exception('ACCOUNT_NOT_FOUND');
      }
      throw Exception("An unexpected error occurred: ${e.toString()}");
    }
  }

  @override
  Future<UserEntity?> signInWithGoogle({UserRole? role, String? deviceId, String? relationship}) async {
    try {
      final helper = GoogleAuthHelper(); 
      final credential = await helper.signIn();
      if (credential == null || credential.user == null) return null;
      
      final user = await getCurrentUser();
      if (user != null) {
        // If role is provided, it means they clicked "Sign up with Google". 
        // If user already exists, throw an error.
        if (role != null) {
          await _firebaseAuth.signOut();
          await helper.signOut();
          throw Exception('An account already exists for that email. Please sign in instead.');
        }
        // Otherwise, it's a normal login. Return existing user.
        
        // Request permission and save FCM token for Push Notifications
        await NotificationService.requestPermission();
        await NotificationService.saveTokenToDatabase(user.uid);
        
        return user;
      }

      // If user is null (new user) but role is null (called from Login Screen),
      // we don't want to create an account. We want to show "Account Not Found".
      if (role == null) {
        // Sign out from Google Auth so they aren't stuck logged in without a Firestore user
        await _firebaseAuth.signOut();
        await helper.signOut(); 
        throw Exception('ACCOUNT_NOT_FOUND');
      }

      // If new user via Google and role is provided (from setup/role-selection screen), create profile
      if (role == UserRole.patient && deviceId != null) {
        final deviceDoc = await _firestore.collection('dispensers').doc(deviceId).get();
        if (!deviceDoc.exists) {
          await _firebaseAuth.signOut();
          await helper.signOut();
          throw Exception('DEVICE_NOT_FOUND');
        }
      }

      final newUser = UserModel(
        uid: credential.user!.uid,
        email: credential.user!.email ?? '',
        role: role, 
        name: credential.user!.displayName,
        linkedDispensers: deviceId != null ? [deviceId] : [],
        relationship: relationship,
      );
      
      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap(), SetOptions(merge: true));
      
      // Request permission and save FCM token for Push Notifications
      await NotificationService.requestPermission();
      await NotificationService.saveTokenToDatabase(newUser.uid);
      
      return newUser;
    } catch (e) {
       if (e.toString().contains('DEVICE_NOT_FOUND')) {
         throw Exception('DEVICE_NOT_FOUND');
       }
       if (e.toString().contains('ACCOUNT_NOT_FOUND')) {
         throw Exception('ACCOUNT_NOT_FOUND');
       }
       throw Exception(e.toString());
    }
  }

  @override
  Future<UserEntity> signUp({
    required String email, 
    required String password, 
    required UserRole role,
    String? name,
    String? phone,
    String? relationship,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      final newUser = UserModel(
        uid: credential.user!.uid,
        email: email,
        role: role,
        name: name,
        phone: phone,
        relationship: relationship,
      );

      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
      
      // Request permission and save FCM token for Push Notifications
      await NotificationService.requestPermission();
      await NotificationService.saveTokenToDatabase(newUser.uid);
      
      return newUser;
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Registration Failed. Please try again.";
      if (e.code == 'weak-password') {
        errorMessage = "The password provided is too weak.";
      } else if (e.code == 'email-already-in-use') {
        errorMessage = "An account already exists for that email.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "The email address is badly formatted.";
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = "Email/password accounts are not enabled. Contact support.";
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception("An unexpected error occurred: ${e.toString()}");
    }
  }

  @override
  Future<UserEntity> signInAnonymously({required UserRole role, required String deviceId}) async {
    try {
      final credential = await _firebaseAuth.signInAnonymously();
      
      final newUser = UserModel(
        uid: credential.user!.uid,
        email: 'anonymous@test.com', // Placeholder for anonymous
        role: role,
        name: 'Test User',
        linkedDispensers: [deviceId],
      );

      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap(), SetOptions(merge: true));
      return newUser;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Anonymous Auth Failed");
    }
  }

  @override
  Future<void> signOut() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
       await NotificationService.removeTokenFromDatabase(user.uid);
    }
    
    await _firebaseAuth.signOut();
    await GoogleAuthHelper().signOut();
  }
  
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final querySnapshot = await _firestore.collection('users').where('email', isEqualTo: email).limit(1).get();
      if (querySnapshot.docs.isEmpty) {
        throw Exception('ACCOUNT_NOT_FOUND');
      }
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('ACCOUNT_NOT_FOUND');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address is badly formatted.');
      }
      throw Exception(e.message ?? "Password reset failed.");
    } catch (e) {
      if (e.toString().contains('ACCOUNT_NOT_FOUND')) {
        throw Exception('ACCOUNT_NOT_FOUND');
      }
      throw Exception("An unexpected error occurred: ${e.toString()}");
    }
  }
}
