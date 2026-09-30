import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/features/auth/data/firebase_auth_repository.dart';
import 'package:planly/features/auth/data/google_auth_adapter.dart';
import 'package:planly/features/auth/domain/auth_provider_id.dart';
import 'package:planly/features/auth/domain/auth_repository.dart';
import 'package:planly/features/auth/domain/auth_state.dart';
import 'package:planly/features/auth/domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    adapters: [GoogleAuthAdapter()],
  );
});

/// `AuthLoading` até o primeiro evento do provedor; depois `SignedOut`/`SignedIn`.
final authStateProvider = StreamProvider<AuthState>((ref) async* {
  yield const AuthLoading();
  yield* ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  final state = ref.watch(authStateProvider).value;
  return state is SignedIn ? state.user : null;
});

final currentUidProvider = Provider<String?>((ref) => ref.watch(currentUserProvider)?.uid);

final availableAuthProvidersProvider = Provider<Set<AuthProviderId>>(
  (ref) => ref.watch(authRepositoryProvider).availableProviders,
);

/// Estado do login: `AsyncLoading` durante o fluxo, `AsyncError(AppFailure)` se falhar.
/// Cancelamento pelo usuário volta a `AsyncData` (não é erro).
class SignInController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> signIn(AuthProviderId provider) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).signIn(provider);
      state = const AsyncData(null);
    } on CancelledFailure {
      state = const AsyncData(null);
    } on AppFailure catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final signInControllerProvider =
    NotifierProvider<SignInController, AsyncValue<void>>(SignInController.new);

// O logout (com aviso de escritas pendentes e limpeza do cache) vive em
// `features/settings/application/session_actions.dart`.
