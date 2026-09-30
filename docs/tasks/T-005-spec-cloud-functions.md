---
id: T-005
title: Spec das Cloud Functions MVP
status: done
plan: 0001
depends_on: [T-002, T-003]
area: docs
parallel_ok: false
---

## Objetivo
Produzir `docs/specs/cloud-functions.md` com contratos (entrada, saída, erros, autorização, logs).

## Critérios de aceite
- [ ] bootstrapUser (1º login, Free + casa inicial), createHousehold, grantHouseholdAccess, inviteMember, acceptInvite, removeMember
- [ ] Validação de limites via Entitlement (`maxMembers`, `maxHouseholds`); convites bloqueados no Free
- [ ] Transferência de ownership (convite → aceite → validação de compra → troca)
- [ ] Jobs agendados: expiração → frozen, exclusão após 90 dias, avisos, limpeza de convites expirados
- [ ] Logging sem dados sensíveis; App Check exigido
