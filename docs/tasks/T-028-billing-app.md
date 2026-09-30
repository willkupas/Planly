---
id: T-028
title: Billing no app (plano, compra e transferência)
status: todo
plan: 0003
depends_on: [T-027]
area: app
parallel_ok: false
---

## Pré-requisito (👤)
Faixa de teste interno na Play com contas de teste (licença de teste) para comprar sem cobrança real.

## Critérios de aceite (docs/specs/flutter-app.md telas #12, #21, #22)
- [ ] Tela `/family/plan`: plano atual, uso, cards Família / Família+ com limites vindos do entitlement e **preço real do Play** (nunca valor fixo no app)
- [ ] Compra via `in_app_purchase` com `obfuscatedAccountId = uid`; envia ao `verifyPurchase`; estados pendente/erro/cancelado tratados
- [ ] Criar nova Family paga (fluxo B) e fazer upgrade da Free (fluxo A)
- [ ] Transferência: owner indica membro; membro vê o convite, assina com a própria conta e conclui (fluxo C); cancelar/recusar
- [ ] Banner `frozen` com CTAs (owner reassina/transfere; membro avisa o owner) e modo de regularização (só remover membros/casas)
- [ ] Upsell final no Free (convites, casas, histórico) sem preços fixos
- [ ] Restaurar compras; link "gerenciar assinatura" da Play
- [ ] Testes de widget com `in_app_purchase` fake; roteiro manual com conta de teste
