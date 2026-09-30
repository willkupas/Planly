---
id: T-003
title: Spec de Security Rules
status: done
plan: 0001
depends_on: [T-002]
area: docs
parallel_ok: true
---

## Objetivo
Produzir `docs/specs/security-rules.md`.

## Critérios de aceite
- [x] Matriz ler/criar/editar/excluir por role (owner/admin/member) e por vínculo à casa (HouseholdAccess)
- [x] Writes bloqueados quando `family.status = frozen`
- [x] Campos protegidos do cliente: role, ownerId, status, limites do plano, entitlement
- [x] Operações que só Functions fazem (convites, membros, casas, plano)
- [x] Lista de testes de negação (acesso cruzado entre families/casas)
