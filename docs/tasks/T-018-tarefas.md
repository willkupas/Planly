---
id: T-018
title: Tarefas (criar, listar, editar, concluir)
status: todo
plan: 0002
depends_on: [T-014]
area: app
parallel_ok: true
---

## Objetivo
Implementar tarefas conforme `docs/specs/data-model.md` §3.9, `docs/specs/flutter-app.md` (telas 4–7) e as Rules (T-012).

## Critérios de aceite
- [ ] Tarefa rápida: `+` → texto → ✓ (`status=pending`, `schedule=null`, `assignedTo=usuário`), meta ≤ 3 toques
- [ ] "Mais opções": descrição, data/hora (`schedule` em UTC + `timezone` do aparelho), responsável (membros com acesso à casa ou "Qualquer pessoa"), notificar
- [ ] Dashboard: Hoje / Próximas / Minhas tarefas (queries com `limit` e índices do data-model §5)
- [ ] Detalhe/edição; concluir e reabrir (`completedAt/By` coerentes com as Rules); soft delete
- [ ] Activity no mesmo `WriteBatch` (`task_created/assigned/completed/reopened/updated/deleted`)
- [ ] Permissões na UI: member edita o que criou e conclui tarefa atribuída a ele ou a "qualquer pessoa"; admin/owner tudo; família frozen = somente leitura
- [ ] Estados Loading/Empty/Error/Offline; textos via ARB
- [ ] Testes unit/widget; teste de integração com emulador das Rules no fluxo criar → concluir
