---
id: T-019
title: Listas e itens (compras)
status: in-progress
plan: 0002
depends_on: [T-014]
area: app
parallel_ok: true
---

## Objetivo
Listas compartilhadas (`data-model.md` §3.10, `flutter-app.md` telas 8–9).

## Critérios de aceite
- [x] Criar/renomear/excluir (soft) lista; tipos `shopping|general`
- [x] Itens em documentos separados; adicionar inline, marcar/desmarcar, editar nome, excluir (soft)
- [x] Pendentes antes dos concluídos; reordenar com `order` (double) sem reescrever a lista
- [x] Itens colaborativos: qualquer pessoa com acesso à casa edita/completa; soft delete por autor/admin/owner
- [x] Activity: `list_created`, `list_deleted`, `item_added`, `item_completed`, `item_deleted` (mesmo `WriteBatch` da ação)
- [x] Contagem de pendentes na lista sem ler todos os itens (`count()` com limite)
- [x] Modo leitura em família frozen; estados de tela; ARB
- [x] Testes unit/widget (app)
- [x] Integração no emulador (Rules reais) em `integration_test/lists_and_invitations_test.dart` (passando): criar lista/itens, completar por membro, `count()` agregado com `where` + `limit(200)` aceito pelas Rules (`pendingCount` = null sem acesso), stream de itens, activity no mesmo batch, soft delete, leitura negada a membro sem casa
- [ ] Testes unitários das Rules (`@firebase/rules-unit-testing`) específicos de listas: não feitos

## Implementação (app)
`lib/features/lists/{domain,data,application,presentation}`:
- `domain/`: `TaskList`, `ListItem`, `ListRepository`, `item_order.dart` (`nextOrder`, `planReorder`).
- `data/firestore_list_repository.dart`: `WriteBatch` (doc + `activityEntry`). Ids via `doc()` (offline).
- `application/list_providers.dart`: `householdListsProvider`, `listItemsProvider(listId)` (autoDispose), `pendingCountProvider(listId)`, `ListActions`, `canManageContentProvider`.
- `presentation/`: `ListsPage` (`/lists`), `ListDetailPage` (`/lists/:listId`), diálogos. Nova aba "Listas" (índice 1) no shell; `/lists` entrou em `Routes.contentRoutes`.
- Testes: `test/item_order_test.dart`, `test/list_repository_test.dart`, `test/lists_flow_test.dart` (widget, repository REAL sobre `fake_cloud_firestore` via `TestApp.listsDb`).

## Decisões e notas
- **Queries:** listas = `where deletedAt == null` + `limit(100)` (índice automático; ordenação por nome no cliente). Itens = `where deletedAt == null` + `orderBy completed, order` + `limit(200)`, que usa o índice composto já existente (`items: deletedAt, completed, order`). Nenhum índice novo.
- **Contagem de pendentes:** `count()` agregado no servidor (`where deletedAt == null, completed == false, limit 200`). Custo: 1 leitura por até 1000 entradas de índice por lista, sem ler itens, e o `limit` satisfaz a Rule `request.query.limit <= 200`. Só existe online (`AggregateSource.server`): offline o número some (mostra só o tipo). Recontado ao voltar do detalhe (`ref.invalidate`). Alternativa descartada: contador denormalizado na lista (exigiria escrever no doc da lista a cada item, contra spec §7 e conflito entre pessoas).
- **Escrita otimista:** `commit()` do Firestore offline só completa ao reconectar. `commitOptimistic` espera até 2 s: online, erros reais (Rules) viram `AppFailure` e aparecem no SnackBar; sem resposta, a escrita segue "salva neste dispositivo" sem travar a UI. Erro de Rules que chegue depois dos 2 s é engolido (o snapshot reverte o dado local e o `SyncIndicator` sai de "pendente"). Não usa `ensureOnline`.
- **`order`:** novo item = maior `order` + 1024. Arrastar (só entre pendentes; concluídos não arrastam): ponto médio entre vizinhos (1 escrita); se a precisão acabar, renumera só os pendentes (passo 1024) no mesmo batch. Empates de `order` (duas pessoas adicionando ao mesmo tempo) desempatam por id no cliente.
- **Permissões na UI (espelham as Rules):** criar/completar/editar/reordenar item = qualquer pessoa com acesso e família `active`; excluir item e renomear/excluir lista = autor, admin da casa (`Household.access[uid] == admin`) ou owner. Restaurar (admin) não tem UI.
- **frozen/deleting:** `familyWriteAccessProvider` falso => sem FAB, sem campo de adicionar, checkbox desabilitado, sem arrastar/excluir/editar; `ListActions` também recusa com `FAMILY_FROZEN`.
- Desmarcar item não gera activity (não existe tipo de cliente nas Rules). Renomear lista/item também não.
- Detalhe obtém o nome da lista do `householdListsProvider` (em vez de um `watchList` separado, previsto no spec §4.6): lista apagada por outra pessoa mostra "Esta lista não existe mais".
- Spec §4.6 previa debounce no rename: como rename é feito por diálogo (um write ao confirmar), não há escrita por tecla.
- `TestApp` (harness) ganhou `listsDb` + override de `listRepositoryProvider`.

## Falta / depende do emulador
- Testes de Rules (create/update de `lists`, `items`, `activity` com os mesmos payloads do repository) e integração real: A online / B offline cria item -> reconecta -> A recebe; confirmar que `count()` com `limit` passa na Rule e que o payload do `WriteBatch` é aceito pelas Rules reais.
- Validação manual de arrastar no aparelho (gesto de scroll x drag handle).
- Atalho do dashboard para a aba Listas (opcional; dashboard é do agente de tarefas).
