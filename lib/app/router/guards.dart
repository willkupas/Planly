import 'package:planly/app/router/routes.dart';
import 'package:planly/app/session/session_phase.dart';
import 'package:planly/features/auth/domain/auth_state.dart';

/// Guard aplicado só com usuário autenticado (spec §2.2 ordens 4–6). Devolve o destino, ou
/// `null` para seguir. Devolver a própria `location` significa "ficar aqui" (interrompe os
/// demais guards e a regra 3).
typedef PostAuthGuard = String? Function(SignedIn auth, String location);

bool _isUnder(String location, String base) => location == base || location.startsWith('$base/');

/// Guards de sessão (bootstrap pendente, `/no-access`, família `deleting`) — puro e testável.
/// Família `frozen` **não** redireciona (modo leitura, spec §2.3).
String? sessionGuard(SessionPhase phase, String location) {
  switch (phase) {
    case SessionPhase.loading:
      return Routes.splash;
    case SessionPhase.error:
      return Routes.sessionError;
    case SessionPhase.needsBootstrap:
      // Ordem 4: só /bootstrap e /settings* (e /join) ficam livres.
      if (location == Routes.bootstrap || _isUnder(location, Routes.settings) || location == Routes.join) {
        return location;
      }
      return Routes.bootstrap;
    case SessionPhase.noAccess:
      if (location == Routes.bootstrap ||
          location == Routes.splash ||
          location == Routes.login ||
          location == Routes.sessionError) {
        return Routes.noAccess;
      }
      // Ordem 5: só rotas de conteúdo caem em /no-access; família/configurações seguem livres.
      if (Routes.contentRoutes.any((r) => _isUnder(location, r))) return Routes.noAccess;
      return location;
    case SessionPhase.ready:
      if (location == Routes.bootstrap || location == Routes.noAccess || location == Routes.sessionError) {
        return Routes.home;
      }
      return null;
  }
}

/// Redirect puro (testável). Ordem da spec §2.2:
/// 1. auth resolvendo -> /splash; 2. deslogado fora de /login -> /login;
/// 3. logado: guards pós-auth (bootstrap/no-access) e, se nenhum agir, /login e /splash -> /home.
String? resolveRedirect({
  required AuthState auth,
  required String location,
  List<PostAuthGuard> postAuthGuards = const [],
}) {
  switch (auth) {
    case AuthLoading():
      return location == Routes.splash ? null : Routes.splash;
    case SignedOut():
      return location == Routes.login ? null : Routes.login;
    case SignedIn():
      for (final guard in postAuthGuards) {
        final target = guard(auth, location);
        if (target != null) return target == location ? null : target;
      }
      if (location == Routes.login || location == Routes.splash) return Routes.home;
      return null;
  }
}
