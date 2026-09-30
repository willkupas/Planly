/// Paths das rotas (spec flutter-app §2.1).
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const bootstrap = '/bootstrap';
  static const sessionError = '/session-error';
  static const home = '/home';
  static const family = '/family';
  static const familyMembers = '/family/members';
  static const familyHouseholds = '/family/households';

  /// Ponto de extensão da T-015 (convites): a tela de convite entra sob esta rota.
  static const familyInvite = '/family/members/invite';
  static const settings = '/settings';
  static const noAccess = '/no-access';

  /// Rotas de conteúdo da casa: exigem casa acessível (guard `/no-access`). Listas e
  /// Atividade entram aqui quando existirem.
  static const contentRoutes = {home};
}
