import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../../../../core/utils/google_auth_helper.dart';
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
            // Fallback if doc doesn't exist yet
            return UserModel(
              uid: firebaseUser.uid, 
              email: firebaseUser.email ?? '', 
              role: UserRole.patient,
              name: firebaseUser.displayName, 
            ); 
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
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      final user = await getCurrentUser();
      if (user == null) throw Exception("User data not found in Firestore");
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Authentication Failed");
    }
  }

  @override
  Future<UserEntity?> signInWithGoogle({UserRole? role, String? deviceId}) async {
    try {
      final helper = GoogleAuthHelper(); 
      final credential = await helper.signIn();
      if (credential == null || credential.user == null) return null;
      
      final user = await getCurrentUser();
      if (user != null) {
        // User exists, maybe update device id if needed?
        // For now, just return existing user.
        return user;
      }

      // If new user via Google, create basic profile
      final newUser = UserModel(
        uid: credential.user!.uid,
        email: credential.user!.email ?? '',
        role: role ?? UserRole.patient, // Use selected role or default
        name: credential.user!.displayName,
        linkedDispensers: deviceId != null ? [deviceId] : [],
      );
      
      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap(), SetOptions(merge: true));
      return newUser;
    } catch (e) {
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
      return newUser;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Registration Failed");
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
    await _firebaseAuth.signOut();
  }
  
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }
}
