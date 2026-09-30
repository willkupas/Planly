import 'package:planly/features/household/domain/household_models.dart';

/// Tamanho do código de convite gerado pelo servidor (alfabeto de 31 símbolos, sem I/L/O).
const inviteCodeLength = 10;

/// Forma canônica do código digitado/colado: maiúsculas, sem hífen, espaço ou outro símbolo.
/// A validação real (alfabeto, existência) é do servidor.
String normalizeInviteCode(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Código em grupos de 5 para leitura ("ABCDE-FGHJK"). Códigos de outro tamanho ficam
/// como estão.
String formatInviteCode(String code) {
  final c = normalizeInviteCode(code);
  if (c.length != inviteCodeLength) return code;
  return '${c.substring(0, 5)}-${c.substring(5)}';
}

/// Versão mascarada para listas: só os 2 últimos caracteres aparecem.
String maskInviteCode(String code) {
  final c = normalizeInviteCode(code);
  if (c.length != inviteCodeLength) return '•••••-•••••';
  return '•••••-•••${c.substring(8)}';
}

enum InvitationStatus {
  pending,
  accepted,
  revoked,
  expired;

  static InvitationStatus parse(Object? v) => switch (v) {
        'pending' => InvitationStatus.pending,
        'accepted' => InvitationStatus.accepted,
        'expired' => InvitationStatus.expired,
        _ => InvitationStatus.revoked, // revogado e desconhecido: inativo
      };
}

/// Casa + papel concedidos pelo convite (`grants`).
class InviteGrant {
  const InviteGrant({required this.householdId, required this.role});

  final String householdId;
  final HouseholdRole role;

  @override
  bool operator ==(Object other) =>
      other is InviteGrant && other.householdId == householdId && other.role == role;

  @override
  int get hashCode => Object.hash(householdId, role);
}

/// `invitations/{code}` do owner. O `code` é o docId.
class Invitation {
  const Invitation({
    required this.code,
    required this.familyId,
    required this.grants,
    required this.status,
    required this.expiresAt,
    this.createdAt,
  });

  final String code;
  final String familyId;
  final List<InviteGrant> grants;
  final InvitationStatus status;
  final DateTime expiresAt;
  final DateTime? createdAt;

  /// `pending` com validade vencida conta como `expired` (o servidor só marca no aceite).
  InvitationStatus effectiveStatus(DateTime now) =>
      status == InvitationStatus.pending && !expiresAt.isAfter(now) ? InvitationStatus.expired : status;
}

/// Resposta de `createInvitation`. `link` é placeholder até existirem deep links.
class CreatedInvitation {
  const CreatedInvitation({required this.code, required this.link, required this.expiresAt});

  final String code;
  final String link;
  final DateTime expiresAt;
}

/// Resposta de `acceptInvitation`.
class AcceptedInvitation {
  const AcceptedInvitation({required this.familyId, required this.householdIds});

  final String familyId;
  final List<String> householdIds;
}
