# Planly — Passo a passo das tasks (Plan 0001)

Legenda: ✅ concluída · 🟡 parcial (resto adiado de propósito) · 🔄 em andamento · ⬜ a fazer · 👤 precisa de você
Detalhes de cada task: `T-NNN-*.md` nesta pasta. Plan: [0001](../plans/0001-fundacao-android.md).

## Fase A — Specs ✅
| | Task | Resultado |
|---|---|---|
| ✅ | T-001 ADRs | `docs/decisions/0001–0005` |
| ✅ | T-002 Modelo Firestore | `docs/specs/data-model.md` |
| ✅ | T-003 Security Rules (spec) | `docs/specs/security-rules.md` |
| ✅ | T-004 App Flutter (spec) | `docs/specs/flutter-app.md` |
| ✅ | T-005 Cloud Functions (spec) | `docs/specs/cloud-functions.md` |

## Fase B — Infraestrutura
| | Task | O que faz | Depende de |
|---|---|---|---|
| ✅ | T-006 Projeto Flutter | Projeto, tema, i18n, router, teste; APK abre no emulador | T-004 |
| 🔄 👤 | T-007 Firebase dev/staging/prod | Projetos, flavors, apps Android, SHA-1 e init do Firebase: **feito e testado no dev**. **Falta você:** budget alerts e restringir as chaves de API (passos na task) | T-006 |
| ✅ | T-008 Emulator Suite | Auth/Firestore/Functions locais testados; rules provisórias (nega tudo); app dev preparado para usá-los | T-007 |
| 🟡 | T-009 CI GitHub Actions (parcial) | Workflow **manual** pronto: scan de segredos, analyze, test, Functions, APK opcional. Automático em PR fica na T-017. **Ainda não rodou no GitHub** | T-006 |
| 🟡 👤 | T-010 App Check, Crashlytics, Analytics | Código pronto e testado no emulador. **Falta você**, só quando houver build de release: registrar Play Integrity e ligar o enforcement (passos na task) | T-007 |

| 🔄 👤 | T-016 Baseline de segurança | Scanner de segredos + hook (feito), `.gitignore` (feito). 2FA Google e secret scanning: feitos. **Falta você:** confirmar 2FA no GitHub. Proteção do `main` → T-017 | T-006 |

Ordem sugerida: T-006 → T-007 → (T-008, T-009, T-010 em paralelo). T-016 corre em paralelo e é requisito de tudo (ver `docs/security.md`).

## Fase C — Conta, Family e casa
| | Task | O que faz | Depende de |
|---|---|---|---|
| ✅ 👤 | T-011 Login com Google | Código, telas e 18 testes prontos. **Falta você:** testar o login real no emulador (conta Google no emulador) — passos na task | T-007 |
| ✅ | T-012 Implementar Security Rules | Regras reais + 65 testes (50 negações + 15 positivos) passando no emulator; falta só plugar no CI (T-017) | T-003, T-008 |
| ✅ | T-013 Functions de Family/casas/membros | 7 callables + 42 testes (8 unit + 34 integração) passando; App Check exigido na nuvem | T-005, T-008 |
| 🔄 | T-014 Telas de dashboard, casas e membros | Primeiro acesso → Family Free → dashboard; casas e membros com limites | T-011, T-013 |
| ⬜ | T-015 Convites | Código de 10 caracteres, 24 h, bloqueado no Free (upsell) | T-013, T-014 |

Ordem sugerida: T-011 e T-012 e T-013 em paralelo → T-014 → T-015.

## Etapas do fim do projeto (pré-release)
| | Task | O que faz |
|---|---|---|
| ⬜ 👤 | T-017 CI automático + proteção do `main` | CI em PR/push, testes das Rules no CI, gitleaks, Dependabot, actions por SHA, proteção do `main`, secrets de CI. Fazer **depois** das etapas de teste do app |

## Depois do plan 0001 (próximos plans)
Tarefas (Sprint 3) → Listas (4) → Offline (5) → Notificações (6) → Histórico (7) → Billing (8) → Qualidade (9) → Play Store (10).
Functions na nuvem e jobs agendados exigem plano **Blaze**: até a Sprint 5 usamos só emuladores.

## Onde você entra
- **T-007:** criar projetos no console Firebase e aceitar termos (eu guio cada passo).
- **Blaze:** só quando chegarmos à primeira necessidade de Functions na nuvem (Sprint 5–6).
- **Conta Google Play (US$ 25):** só na publicação (Sprint 10).
