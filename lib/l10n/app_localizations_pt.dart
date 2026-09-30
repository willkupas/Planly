// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Planly';

  @override
  String get homeTitle => 'Início';

  @override
  String get homeGreeting => 'Bom dia 👋';

  @override
  String get homePlaceholder =>
      'Suas tarefas compartilhadas vão aparecer aqui.';
}
