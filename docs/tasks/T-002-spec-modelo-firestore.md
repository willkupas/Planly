---
id: T-002
title: Spec do modelo Firestore
status: todo
plan: 0001
depends_on: []
area: docs
parallel_ok: false
---

## Objetivo
Produzir `docs/specs/data-model.md`.

## Critérios de aceite
- [ ] Collections/documentos/campos: User, Family (`status` active/frozen, `frozenAt`), FamilyMember, Household, HouseholdAccess, Entitlement (`maxMembers`, `maxHouseholds`), Invitation, Task, TaskList/Item, ActivityEvent, Device
- [ ] Caminhos definitivos (ex.: `/families/{f}/households/{h}/...`) sem coleções globais expostas
- [ ] Índices necessários
- [ ] Soft delete, timestamps, `schemaVersion`, IDs gerados
- [ ] Máquina de estados da Family: active → (expiração) frozen → (90 dias) exclusão; frozen → active via transferência
- [ ] Transferência de ownership e regra "1 Family Free por usuário, N pagas"
- [ ] Task Definition vs Occurrence (campos previstos, implementação na Fase 2)
