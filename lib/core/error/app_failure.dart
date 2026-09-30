/// Falha tipada do app. A UI nunca mostra mensagem de SDK: mapeia cada tipo para uma
/// chave ARB (ver `core/l10n_helpers/failure_message.dart`).
sealed class AppFailure implements Exception {
  const AppFailure();
}

/// Sem conexão ou serviço inalcançável.
class NetworkFailure extends AppFailure {
  const NetworkFailure();
}

/// Usuário cancelou a operação (não é erro para a UI).
class CancelledFailure extends AppFailure {
  const CancelledFailure();
}

class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure();
}

/// Operação sensível que exige login recente (reautenticação).
class RequiresRecentLoginFailure extends AppFailure {
  const RequiresRecentLoginFailure();
}

/// Conta desativada, credencial inválida/expirada ou conta já vinculada a outro método.
class AccountFailure extends AppFailure {
  const AccountFailure();
}

/// App mal configurado (ex.: client ID/SHA-1 do Google ausente).
class ConfigurationFailure extends AppFailure {
  const ConfigurationFailure();
}

/// Regra de negócio recusada por uma Cloud Function. `reason` é o código estável definido em
/// `docs/specs/cloud-functions.md` §1.1 (ex.: `PLAN_LIMIT_HOUSEHOLDS`, `FAMILY_FROZEN`).
class BusinessFailure extends AppFailure {
  const BusinessFailure(this.reason);

  final String reason;

  @override
  bool operator ==(Object other) => other is BusinessFailure && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

class UnknownFailure extends AppFailure {
  const UnknownFailure();
}
