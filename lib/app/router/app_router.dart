import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/features/tasks/presentation/home_page.dart';

/// Rotas do app. Guards (auth, bootstrap, família frozen) entram com a T-011/T-014;
/// ver docs/specs/flutter-app.md §2.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
    ],
  );
});
