import 'package:planly/app/router/routes.dart';
import 'package:planly/features/auth/domain/auth_state.dart';

/// Guard adicional aplicado só com usuário autenticado (spec §2.2 ordens 4–6: bootstrap,
/// `/no-access`, família frozen). Devolve o destino ou `null` para seguir.
/// PONTO DE EXTENSÃO da T-014: registrar guards em `postAuthGuards` (app_router.dart).
typedef PostAuthGuard = String? Function(SignedIn auth, String location);

/// Redirect puro (testável). Ordem da spec §2.2:
/// 1. auth resolvendo -> /splash; 2. deslogado fora de /login -> /login;
/// 3. logado em /login ou /splash -> /home; depois, guards pós-auth (T-014).
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
      if (location == Routes.login || location == Routes.splash) return Routes.home;
      for (final guard in postAuthGuards) {
        final target = guard(auth, location);
        if (target != null && target != location) return target;
      }
      return null;
  }
}
