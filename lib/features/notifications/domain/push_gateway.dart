/// Abstração sobre o Firebase Messaging (testes usam um fake; telas nunca importam o SDK).
abstract class PushGateway {
  /// Token FCM atual do aparelho, ou `null` se indisponível.
  Future<String?> token();

  /// Novos tokens (rotação pelo FCM).
  Stream<String> get tokenRefreshes;

  /// `data` das mensagens recebidas com o app em primeiro plano.
  Stream<Map<String, dynamic>> get foregroundMessages;

  /// `data` das notificações tocadas com o app em segundo plano (mensagens com bloco
  /// `notification`; as nossas são só dados, mas o caminho fica coberto).
  Stream<Map<String, dynamic>> get openedMessages;

  /// `data` da mensagem que abriu o app (cold start), se houver.
  Future<Map<String, dynamic>?> initialMessage();

  /// Invalida o token no aparelho (logout): o FCM passa a recusá-lo e as Functions o removem.
  Future<void> deleteToken();
}
