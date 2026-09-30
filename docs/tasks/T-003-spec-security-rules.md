---
id: T-003
title: Spec de Security Rules
status: todo
plan: 0001
depends_on: [T-002]
area: docs
parallel_ok: true
---

## Objetivo
Produzir `docs/specs/security-rules.md`.

## Critérios de aceite
- [ ] Matriz ler/criar/editar/excluir por role (owner/admin/member) e por vínculo à casa (HouseholdAccess)
- [ ] Writes bloqueados quando `family.status = frozen`
- [ ] Campos protegidos do cliente: role, ownerId, status, limites do plano, entitlement
- [ ] Operações que só Functions fazem (convites, membros, casas, plano)
- [ ] Lista de testes de negação (acesso cruzado entre families/casas)
