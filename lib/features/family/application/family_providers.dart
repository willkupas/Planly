import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/family/data/firestore_family_repository.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/family/domain/family_repository.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FirestoreFamilyRepository(
    firestore: ref.watch(firestoreProvider),
    callable: ref.watch(callableInvokerProvider),
  );
});

/// `users/{uid}/memberships` (listener de sessão, spec §7).
final membershipsProvider = StreamProvider<List<FamilyMembership>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(familyRepositoryProvider).watchMemberships(uid);
});

/// Família ativa já validada: a escolha guardada se ainda existir nas memberships; senão a
/// Free do usuário (preferida), senão a primeira. `null` enquanto não há dado/sem famílias.
final activeFamilyIdProvider = Provider<String?>((ref) {
  final memberships = ref.watch(membershipsProvider).value;
  if (memberships == null || memberships.isEmpty) return null;
  final stored = ref.watch(activeContextProvider).familyId;
  if (stored != null && memberships.any((m) => m.familyId == stored)) return stored;
  final own = memberships.where((m) => m.isOwner && m.plan == PlanId.free);
  return (own.isNotEmpty ? own.first : memberships.first).familyId;
});

final activeMembershipProvider = Provider<FamilyMembership?>((ref) {
  final id = ref.watch(activeFamilyIdProvider);
  final memberships = ref.watch(membershipsProvider).value;
  if (id == null || memberships == null) return null;
  for (final m in memberships) {
    if (m.familyId == id) return m;
  }
  return null;
});

final isOwnerProvider = Provider<bool>(
  (ref) => ref.watch(activeMembershipProvider)?.isOwner ?? false,
);

/// `families/{f}` da família ativa (listener de sessão).
final activeFamilyProvider = StreamProvider<Family?>((ref) {
  final id = ref.watch(activeFamilyIdProvider);
  if (id == null) return const Stream.empty();
  return ref.watch(familyRepositoryProvider).watchFamily(id);
});

final activeEntitlementProvider = StreamProvider<Entitlement?>((ref) {
  final id = ref.watch(activeFamilyIdProvider);
  if (id == null) return const Stream.empty();
  return ref.watch(familyRepositoryProvider).watchEntitlement(id);
});

/// Status da família ativa: doc da família se já carregou; senão o espelho da membership.
final activeFamilyStatusProvider = Provider<FamilyStatus?>((ref) {
  final family = ref.watch(activeFamilyProvider).value;
  if (family != null) return family.status;
  return ref.watch(activeMembershipProvider)?.familyStatus;
});

/// Modo leitura (spec §2.3): escrita de conteúdo só com família `active`. As Rules são a
/// barreira real; isto só evita tentativas inúteis e alimenta o banner.
final familyWriteAccessProvider = Provider<bool>(
  (ref) => ref.watch(activeFamilyStatusProvider) == FamilyStatus.active,
);

/// Só enquanto a tela de Membros está aberta (autoDispose).
final familyMembersProvider = StreamProvider.autoDispose.family<List<FamilyMember>, String>(
  (ref, familyId) {
    // Invalida ao trocar de conta.
    ref.watch(currentUidProvider);
    return ref.watch(familyRepositoryProvider).watchMembers(familyId);
  },
);
