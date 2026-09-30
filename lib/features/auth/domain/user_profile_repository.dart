/// `users/{uid}` visto pelo cliente (data-model §3.1).
class UserProfile {
  const UserProfile({this.freeFamilyId});

  /// Preenchido só pela Function `bootstrapUser`. `null` = bootstrap ainda não feito.
  final String? freeFamilyId;
}

abstract class UserProfileRepository {
  /// Emite `null` se o doc ainda não existe (usuário novo, antes do bootstrap).
  Stream<UserProfile?> watchProfile(String uid);

  /// Atualiza só os campos que o cliente pode escrever (Rules): displayName, photoUrl, locale,
  /// timezone (+ `updatedAt` de servidor). Campos `null` não são enviados.
  /// Requer que o doc exista (criado por `bootstrapUser`).
  Future<void> upsertClientFields(
    String uid, {
    String? displayName,
    String? photoUrl,
    String? locale,
    String? timezone,
  });
}
