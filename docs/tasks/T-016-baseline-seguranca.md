---
id: T-016
title: Baseline de segurança do repositório e do app
status: in-progress
plan: 0001
depends_on: [T-006]
area: ci
parallel_ok: true
---

## Objetivo
Cumprir os requisitos de `docs/security.md` que já dá para atender na fundação.

## Critérios de aceite
- [x] `docs/security.md` com requisitos mínimos e recomendados
- [x] `.gitignore` bloqueia segredos, chaves e configs Firebase
- [x] `scripts/check-secrets.sh` + hook `.githooks/pre-commit` ativo; testado com segredo falso
- [x] Auditoria do histórico atual: nenhum segredo encontrado
- [x] Regra "verificar antes de commitar" no CLAUDE.md
- [ ] Usuário: ativar 2FA (Google, GitHub, Play Console), secret scanning + push protection e proteção do `main` no GitHub
- [x] `AndroidManifest`: `allowBackup=false`, `usesCleartextTraffic=false` (R11). Nota: o debug com hot reload usa cleartext local; se o `flutter run` falhar, criar `src/debug/AndroidManifest.xml` liberando só o debug
- [ ] CI com gitleaks e Dependabot (junto da T-009)
