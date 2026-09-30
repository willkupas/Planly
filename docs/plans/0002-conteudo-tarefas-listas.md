# Plan 0002 — Conteúdo: tarefas, listas, atividade, offline e notificações

**Objetivo:** entregar o valor do produto (tarefas e listas compartilhadas, funcionando offline, com histórico e lembretes) sobre a fundação do plan 0001.
**Pré-requisito:** plan 0001 concluído (Family/casas/membros/convites funcionando no emulador).
**Status:** proposto — tasks criadas como `todo`.

## Ordem e paralelismo

| Task | Descrição | Sprint | Depende de | Paralelizável com |
|---|---|---|---|---|
| T-018 | Tarefas: criar rápida, listar, detalhe/editar, concluir, atribuir, data/hora, soft delete (+ activity no batch) | 3 | T-014 | T-019 (após o esqueleto de repository) |
| T-019 | Listas e itens (compras): criar, itens colaborativos, reordenar, concluir | 4 | T-014 | T-018 |
| T-020 | Atividade: tela de histórico paginado, limite de 7 dias no Free, sem ranking | 7 | T-018 ou T-019 | T-021 |
| T-021 | Offline e sincronização: indicador de sync, escritas rejeitadas, teste crítico A online / B offline | 5 | T-018, T-019 | T-020 |
| T-022 | Lembretes (notificações locais) + canais Android + permissão | 6 | T-018 | T-023 |
| T-023 | Push de eventos compartilhados (FCM + triggers de Firestore) — **exige Blaze** | 6 | T-018, T-019 | T-022 |
| T-024 | Jobs agendados (lifecycle, purge, cleanup, avisos) — **exige Blaze** | 6–8 | T-013, T-015 | T-022 |

Depois deste plan: Billing (Sprint 8), Qualidade (Sprint 9), Play Store (Sprint 10) — tasks criadas ao abrir o plan 0003.

## Regras do bloco
- Toda query com `limit` (Rules negam sem ele).
- Conteúdo é client-direct e offline-first; activity vai no mesmo `WriteBatch` da ação.
- Família `frozen`: modo leitura (spec flutter-app §2.3).
- Blaze só quando chegar a T-023/T-024 (ativar só no `dev`, com budget alert — ação do usuário).

## Riscos
- Conflito de edição simultânea e ordenação de itens (mitigado por `order` double e docs separados).
- Lembrete local vs push duplicado (definir em T-022/T-023 qual é a fonte por tipo de evento).
