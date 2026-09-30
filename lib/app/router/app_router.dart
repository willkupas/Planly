import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/guards.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/auth/domain/auth_state.dart';
import 'package:planly/features/auth/presentation/login_page.dart';
import 'package:planly/features/auth/presentation/splash_page.dart';
import 'package:planly/features/tasks/presentation/home_page.dart';

/// Guards pós-autenticação (bootstrap pendente, /no-access, família frozen).
/// A T-014 adiciona os seus aqui; ver `guards.dart`.
final postAuthGuardsProvider = Provider<List<PostAuthGuard>>((ref) => const []);

/// Notifica o GoRouter quando a sessão (ou, na T-014, bootstrap/contexto) muda.
class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier();
  ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, _) => refresh.refresh());
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
      GoRoute(path: Routes.home, builder: (context, state) => const HomePage()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
