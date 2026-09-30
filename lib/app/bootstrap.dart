import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/app/app.dart';

/// Ponto único de inicialização. Firebase, App Check e emuladores entram na T-007/T-008.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PlanlyApp()));
}
