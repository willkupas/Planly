import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// `true` = há alguma rede. Sinal complementar (o sinal real de sync vem do Firestore).
final connectivityProvider = StreamProvider<bool>((ref) async* {
  try {
    final connectivity = Connectivity();
    yield _isOnline(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(_isOnline);
  } catch (_) {
    // Sem plugin/permissão: assume online (nunca bloquear o usuário por engano).
    yield true;
  }
});

/// Sem dado ainda => assume online.
final isOnlineProvider = Provider<bool>((ref) => ref.watch(connectivityProvider).value ?? true);
