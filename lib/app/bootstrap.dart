import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/app/app.dart';
import 'package:planly/app/flavor.dart';
import 'package:planly/core/firebase/emulators.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/core/firebase/firestore_local_data_service.dart';
import 'package:planly/core/firebase/observability.dart';
import 'package:planly/features/notifications/data/push_background_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ponto único de inicialização, chamado pelos entry points de cada flavor.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sem `options`: no Android o plugin google-services lê o google-services.json do flavor.
  await Firebase.initializeApp();
  await initAppCheck(flavor);
  await initCrashReporting(flavor);
  await initAnalytics(flavor);
  if (flavor.useEmulators) {
    await connectToFirebaseEmulators();
  }
  // Push de eventos compartilhados em segundo plano/encerrado (T-023).
  registerPushBackgroundHandler();
  final prefs = await SharedPreferences.getInstance();
  // Limpeza de cache agendada por um logout anterior que não conseguiu limpar (spec §8.3).
  // Precisa rodar antes de qualquer outro uso do Firestore (e depois de apontar o emulador).
  await runPendingFirestoreClear(prefs);
  runApp(
    ProviderScope(
      // Falhas de stream/callable viram estado de erro na UI (com "Tentar de novo"), sem
      // retry automático silencioso do Riverpod.
      retry: (_, _) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PlanlyApp(),
    ),
  );
}
