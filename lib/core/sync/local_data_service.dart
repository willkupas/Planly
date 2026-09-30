/// Dados locais do Firestore (cache persistente). Usado no logout (spec flutter-app §8.3).
abstract class LocalDataService {
  /// true se há escritas locais ainda não confirmadas pelo servidor (ex.: offline).
  Future<bool> hasPendingWrites();

  /// Descarta cache e escritas pendentes (evita vazamento entre contas no mesmo aparelho).
  /// Se não der para limpar agora, agenda a limpeza para a próxima inicialização.
  Future<void> clearLocalData();
}
