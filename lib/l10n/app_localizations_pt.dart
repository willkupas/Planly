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

  @override
  String get splashLoading => 'Carregando';

  @override
  String get loginSubtitle => 'Tarefas da casa, em conjunto.';

  @override
  String get loginWithGoogle => 'Entrar com Google';

  @override
  String get loginSigningIn => 'Entrando…';

  @override
  String get logout => 'Sair';

  @override
  String get errorNetwork =>
      'Sem conexão. Verifique sua internet e tente de novo.';

  @override
  String get errorPermissionDenied => 'Você não tem permissão para fazer isso.';

  @override
  String get errorRequiresRecentLogin =>
      'Por segurança, entre novamente para continuar.';

  @override
  String get errorAccount =>
      'Não foi possível entrar com esta conta. Tente outra conta Google.';

  @override
  String get errorConfiguration =>
      'O login não está configurado neste aparelho. Tente mais tarde.';

  @override
  String get errorUnknown => 'Algo deu errado. Tente de novo.';
}
