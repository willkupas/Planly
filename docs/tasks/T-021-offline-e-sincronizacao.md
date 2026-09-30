---
id: T-021
title: Offline e sincronização (UX e teste crítico)
status: in-progress
plan: 0002
depends_on: [T-018, T-019]
area: app
parallel_ok: true
---

## Objetivo
Garantir o principal risco do projeto (brainstorm §73, §92): sincronização com duas pessoas e offline.

## Critérios de aceite
- [x] Indicador de sync visível (Salvo neste dispositivo → Sincronizando → Sincronizado) via `SnapshotMetadata` (`SyncIndicator` + `syncStatusFor` + `combineSyncMeta`; testes em `test/sync_ux_test.dart` e `test/write_failure_center_test.dart`)
- [x] Escritas rejeitadas ao sincronizar (ex.: família congelada enquanto offline): canal central `WriteFailureCenter` (`lib/core/sync/`), faixa global "N alterações não foram sincronizadas" com lista e **Descartar / Descartar tudo**. **Limite do SDK:** o Firestore já desfaz o efeito local quando o servidor recusa, então não há "linha fantasma" para marcar; antes da resposta a linha mostra o relógio (`hasPendingWrites`), depois da recusa vira aviso. "Descartar" só dispensa o aviso; não há "Tentar de novo" (o usuário refaz a ação).
- [x] Operações só-online (bootstrap, convites, casas, membros) mostram aviso claro quando offline e nunca travam o app (todas passam por `ensureOnline`; o `rename` da casa, único update direto, ganhou timeout de 10 s → `NetworkFailure` caso a rede caia depois da checagem)
- [x] Logout com escritas pendentes: aviso e "Sair mesmo assim" validados (`test/family_flow_test.dart` e `test/sync_ux_test.dart`; o logout também limpa os avisos de escritas recusadas)
- [x] **Teste crítico automatizado:** A online / B offline cria tarefa → B volta online → A recebe (+ activity do mesmo batch), executado contra o Emulator Suite (Rules reais) em `integration_test/offline_two_clients_test.dart`: **4/4 passando** (crítico; LWW em campos diferentes; LWW no mesmo campo, vence a escrita que chega por último; escrita offline recusada pela Rule de família congelada → `PermissionDeniedFailure` no ack e registro no `WriteFailureCenter`). Dois `FirebaseApp` no mesmo processo, sem UI; como rodar em `docs/testing/offline-dois-clientes.md`. O roteiro manual com dois aparelhos segue como complemento.
- [x] Roteiro de teste manual com dois aparelhos/emuladores documentado: `docs/testing/offline-dois-clientes.md`
- [x] Conflito last-write-wins documentado e testado (concluir x editar título): unitário em `test/lww_conflict_test.dart`; com Rules reais em `integration_test/offline_two_clients_test.dart` (executado, passando)

## Pontos vindos da T-019 (listas) para tratar aqui
- **Erro de Rules tardio é engolido:** `commitOptimistic` espera até 2 s; um erro de permissão que chegue depois só reverte o dado local, sem aviso. Precisa de um canal de "escrita rejeitada" visível (item "não sincronizado" + opção de descartar), valendo para tarefas, listas e itens.
- **`count()` agregado de pendentes só existe online:** offline o número some. Decidir se vale um fallback local.
- **Verificar no emulador:** `count()` com `limit(200)` passa na Rule `request.query.limit <= 200`; payload dos batches (lista/item/activity) aceito pelas Rules reais; teste A online / B offline cria item → reconecta → A recebe.
- **Arrastar item no aparelho:** validar o conflito entre scroll e handle de arrastar.

## Notas de implementação (T-021)
- `commitOptimistic` (listas) mantém o comportamento (espera 2 s; erro dentro do prazo volta ao chamador) e ganhou `onLateError`: o erro tardio deixa de ser engolido e vai ao canal central via `FirestoreListRepository.onRejected`. `TaskActions` também usa o canal (substitui `taskWriteFailureProvider`, removido). O snackbar do dashboard agora escuta o canal.
- **Decisão `count()` offline:** sem fallback local; offline o número de pendentes simplesmente não aparece (já é o comportamento). Contar localmente exigiria ler todos os itens.
- **Ainda a verificar no emulador/aparelho (não executado):** `count()` com `limit(200)` nas Rules; payload dos batches de listas/itens/activity nas Rules reais; cenário A online / B offline com item de lista; conflito scroll x handle de arrastar.
