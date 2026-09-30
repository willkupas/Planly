---
id: T-004
title: Spec do app Flutter
status: todo
plan: 0001
depends_on: [T-002]
area: docs
parallel_ok: true
---

## Objetivo
Produzir `docs/specs/flutter-app.md`.

## Critérios de aceite
- [ ] Telas e fluxos MVP (splash, login, dashboard, casas, membros, criar tarefa rápida, listas, atividade, família/plano)
- [ ] Rotas GoRouter e guards (auth, família frozen)
- [ ] Providers, repositories, models por feature
- [ ] Estados por tela: Loading/Empty/Success/Error/Offline + indicador de sync
- [ ] Estratégia i18n (ARB, pt-BR) e tema Material 3
- [ ] AuthRepository com provedores plugáveis
