---
id: T-017
title: CI automático em PR e proteção do main (pré-release)
status: todo
plan: 0001
depends_on: [T-009, T-012]
area: ci
parallel_ok: false
---

## Quando fazer
Ao **finalizar as etapas de teste do app** (antes do release / Sprint 9–10). Até lá o CI é manual (T-009) e o trabalho segue direto no `main` com commits pequenos.

## Critérios de aceite
- [ ] Workflow dispara em `pull_request` (e `push` no `main`), mantendo `workflow_dispatch`
- [ ] Testes das Security Rules com emulators no CI (T-012)
- [ ] gitleaks no CI (além do `scripts/check-secrets.sh`) e Dependabot (pub, npm, gradle, actions)
- [ ] Actions fixadas por SHA
- [ ] 👤 Proteção do `main`: PR obrigatório, CI verde exigido, sem force-push (requisito R1 de `docs/security.md`)
- [ ] 👤 Secrets de CI criados conforme necessidade (ex.: `GOOGLE_SERVICES_DEV_B64`), nunca no repositório
- [ ] Decidir workflow de release (build assinado fora do repositório; Play App Signing)

## Notas
Requisitos de segurança relacionados: M1, M13, R1, R2 em `docs/security.md`.
