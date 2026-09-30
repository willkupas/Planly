import 'package:planly/core/error/app_failure.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Texto (i18n) para uma falha; nunca expõe mensagem técnica de SDK.
String failureMessage(AppLocalizations l10n, Object error) {
  if (error is! AppFailure) return l10n.errorUnknown;
  return switch (error) {
    NetworkFailure() => l10n.errorNetwork,
    CancelledFailure() => l10n.errorUnknown,
    PermissionDeniedFailure() => l10n.errorPermissionDenied,
    RequiresRecentLoginFailure() => l10n.errorRequiresRecentLogin,
    AccountFailure() => l10n.errorAccount,
    ConfigurationFailure() => l10n.errorConfiguration,
    UnknownFailure() => l10n.errorUnknown,
  };
}
