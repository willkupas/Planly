# Backlog (itens fora das tasks atuais)

Decisões do dono do produto que mudam o caminho, e itens a fazer mais tarde. Tasks formais ficam em `docs/tasks/`.

## Decisões
- **2026-09-30 — Distribuição:** sem publicação na Play por enquanto. O app será instalado **manualmente via APK**
  (flavor dev/prod, assinado com keystore local fora do git) até estar "redondo". Conta Play (US$ 25), produtos de
  assinatura e service account ficam para quando formos publicar (T-027..T-030). Consequência: billing real só entra
  depois; enquanto isso, planos pagos podem ser testados com o entitlement semeado/emulador.
- **Blaze:** liberado pelo dono para o projeto `dev` (T-023/T-024), com budget alert baixo.

## Backlog
- [ ] **Textos legais:** política de privacidade e termos — rascunhos em `docs/legal/*.rascunho.md`; revisão jurídica
      e preenchimento dos `[colchetes]` antes de publicar (T-030).
- [ ] **Domínio** (política publicada em URL, deep links de convite, `INVITE_LINK_BASE`): decidir antes da publicação.
- [x] Build de release para APK manual: feito, ver docs/testing/apk-manual.md (App Check desligado só no dev; testadores por `_testers`).
- [ ] Outros idiomas/regiões (ARB já preparado).
- [ ] iOS, web, widgets, gamificação (fase 3).
