/// Registro do aparelho para push: `users/{uid}/devices/{deviceId}` (data-model §3.3).
abstract class DeviceRepository {
  /// Cria ou atualiza o doc do aparelho (`fcmToken`, `lastSeenAt`, idioma e fuso).
  Future<void> register({
    required String uid,
    required String deviceId,
    required String fcmToken,
    String? locale,
    String? timezone,
  });

  /// Remove o doc do aparelho (logout). Idempotente.
  Future<void> remove({required String uid, required String deviceId});
}
