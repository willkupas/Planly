import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/app/app.dart';
import 'package:planly/app/flavor.dart';

/// Ponto único de inicialização, chamado pelos entry points de cada flavor.
/// Firebase, App Check e emuladores entram aqui (T-007 em diante).
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PlanlyApp()));
}
