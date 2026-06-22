import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// null = logged out; map = the /auth/me payload.
final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, Map<String, dynamic>?>(
        AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() =>
      ref.read(authRepositoryProvider).currentUser();

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.login(email, password);
      return repo.currentUser();
    });
  }

  Future<void> register(String email, String password, String? name) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.register(email, password, name);
      return repo.currentUser();
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}
