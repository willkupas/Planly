---
id: T-020
title: Atividade (histórico da casa)
status: todo
plan: 0002
depends_on: [T-018]
area: app
parallel_ok: true
---

## Critérios de aceite
- [ ] Tela Atividade: "quem fez o quê", agrupada por dia, paginada (`limit` ≤ 50 + cursor por `createdAt`)
- [ ] Sem ranking/competição; "Pessoas" como histórico, não pontuação
- [ ] Free: apenas os últimos 7 dias (filtro por `createdAt` + nota de upsell)
- [ ] Snapshots (`actorName`, `targetTitle`) exibidos sem leituras extras; eventos de Function (`member_joined/left`) tratados
- [ ] Filtro por pessoa (índice `actorId` + `createdAt` já existe)
- [ ] Estados de tela; ARB; testes
