---
id: T-026
title: Transferência de ownership e ciclo de vida no servidor
status: todo
plan: 0003
depends_on: [T-013, T-024]
area: functions
parallel_ok: true
---

## Pré-requisito (👤)
Blaze (jobs agendados) para o que roda em produção; em dev tudo é testável no emulador chamando as funções diretamente.

## Critérios de aceite (docs/specs/cloud-functions.md §2.8, §4.1; ADR 0005)
- [ ] `startOwnershipTransfer({familyId, toUid})` (owner; destinatário é membro ativo; `pendingTransfer` com validade de 7 dias; um pendente por vez — `TRANSFER_PENDING`) e `cancelOwnershipTransfer` (owner cancela ou destinatário recusa)
- [ ] Conclusão da transferência dentro do `verifyPurchase` (T-027): troca `ownerId`, roles, substitui `billing/subscription`, revoga convites pendentes, leva a família a `active`
- [ ] Estado `frozen` (somente leitura) e saída dele por reassinatura do owner ou transferência; `deleteAfter = frozenAt + 90d`
- [ ] `regularizeBy` (plano reduzido com uso acima do novo limite): 30 dias em modo restrito; expirado → `frozen`
- [ ] Downgrade automático para Free quando a assinatura expira e só existe o owner com ≤ 1 casa
- [ ] Testes de integração no emulador com relógio injetável
