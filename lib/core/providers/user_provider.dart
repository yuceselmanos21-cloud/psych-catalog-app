import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/logger.dart';

/// Kullanıcı state modeli
class UserState {
  final String? uid;
  final String? email;
  final String? name;
  final String? username;
  final String? role; // 'client', 'expert', 'admin'
  final bool isAdmin;
  final bool isExpert;
  final Map<String, dynamic>? userData;
  final bool isLoading;

  const UserState({
    this.uid,
    this.email,
    this.name,
    this.username,
    this.role,
    this.isAdmin = false,
    this.isExpert = false,
    this.userData,
    this.isLoading = true,
  });

  UserState copyWith({
    String? uid,
    String? email,
    String? name,
    String? username,
    String? role,
    bool? isAdmin,
    bool? isExpert,
    Map<String, dynamic>? userData,
    bool? isLoading,
  }) {
    return UserState(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      username: username ?? this.username,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
      isExpert: isExpert ?? this.isExpert,
      userData: userData ?? this.userData,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Kullanıcı state notifier
class UserNotifier extends StateNotifier<UserState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserNotifier() : super(const UserState()) {
    _init();
  }

  Future<void> _init() async {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        state = const UserState(isLoading: false);
      }
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      state = state.copyWith(isLoading: true);

      // User document'ı çek
      final userDoc = await _db.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String? ?? 'client';
      
      // Admin kontrolü
      final adminDoc = await _db.collection('admins').doc(uid).get();
      final isAdmin = adminDoc.exists || role == 'admin';
      final isExpert = role == 'expert' || role == 'admin' || isAdmin;

      state = state.copyWith(
        uid: uid,
        email: _auth.currentUser?.email,
        name: userData['name'] as String?,
        username: userData['username'] as String?,
        role: role,
        isAdmin: isAdmin,
        isExpert: isExpert,
        userData: userData,
        isLoading: false,
      );

      AppLogger.debug('User data loaded', context: {
        'uid': uid,
        'role': role,
        'isAdmin': isAdmin,
        'isExpert': isExpert,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load user data', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false);
    }
  }

  /// Kullanıcı verilerini yenile
  Future<void> refresh() async {
    final uid = state.uid;
    if (uid != null) {
      await _loadUserData(uid);
    }
  }

  /// Kullanıcı çıkış yap
  Future<void> signOut() async {
    await _auth.signOut();
    state = const UserState(isLoading: false);
  }
}

/// User provider
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier();
});

/// Convenience providers
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(userProvider).uid;
});

final currentUserRoleProvider = Provider<String?>((ref) {
  return ref.watch(userProvider).role;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(userProvider).isAdmin;
});

final isExpertProvider = Provider<bool>((ref) {
  return ref.watch(userProvider).isExpert;
});

final currentUserNameProvider = Provider<String?>((ref) {
  return ref.watch(userProvider).name;
});

final currentUserUsernameProvider = Provider<String?>((ref) {
  return ref.watch(userProvider).username;
});
