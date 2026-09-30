import 'package:planly/features/family/domain/family_models.dart';

/// Acesso a famílias, membros e plano. Falhas são lançadas como `AppFailure`.
/// Streams emitem erros como `AppFailure` (mapeados na camada data).
abstract class FamilyRepository {
  /// `users/{uid}/memberships`.
  Stream<List<FamilyMembership>> watchMemberships(String uid);

  /// `families/{id}` via `get/snapshots` de documento (Rules não permitem list). `null` se
  /// o doc não existe/foi removido.
  Stream<Family?> watchFamily(String familyId);

  Stream<Entitlement?> watchEntitlement(String familyId);

  /// Membros ativos (`status == active`).
  Stream<List<FamilyMember>> watchMembers(String familyId);

  /// Callable `bootstrapUser` (online-only, idempotente).
  Future<BootstrapResult> bootstrapUser({
    String? displayName,
    String? locale,
    String? timezone,
  });

  /// Callable `removeMember` (owner).
  Future<void> removeMember({required String familyId, required String targetUid});

  /// Callable `leaveFamily` (membro).
  Future<void> leaveFamily(String familyId);
}
