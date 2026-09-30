---
id: T-004
title: Spec do app Flutter
status: done
plan: 0001
depends_on: [T-002]
area: docs
parallel_ok: true
---

## Objetivo
Produzir `docs/specs/flutter-app.md`.

## Critérios de aceite
- [x] Telas e fluxos MVP (splash, login, dashboard, casas, membros, criar tarefa rápida, listas, atividade, família/plano)
- [x] Rotas GoRouter e guards (auth, família frozen)
- [x] Providers, repositories, models por feature
- [x] Estados por tela: Loading/Empty/Success/Error/Offline + indicador de sync
- [x] Estratégia i18n (ARB, pt-BR) e tema Material 3
- [x] AuthRepository com provedores plugáveis
