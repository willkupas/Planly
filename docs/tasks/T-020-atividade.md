---
id: T-020
title: Atividade (histórico da casa)
status: done
plan: 0002
depends_on: [T-018]
area: app
parallel_ok: true
---

## Critérios de aceite
- [x] Tela Atividade: "quem fez o quê", agrupada por dia (Hoje/Ontem/data), paginada (20 por página, `limit` ≤ 50 + cursor `startAfterDocument` por `createdAt DESC`, botão "Carregar mais")
- [x] Sem ranking/competição; "Pessoas" como histórico, não pontuação (sem contagem por pessoa)
- [x] Free: apenas os últimos 7 dias (`createdAt >= agora-7d` na query) + nota de upsell no fim
- [x] Snapshots (`actorName`, `targetTitle`) exibidos sem leituras extras; eventos de Function (`member_joined/left`, `household_created`) tratados; tipo desconhecido -> texto genérico
- [x] Filtro por pessoa (índice `actorId` + `createdAt`, já existente)
- [x] Estados Loading/Empty/Error/Offline; `permission-denied` com mensagem amigável; ARB; testes

## Notas de implementação
- `lib/features/activity/`: `domain/` (`ActivityEvent`, `ActivityEventType`, `ActivityPage`, `ActivityRepository`), `data/firestore_activity_repository.dart` (leitura; `activity_entry.dart` segue como escritor), `application/` (`activityFeedProvider` AsyncNotifier autoDispose, `activityFilterProvider`, `activityPeopleProvider`, `activityRestrictedProvider`, `groupByDay`), `presentation/` (`ActivityPage`, textos por tipo).
- Nova aba "Atividade" no shell (ordem: Início, Listas, Atividade, Família) e rota `/activity`, incluída em `Routes.contentRoutes`.
- Leitura por página (`get()`), sem listener (spec §7). Como o shell mantém as abas vivas, a tela recarrega ao voltar para a aba (detecta via `TickerMode`) e há "tentar de novo" no Error. Offline lê do cache do Firestore.
- Paginação pede `limit+1` para saber se há próxima página sem leitura extra; `limit` é limitado a 50 (Rules).
- `Entitlement` ganhou `fullHistory` (lido de `features.fullHistory`; sem a flag, assume pelo plano: Free = restrito). Enquanto o entitlement não carrega, aplica a janela de 7 dias (mais restritivo) e recarrega quando chegar.
- Filtro por pessoa: chips só aparecem com 2+ pessoas; lista = owner + membros com acesso à casa (`household.access`); o autor atual aparece como "Você".
- Free é limite de UX (cliente): as Rules não impõem `fullHistory` (data-model §8, item 14); impõem só `limit <= 50`.

## Desvios / pontos em aberto
- Filtro por pessoa estava como "Fase 2 se índice existir" na spec flutter-app §1 #10; como o índice existe, entrou agora.
- Janela do Free definida como 7 dias (fecha a pendência da spec flutter-app §11 item 4 para a tela Atividade).
- Ícone "pendente" no evento só aparece se o doc vier do cache com escrita pendente (leitura por `get()` não acompanha o servidor em tempo real; recarregar atualiza).
- Testes: `test/activity_repository_test.dart` (repository + agrupamento), `test/activity_flow_test.dart` (tela). `test/support/harness.dart` ganhou `activityOverride` e o override do `activityRepositoryProvider`.
