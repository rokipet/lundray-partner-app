import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase.dart';
import '../models/profile.dart';

class AuthState {
  final User? user;
  final Profile? profile;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null && profile != null;
  bool get isPartner => profile?.role == 'partner';

  AuthState copyWith({
    User? user,
    Profile? profile,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _init();
  }

  StreamSubscription<AuthState>? _authSubscription;

  void _init() {
    final session = supabase.auth.currentSession;
    if (session != null) {
      state = state.copyWith(user: supabase.auth.currentUser, isLoading: true);
      _fetchProfile();
    }

    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        state = state.copyWith(user: data.session?.user, isLoading: true);
        _fetchProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        state = AuthState();
      }
    });
  }

  Future<void> _fetchProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        state = AuthState(error: 'No user found');
        return;
      }

      final data =
          await supabase.from('profiles').select().eq('id', userId).single();

      final profile = Profile.fromJson(data);

      if (profile.role != 'partner') {
        await supabase.auth.signOut();
        state = AuthState(error: 'Access denied. Partner account required.');
        return;
      }

      state = AuthState(
        user: supabase.auth.currentUser,
        profile: profile,
      );
    } catch (e) {
      state = AuthState(error: 'Failed to load profile: $e');
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        state = AuthState(error: 'Login failed. Please try again.');
        return;
      }

      state = state.copyWith(user: response.user, isLoading: true);
      await _fetchProfile();
    } on AuthException catch (e) {
      state = AuthState(error: e.message);
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    state = AuthState();
  }

  Future<void> refreshProfile() async {
    await _fetchProfile();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
