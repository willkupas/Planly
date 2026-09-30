---
id: T-018
title: Tarefas (criar, listar, editar, concluir)
status: in-progress
plan: 0002
depends_on: [T-014]
area: app
parallel_ok: true
---

## Objetivo
Implementar tarefas conforme `docs/specs/data-model.md` §3.9, `docs/specs/flutter-app.md` (telas 4–7) e as Rules (T-012).

## Critérios de aceite
- [x] Tarefa rápida: `+` -> texto -> ✓ (`status=pending`, `schedule=null`, `assignedTo=usuário`), meta ≤ 3 toques (2 toques: FAB + ✓; campo já focado)
- [x] "Mais opções": descrição, data/hora (`schedule` em UTC + `timezone` do aparelho), responsável (membros com acesso à casa, owner incluso, ou "Qualquer pessoa"), notificar
- [x] Dashboard: Hoje / Próximas / Minhas tarefas (toggle) / Sem data / Concluídas recentes (queries com `limit` e índices do data-model §5)
- [x] Detalhe/edição; concluir e reabrir (`completedAt/By` coerentes com as Rules); soft delete
- [x] Activity no mesmo `WriteBatch` (`task_created/assigned/completed/reopened/updated/deleted`)
- [x] Permissões na UI: member edita o que criou e conclui tarefa atribuída a ele ou a "qualquer pessoa"; admin/owner tudo; família frozen = somente leitura
- [x] Estados Loading/Empty/Error/Offline; textos via ARB
- [x] Testes unit/widget (repository com `fake_cloud_firestore`; fluxos com `FakeTasks`)
- [ ] Teste de integração com emulador das Rules no fluxo criar → concluir (depende do emulador; ver "Falta")

## Notas de implementação (lado do app)
- **Camadas** em `lib/features/tasks/`: `domain/` (`Task`, `TaskSchedule`, `TaskNotification`, `TaskDraft`, `TaskScope`, `TaskWrite`, `TaskRepository`), `data/firestore_task_repository.dart` (única parte com SDK), `application/` (`task_providers.dart`: repositório, escopo, filtro, streams do dashboard, `taskAccessProvider`, `assigneeCandidatesProvider`, `TaskActions`; `dashboard_groups.dart`: Hoje/Próximas), `presentation/` (`quick_add_sheet`, `task_form`, `task_tile`, `task_detail_page`). Dashboard em `lib/features/household/presentation/dashboard_page.dart`.
- **Escrita offline-first**: cada mutação é um `WriteBatch` (tarefa + `activityEntry(...)` de `features/activity/data/activity_entry.dart`). O repositório devolve `TaskWrite{id, ack}`; a UI NÃO aguarda o `ack` (offline ele só completa ao reconectar). `TaskActions` acompanha o `ack` em segundo plano e, se o servidor recusar (Rules/`permission-denied`), publica em `taskWriteFailureProvider` -> SnackBar amigável no dashboard; o Firestore desfaz o efeito local. Não usa `ensureOnline`.
- **Doc da tarefa** (create): chaves exatas exigidas pelas Rules; `description` só é gravada se não vazia; `recurrence=null`; ids via `doc()` sem argumento. Update grava só os campos que mudaram + `updatedAt` (whitelist das Rules); soft delete grava só `deletedAt` + `updatedAt`; concluir = `status/completedAt(serverTimestamp)/completedBy(uid)/updatedAt`; reabrir = `status` + `completedAt/By = null`.
- **Activity**: `task_created`, `task_completed`, `task_reopened`, `task_deleted`; na edição, `task_updated` se título/descrição/agenda/notificação mudaram e `task_assigned` se o responsável mudou (ambos se os dois).
- **Queries** (sempre `limit`, Rules exigem ≤ 100): agendadas `deletedAt==null, status==pending, orderBy schedule.scheduledAt` (+ `assignedTo==uid` no toggle "Minhas": índices 1 e 2 do data-model §5), limit 100; sem data `deletedAt==null, status==pending, schedule==null` (só igualdades, sem índice composto), limit 50; concluídas `deletedAt==null, status==done, orderBy completedAt desc`, limit 20. Motivo da divisão: `orderBy schedule.scheduledAt` exclui docs com `schedule=null` (tarefa rápida), por isso a query separada "Sem data". 3 listeners no dashboard (autoDispose); detalhe usa `taskProvider(id)` autoDispose.
- **Índice adicionado** em `firebase/firestore.indexes.json`: `tasks (deletedAt ASC, status ASC, completedAt DESC)` para "Concluídas recentes". Precisa de deploy (`firebase deploy --only firestore:indexes`) em dev/staging/prod; o emulador não exige.
- **Permissões de UI** (`TaskAccess`, espelha as Rules): criar = família `active` + acesso; editar/excluir = autor, admin da casa ou owner; concluir/reabrir = quem pode editar, ou `assignedTo` null/eu. Frozen/deleting: sem FAB, checkbox desabilitado, campos desabilitados, sem salvar/excluir/concluir.
- **Detalhe** (`/home/task/:taskId`, sub-rota de `/home`): campos desabilitados sem permissão; "Salvar" só aparece com alterações; campos não tocados acompanham versões novas vindas do servidor (`TaskFormController.rebase`). Horário inalterado preserva o `timezone` original; horário novo usa o IANA do aparelho (`deviceTimezoneProvider`, fallback `UTC`).
- **Sync por tarefa**: streams com `includeMetadataChanges: true`; ícone de relógio na linha quando `hasPendingWrites`. `SyncIndicator` do dashboard combina casas + tarefas.
- **Testes**: `test/task_repository_test.dart` (17: chaves do create, activity por tipo, patches mínimos, queries/ordem/filtros), `test/task_flow_test.dart` (24 widget: criar em 2 toques, teclado, mais opções, responsáveis, offline, erro de Rules no ack, seções, toggle Minhas, Empty/Error, concluir/reabrir, editar, excluir, permissões member/admin/owner, frozen), `test/support/fake_tasks.dart` (+ override no `harness.dart`).

## Desvios da spec (opção mais simples/restritiva)
- Sem *undo* de exclusão por SnackBar: restaurar é só admin/owner pelas Rules (taskRestore) e não há UI de restaurar ainda.
- "Concluídas recentes" no toggle "Minhas" é filtrada no cliente (as 20 mais recentes da casa), para não criar mais um índice `assignedTo + completedAt`.
- Limites: até 100 pendentes com data e 50 sem data por casa aparecem no dashboard (sem paginação no MVP).
- Lembretes (`notification.enabled/offsetMinutes`) só são gravados aqui; o agendamento fica para T-022/T-023.
- Debounce de edição não foi necessário: o detalhe só grava ao tocar em "Salvar".
- Listas no dashboard continuam placeholder ("Em breve") por decisão de coordenação (T-019).

## Falta (depende de integração/teste manual)
- Teste de integração em `integration_test/` com emulador (Auth + Firestore + Rules reais): criar -> concluir -> reabrir -> editar -> excluir e verificar activity; A online / B offline cria tarefa -> volta online -> A recebe. Valida de fato as Rules contra o payload do `FirestoreTaskRepository` (hoje só o teste de repository com `fake_cloud_firestore` confere as chaves).
- Deploy do novo índice de `tasks`.
- Teste manual em aparelho: teclado/foco da sheet, pickers de data/hora, comportamento offline real.
