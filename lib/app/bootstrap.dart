import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/app/app.dart';
import 'package:planly/app/flavor.dart';

/// Ponto único de inicialização, chamado pelos entry points de cada flavor.
/// Emuladores (T-008), App Check e Crashlytics (T-010) entram aqui.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sem `options`: no Android o plugin google-services lê o google-services.json do flavor.
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: PlanlyApp()));
}
