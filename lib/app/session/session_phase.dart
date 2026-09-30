import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/features/auth/application/user_profile_providers.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/household/domain/household_models.dart';

/// Em que ponto da sessão o usuário logado está (base dos guards de spec §2.2 ordens 4–6).
enum SessionPhase {
  /// Ainda lendo `users/{uid}` e memberships (cache primeiro).
  loading,

  /// Falha ao ler o contexto (ex.: permissão/rede sem cache).
  error,

  /// Sem `freeFamilyId` e sem memberships: precisa de `bootstrapUser`.
  needsBootstrap,

  /// Família ativa em `deleting`, ou sem casa acessível (membro sem vínculo).
  noAccess,

  ready,
}

/// Decisão pura (testável), sem Riverpod.
SessionPhase computeSessionPhase({
  required bool profileLoading,
  required bool profileError,
  required bool membershipsLoading,
  required bool membershipsError,
  required bool hasFreeFamily,
  required int membershipCount,
  required FamilyStatus? activeStatus,
  required bool? hasAccessibleHousehold, // null = ainda carregando
}) {
  if (profileError || membershipsError) return SessionPhase.error;
  if (profileLoading || membershipsLoading) return SessionPhase.loading;
  if (!hasFreeFamily && membershipCount == 0) return SessionPhase.needsBootstrap;
  if (activeStatus == FamilyStatus.deleting) return SessionPhase.noAccess;
  // Casas ainda carregando não derrubam a sessão para a splash (as telas mostram o loading).
  if (hasAccessibleHousehold == false) return SessionPhase.noAccess;
  return SessionPhase.ready;
}

/// `null` = não dá para afirmar: sem dado, ou lista vazia vinda só do cache (pode estar
/// desatualizada; evita falso `/no-access` antes do servidor responder).
bool? _hasHousehold(AsyncValue<HouseholdsSnapshot> households) {
  final snap = households.value;
  if (snap == null) return null;
  if (snap.items.isNotEmpty) return true;
  return snap.meta.isFromCache ? null : false;
}

final sessionPhaseProvider = Provider<SessionPhase>((ref) {
  final profile = ref.watch(userProfileProvider);
  final memberships = ref.watch(membershipsProvider);
  final households = ref.watch(accessibleHouseholdsProvider);

  // Erro só conta se não há valor (um erro de stream depois de dados não derruba a sessão).
  return computeSessionPhase(
    profileLoading: !profile.hasValue && !profile.hasError,
    profileError: profile.hasError && !profile.hasValue,
    membershipsLoading: !memberships.hasValue && !memberships.hasError,
    membershipsError: memberships.hasError && !memberships.hasValue,
    hasFreeFamily: profile.value?.freeFamilyId != null,
    membershipCount: memberships.value?.length ?? 0,
    activeStatus: ref.watch(activeFamilyStatusProvider),
    hasAccessibleHousehold: _hasHousehold(households),
  );
});
