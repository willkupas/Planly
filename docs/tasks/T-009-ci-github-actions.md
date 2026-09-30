---
id: T-009
title: CI no GitHub Actions (parcial — manual)
status: in-progress
plan: 0001
depends_on: [T-006]
area: ci
parallel_ok: true
---

## Objetivo
Pipeline de CI **disparado manualmente** por enquanto. Automação em PR/push e proteção do `main` ficam para a T-017, ao fim das etapas de teste do app (decisão do usuário).

## Critérios de aceite — feito (parcial)
- [x] `.github/workflows/ci.yml` com gatilho **apenas** `workflow_dispatch`; permissões mínimas (`contents: read`); YAML validado localmente
- [x] Job `secrets-scan`: `scripts/check-secrets.sh --all`
- [x] Job `flutter`: `pub get`, `gen-l10n`, `analyze`, `test`
- [x] Job `functions`: `npm ci`, `build`, `npm audit --audit-level=high`
- [x] Job `android-apk` (opcional, input `build_apk`): restaura `google-services.json` do flavor dev a partir do secret `GOOGLE_SERVICES_DEV_B64` e gera o APK debug como artefato (7 dias)
- [x] Cache de dependências (Flutter e npm)

## Adiado para a T-017 (fim do projeto)
- [ ] Gatilho `pull_request` e/ou `push` no `main`
- [ ] gitleaks e Dependabot
- [ ] Testes com emulators (Rules) no CI, depois da T-012
- [ ] Proteção do `main` exigindo CI verde

## Notas
- **Nunca executado no GitHub ainda:** só foi validada a sintaxe. Rodar uma vez em Actions → CI → Run workflow e ajustar o que falhar.
- Para o job de APK: 👤 criar o secret `GOOGLE_SERVICES_DEV_B64` (GitHub → Settings → Secrets and variables → Actions) com o base64 de `android/app/src/dev/google-services.json`. Nunca colar o conteúdo no chat.
- Actions fixadas por tag maior (`@v4`, `@v2`); fixar por SHA é recomendação para a T-017.
- Usar os outros flavors no CI exigirá secrets próprios (staging/prod) — só se necessário.
