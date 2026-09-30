import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/connectivity/connectivity_provider.dart';
import 'package:planly/core/error/app_failure.dart';

/// Guarda de operações só-online (spec flutter-app §5.3): chamadas a Functions não entram em
/// fila; offline, falha cedo com `NetworkFailure` (a UI explica e mantém o botão habilitado).
/// Se a conectividade ainda não foi medida (início do app), espera a primeira leitura.
Future<void> ensureOnline(Ref ref) async {
  final current = ref.read(connectivityProvider);
  var online = true;
  if (current.hasValue) {
    online = current.requireValue;
  } else {
    try {
      online = await ref.read(connectivityProvider.future).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Sem leitura: assume online e deixa a própria chamada falhar, se for o caso.
    }
  }
  if (!online) throw const NetworkFailure();
}
