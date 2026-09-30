/// Paths das rotas (spec flutter-app §2.1).
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const bootstrap = '/bootstrap';
  static const sessionError = '/session-error';
  static const home = '/home';

  /// Detalhe/edição de tarefa (sub-rota de `/home`).
  static String taskPath(String taskId) => '/home/task/$taskId';
  static const family = '/family';
  static const lists = '/lists';
  static String listDetail(String listId) => '/lists/$listId';
  static const activity = '/activity';
  static const familyMembers = '/family/members';
  static const familyHouseholds = '/family/households';

  /// Convidar (owner de plano pago) e lista de convites enviados.
  static const familyInvite = '/family/members/invite';
  static const familyInvitations = '/family/members/invitations';

  /// Entrar com código (liberado antes do bootstrap; `?code=` opcional).
  static const join = '/join';
  static const settings = '/settings';

  /// Excluir conta (T-025): rota livre de contexto, como as demais Configurações.
  static const deleteAccount = '/settings/delete-account';
  static const noAccess = '/no-access';

  /// Rotas de conteúdo da casa: exigem casa acessível (guard `/no-access`). Listas e
  /// Atividade entram aqui quando existirem.
  static const contentRoutes = {home, lists, activity};
}
