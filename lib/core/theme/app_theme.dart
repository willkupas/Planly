import 'package:flutter/material.dart';

/// Tema Material 3. A cor-semente é provisória até existir identidade visual.
abstract final class AppTheme {
  static const _seed = Color(0xFF2E7D6B);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    );
  }
}
