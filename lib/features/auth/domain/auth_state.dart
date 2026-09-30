import 'package:planly/features/auth/domain/auth_user.dart';

sealed class AuthState {
  const AuthState();
}

/// Sessão ainda sendo resolvida (primeiro evento do provedor de auth).
class AuthLoading extends AuthState {
  const AuthLoading();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.user);

  final AuthUser user;

  @override
  bool operator ==(Object other) => other is SignedIn && other.user == user;

  @override
  int get hashCode => user.hashCode;
}
