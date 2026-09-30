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

class UnknownFailure extends AppFailure {
  const UnknownFailure();
}
