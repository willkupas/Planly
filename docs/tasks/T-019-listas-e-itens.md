---
id: T-019
title: Listas e itens (compras)
status: todo
plan: 0002
depends_on: [T-014]
area: app
parallel_ok: true
---

## Objetivo
Listas compartilhadas (`data-model.md` §3.10, `flutter-app.md` telas 8–9).

## Critérios de aceite
- [ ] Criar/renomear/excluir (soft) lista; tipos `shopping|general`
- [ ] Itens em documentos separados; adicionar inline, marcar/desmarcar, editar nome, excluir (soft)
- [ ] Pendentes antes dos concluídos; reordenar com `order` (double) sem reescrever a lista
- [ ] Itens colaborativos: qualquer pessoa com acesso à casa edita/completa; soft delete por autor/admin/owner
- [ ] Activity: `list_created`, `list_deleted`, `item_added`, `item_completed`, `item_deleted`
- [ ] Contagem de pendentes na lista sem ler todos os itens (contador agregado ou `count()` com limite)
- [ ] Modo leitura em família frozen; estados de tela; ARB
- [ ] Testes unit/widget e de Rules no emulador
