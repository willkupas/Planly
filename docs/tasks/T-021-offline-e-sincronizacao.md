---
id: T-021
title: Offline e sincronização (UX e teste crítico)
status: todo
plan: 0002
depends_on: [T-018, T-019]
area: app
parallel_ok: true
---

## Objetivo
Garantir o principal risco do projeto (brainstorm §73, §92): sincronização com duas pessoas e offline.

## Critérios de aceite
- [ ] Indicador de sync visível (Salvo neste dispositivo → Sincronizando → Sincronizado) via `SnapshotMetadata`
- [ ] Escritas rejeitadas ao sincronizar (ex.: família congelada enquanto offline): item marcado "não sincronizado" com opção de descartar
- [ ] Operações só-online (bootstrap, convites, casas, membros) mostram aviso claro quando offline e nunca travam o app
- [ ] Logout com escritas pendentes: aviso e "Sair mesmo assim" (já previsto na T-014; validar aqui)
- [ ] **Teste crítico automatizado:** A online / B offline cria tarefa → B volta online → A recebe (dois clientes contra o emulador)
- [ ] Roteiro de teste manual com dois aparelhos/emuladores documentado em `docs/`
- [ ] Conflito last-write-wins documentado e testado (concluir x editar título)

## Pontos vindos da T-019 (listas) para tratar aqui
- **Erro de Rules tardio é engolido:** `commitOptimistic` espera até 2 s; um erro de permissão que chegue depois só reverte o dado local, sem aviso. Precisa de um canal de "escrita rejeitada" visível (item "não sincronizado" + opção de descartar), valendo para tarefas, listas e itens.
- **`count()` agregado de pendentes só existe online:** offline o número some. Decidir se vale um fallback local.
- **Verificar no emulador:** `count()` com `limit(200)` passa na Rule `request.query.limit <= 200`; payload dos batches (lista/item/activity) aceito pelas Rules reais; teste A online / B offline cria item → reconecta → A recebe.
- **Arrastar item no aparelho:** validar o conflito entre scroll e handle de arrastar.
