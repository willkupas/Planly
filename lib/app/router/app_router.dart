import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/app_shell.dart';
import 'package:planly/app/router/guards.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/app/session/session_phase.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/auth/domain/auth_state.dart';
import 'package:planly/features/auth/presentation/login_page.dart';
import 'package:planly/features/auth/presentation/splash_page.dart';
import 'package:planly/features/family/presentation/bootstrap_page.dart';
import 'package:planly/features/family/presentation/family_hub_page.dart';
import 'package:planly/features/family/presentation/members_page.dart';
import 'package:planly/features/family/presentation/no_access_page.dart';
import 'package:planly/features/family/presentation/session_error_page.dart';
import 'package:planly/features/household/presentation/dashboard_page.dart';
import 'package:planly/features/household/presentation/households_page.dart';
import 'package:planly/features/invitation/presentation/invitations_page.dart';
import 'package:planly/features/invitation/presentation/invite_page.dart';
import 'package:planly/features/invitation/presentation/join_page.dart';
import 'package:planly/features/lists/presentation/list_detail_page.dart';
import 'package:planly/features/lists/presentation/lists_page.dart';
import 'package:planly/features/settings/presentation/settings_page.dart';
import 'package:planly/features/tasks/presentation/task_detail_page.dart';

/// Guards pós-autenticação (spec §2.2 ordens 4–6): bootstrap pendente, `/no-access` e família
/// `deleting`. A lógica está em `sessionGuard` (pura); aqui só lemos a fase da sessão.
final postAuthGuardsProvider = Provider<List<PostAuthGuard>>((ref) {
  return [(auth, location) => sessionGuard(ref.read(sessionPhaseProvider), location)];
});

/// Notifica o GoRouter quando a sessão, o bootstrap ou o contexto ativo mudam.
class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier();
  ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, _) => refresh.refresh());
  ref.listen<SessionPhase>(sessionPhaseProvider, (_, _) => refresh.refresh());
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      auth: ref.read(authStateProvider).value ?? const AuthLoading(),
      location: state.matchedLocation,
      postAuthGuards: ref.read(postAuthGuardsProvider),
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (context, state) => const SplashPage()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginPage()),
      GoRoute(path: Routes.bootstrap, builder: (context, state) => const BootstrapPage()),
      GoRoute(path: Routes.sessionError, builder: (context, state) => const SessionErrorPage()),
      GoRoute(path: Routes.noAccess, builder: (context, state) => const NoAccessPage()),
      GoRoute(path: Routes.settings, builder: (context, state) => const SettingsPage()),
      GoRoute(
        path: Routes.join,
        builder: (context, state) => JoinPage(initialCode: state.uri.queryParameters['code']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const DashboardPage(),
              routes: [
                GoRoute(
                  path: 'task/:taskId',
                  builder: (context, state) => TaskDetailPage(taskId: state.pathParameters['taskId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.lists,
              builder: (context, state) => const ListsPage(),
              routes: [
                GoRoute(
                  path: ':listId',
                  builder: (context, state) => ListDetailPage(listId: state.pathParameters['listId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.family,
              builder: (context, state) => const FamilyHubPage(),
              routes: [
                GoRoute(
                  path: 'members',
                  builder: (context, state) => const MembersPage(),
                  routes: [
                    GoRoute(path: 'invite', builder: (context, state) => const InvitePage()),
                    GoRoute(path: 'invitations', builder: (context, state) => const InvitationsPage()),
                  ],
                ),
                GoRoute(path: 'households', builder: (context, state) => const HouseholdsPage()),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
