# Plan 0003 — Conta, assinatura, qualidade e publicação

**Objetivo:** fechar o ciclo de vida da conta (exclusão de dados, LGPD), cobrar com segurança (Play Billing validado no servidor), elevar a qualidade e publicar na Play Store.
**Pré-requisito:** plan 0002 concluído (tarefas, listas, atividade, offline, lembretes).
**Status:** proposto — tasks criadas como `todo`.

## Ordem e paralelismo

| Task | Descrição | Sprint | Depende de | Exige você (👤) |
|---|---|---|---|---|
| T-025 | Exclusão de conta e de dados (LGPD): Function `deleteAccount` + tela + cascata | 8 | T-013 | — (testável em emulador) |
| T-026 | Transferência de ownership e ciclo de vida no servidor: `startOwnershipTransfer`/`cancelOwnershipTransfer`; estados `frozen`/`regularizeBy` | 8 | T-013, T-024 | Blaze (jobs) |
| T-027 | Billing no servidor: `verifyPurchase` (Play Developer API), RTDN (Pub/Sub), reconciliação diária, entitlement | 8 | T-026 | 👤 conta Play Console, produtos, service account, Blaze |
| T-028 | Billing no app: tela de plano (`/family/plan`), `in_app_purchase`, preços reais do Play, upsell final, transferência, modo regularização, banner `frozen` com CTAs | 8 | T-027 | 👤 faixa de teste na Play |
| T-029 | Qualidade: performance e custo do Firestore, acessibilidade, revisão de segurança (`/security-review`), teste de Crashlytics em release, App Check em enforcement | 9 | T-028 | 👤 registrar Play Integrity e ligar enforcement |
| T-030 | Publicação: assinatura de release (Play App Signing), ofuscação, política de privacidade e termos, Data safety, listing/screenshots, teste interno → produção | 10 | T-029 | 👤 conta Play (US$ 25), textos legais, domínio |
| T-017 | CI automático, proteção do `main`, Dependabot (já criada) | 10 | T-029 | 👤 configurações do GitHub |

Paralelizáveis: T-025 com T-026 · T-027 (servidor) com o esqueleto de T-028 (app) · T-029 com partes de T-030.

## Decisões a tomar (produto/negócio) antes da T-027
- Preços e produtos da Play (ex.: `family_monthly`, `family_plus_monthly`; anual?). O app mostra sempre o preço vindo da loja.
- Período de teste gratuito/oferta introdutória.
- Política de reembolso e cancelamento (texto) e o prazo de regularização (proposta: 30 dias) e de congelamento (90 dias, já decidido).

## Riscos
- Play Billing liga a assinatura à conta Google do comprador: transferência exige nova compra (já decidido, ADR 0005).
- Enforcement do App Check só pode ser ligado após ter build de release com Play Integrity registrado.
- Política de privacidade/LGPD precisa existir antes de publicar (requisito M12).
