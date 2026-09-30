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
    BusinessFailure(:final reason) => _businessMessage(l10n, reason),
    UnknownFailure() => l10n.errorUnknown,
  };
}

String _businessMessage(AppLocalizations l10n, String reason) {
  return switch (reason) {
    'NOT_OWNER' || 'NOT_MEMBER' => l10n.errorPermissionDenied,
    'FAMILY_FROZEN' => l10n.errorFamilyFrozen,
    'FEATURE_NOT_IN_PLAN' => l10n.errorFeatureNotInPlan,
    'PLAN_LIMIT_MEMBERS' => l10n.errorPlanLimitMembers,
    'PLAN_LIMIT_HOUSEHOLDS' => l10n.errorPlanLimitHouseholds,
    'OWNER_HAS_MEMBERS' => l10n.errorOwnerHasMembers,
    'LAST_HOUSEHOLD' => l10n.errorLastHousehold,
    'OWNER_CANNOT_LEAVE' => l10n.errorOwnerCannotLeave,
    'TRANSFER_PENDING' => l10n.errorTransferPending,
    'BOOTSTRAP_REQUIRED' => l10n.errorBootstrapRequired,
    'FAMILY_NOT_FOUND' ||
    'HOUSEHOLD_NOT_FOUND' ||
    'MEMBER_NOT_FOUND' =>
      l10n.errorNotFound,
    // Convite: nunca distingue inexistente / usado / revogado / expirado.
    'INVITE_NOT_FOUND' || 'INVITE_EXPIRED' => l10n.errorInviteInvalid,
    'ALREADY_MEMBER' => l10n.errorAlreadyMember,
    'TRANSFER_EXPIRED' => l10n.errorExpired,
    'RATE_LIMITED' => l10n.errorRateLimited,
    'REQUIRES_RECENT_LOGIN' => l10n.errorRequiresRecentLogin,
    _ => l10n.errorUnknown,
  };
}
