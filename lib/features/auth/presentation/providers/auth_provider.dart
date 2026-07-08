import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppUser {
  final String uid;
  final String email;
  final String role; // 'OWNER', 'TEACHER', etc.

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
  });
}

class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseAuth get auth => _auth;

  AuthNotifier() : super(AuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      try {
        await _auth.setPersistence(Persistence.LOCAL);
      } catch (_) {}
    }
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        state = AuthState(user: null, isLoading: false);
      } else {
        try {
          // Fetch user role from Firestore
          final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
          String role = 'OWNER'; // Default role for initial owner accounts
          if (doc.exists) {
            role = doc.data()?['role'] as String? ?? 'OWNER';
          } else {
            // Write default role to Firestore
            await _firestore.collection('users').doc(firebaseUser.uid).set({
              'email': firebaseUser.email,
              'role': role,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          state = AuthState(
            user: AppUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              role: role,
            ),
            isLoading: false,
          );
        } catch (e) {
          // Fall back to OWNER if read fails during initial setups
          state = AuthState(
            user: AppUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              role: 'OWNER',
            ),
            isLoading: false,
          );
        }
      }
    });
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e, stackTrace) {
      print('DEBUG AUTH EXCEPTION: Code: ${e.code}, Message: ${e.message}');
      print(stackTrace);

      final message = 'FirebaseAuthException: [${e.code}] ${e.message}';
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    } catch (e, stackTrace) {
      print('DEBUG GENERIC AUTH EXCEPTION: $e');
      print(stackTrace);

      state = state.copyWith(isLoading: false, errorMessage: 'Exception: ${e.toString()}');
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _auth.signOut();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
