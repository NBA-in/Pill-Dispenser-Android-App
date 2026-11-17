import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

final authStateProvider = StreamProvider<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Implementation of a Controller for Auth Actions (Sign In, Sign Up)
final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(const AsyncValue.data(null));

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.signInWithEmail(email: email, password: password));
  }

  Future<void> signInWithGoogle({UserRole? role, String? deviceId, String? relationship}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signInWithGoogle(role: role, deviceId: deviceId, relationship: relationship);
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required UserRole role,
    String? name,
    String? phone,
    String? relationship,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.signUp(
      email: email, 
      password: password, 
      role: role,
      name: name,
      phone: phone,
      relationship: relationship,
    ));
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.signOut());
  }

  Future<void> signInAnonymously({required UserRole role, required String deviceId}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authRepository.signInAnonymously(role: role, deviceId: deviceId));
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _authRepository.sendPasswordResetEmail(email);
  }
}
