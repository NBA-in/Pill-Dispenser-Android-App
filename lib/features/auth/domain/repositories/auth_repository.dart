import '../entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;
  
  Future<UserEntity?> getCurrentUser();
  
  Future<UserEntity> signInWithEmail({required String email, required String password});
  
  Future<UserEntity> signUp({
    required String email, 
    required String password, 
    required UserRole role,
    String? name,
    String? phone,
    String? relationship, // for caregiver
  });
  
  Future<void> signOut();
  
  Future<UserEntity?> signInWithGoogle({UserRole? role, String? deviceId});

  Future<UserEntity> signInAnonymously({required UserRole role, required String deviceId});

  Future<void> sendPasswordResetEmail(String email);
}
