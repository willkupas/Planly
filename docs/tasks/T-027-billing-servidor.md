---
id: T-027
title: Billing no servidor (Play Billing)
status: todo
plan: 0003
depends_on: [T-026]
area: functions
parallel_ok: false
---

## Pré-requisitos (👤) — não comece sem isto
- Conta de desenvolvedor Google Play (US$ 25) com o app criado e os produtos de assinatura cadastrados
- Projeto Blaze e uma **service account** com acesso à Play Developer API (chave só no Secret Manager, nunca no repositório)
- Decisões de produto do plan 0003 (preços/produtos)

## Critérios de aceite (docs/specs/cloud-functions.md §2.9, §3.1, §4.4; ADR 0005; security M8)
- [ ] `verifyPurchase({productId, purchaseToken, familyId?, familyName?})`: valida na Play Developer API (`purchases.subscriptionsv2.get`), confere `obfuscatedExternalAccountId == uid`, faz `acknowledge`, grava `billing/subscription` (só `purchaseTokenHash`) e `billing/entitlement`; fluxos A (upgrade da Free), B (nova Family paga), C (reassinar / concluir transferência)
- [ ] Token de compra ligado a uma única família (reuso em outra → `failed-precondition`)
- [ ] `onPlayNotification` (Pub/Sub RTDN): reconsulta a Play (nunca confia no payload), atualiza estado/datas; reembolso/revogação expira na hora
- [ ] `reconcileBillingJob` diário como rede de segurança
- [ ] `PlayBillingClient` (interface + impl real + fake para testes/dev)
- [ ] Mudança de plano com uso acima do novo limite → `regularizeBy`
- [ ] Segredos no Secret Manager; logs sem token/e-mail
- [ ] Testes com o cliente fake no emulador (sem chamar a Play)
