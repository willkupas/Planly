import 'dart:async';

import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/auth/domain/auth_provider_id.dart';
import 'package:planly/features/auth/domain/auth_repository.dart';
import 'package:planly/features/auth/domain/auth_state.dart';
import 'package:planly/features/auth/domain/auth_user.dart';

const testUser = AuthUser(uid: 'u1', displayName: 'Teste', email: 'teste@example.com');

/// Fake em memória para testes (injetado via override de `authRepositoryProvider`).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser, this.emitInitial = true}) : _user = initialUser;

  /// Se false, o stream fica sem evento até `resolve()` (simula sessão resolvendo).
  final bool emitInitial;
  AuthUser? _user;
  final _controller = StreamController<AuthState>.broadcast();
  final _resolved = Completer<void>();

  /// Falha a lançar no próximo `signIn`; `signInGate` segura o fluxo em "loading".
  AppFailure? nextSignInFailure;
  Completer<void>? signInGate;
  int signInCalls = 0;
  int signOutCalls = 0;

  AuthState get _current => _user == null ? const SignedOut() : SignedIn(_user!);

  void resolve() {
    if (!_resolved.isCompleted) _resolved.complete();
  }

  @override
  Stream<AuthState> authStateChanges() async* {
    if (emitInitial) resolve();
    await _resolved.future;
    yield _current;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Set<AuthProviderId> get availableProviders => {AuthProviderId.google};

  @override
  Future<AuthUser> signIn(AuthProviderId provider) async {
    signInCalls++;
    await signInGate?.future;
    final failure = nextSignInFailure;
    if (failure != null) {
      nextSignInFailure = null;
      throw failure;
    }
    _user = testUser;
    _controller.add(_current);
    return testUser;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _user = null;
    _controller.add(_current);
  }

  @override
  Future<void> deleteAccount() => signOut();

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      _user == null ? null : 'fake-token';
}
