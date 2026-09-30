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
- [x] Usuário: 2FA na conta Google (cobre Firebase e Play Console); secret scanning + push protection no GitHub
- [ ] Usuário: 2FA na conta GitHub (confirmar)
- [x] `AndroidManifest`: `allowBackup=false`, `usesCleartextTraffic=false` no release (R11); o manifest de debug libera cleartext só para os emuladores (T-008)
- [ ] Proteção do `main`, gitleaks e Dependabot — adiados para a T-017 (fim do projeto, por decisão do usuário)
