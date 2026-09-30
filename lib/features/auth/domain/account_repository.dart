/// Operações de conta que dependem do backend (Cloud Functions). Falhas são `AppFailure`.
abstract class AccountRepository {
  /// Callable `deleteAccount` (online-only): apaga os dados da conta e, por último, o usuário
  /// no Firebase Auth. `OWNER_HAS_MEMBERS` bloqueia; `REQUIRES_RECENT_LOGIN` pede reautenticação.
  Future<void> deleteAccount();
}
