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
| 🟡 | T-009 CI GitHub Actions (parcial) | Workflow **manual** pronto: scan de segredos, analyze, test, Functions, APK opcional. Automático em PR fica na T-017. **Rodou no GitHub com sucesso (2026-09-30)** | T-006 |
| 🟡 👤 | T-010 App Check, Crashlytics, Analytics | Código pronto e testado no emulador. **Falta você**, só quando houver build de release: registrar Play Integrity e ligar o enforcement (passos na task) | T-007 |

| 🔄 👤 | T-016 Baseline de segurança | Scanner de segredos + hook (feito), `.gitignore` (feito). 2FA Google e secret scanning: feitos. **Falta você:** confirmar 2FA no GitHub. Proteção do `main` → T-017 | T-006 |

Ordem sugerida: T-006 → T-007 → (T-008, T-009, T-010 em paralelo). T-016 corre em paralelo e é requisito de tudo (ver `docs/security.md`).

## Fase C — Conta, Family e casa
| | Task | O que faz | Depende de |
|---|---|---|---|
| ✅ 👤 | T-011 Login com Google | Código, telas e 18 testes prontos. **Falta você:** testar o login real no emulador (conta Google no emulador) — passos na task | T-007 |
| ✅ | T-012 Implementar Security Rules | Regras reais + 65 testes (50 negações + 15 positivos) passando no emulator; falta só plugar no CI (T-017) | T-003, T-008 |
| ✅ | T-013 Functions de Family/casas/membros | 7 callables + 42 testes (8 unit + 34 integração) passando; App Check exigido na nuvem | T-005, T-008 |
| ✅ | T-014 Telas de dashboard, casas e membros | App + 7 testes de integração no emulador (Functions e Rules reais) passando. Só não provado: modo avião durante o bootstrap |
| ✅ | T-015 Convites | Servidor (57 testes), telas (testes de widget) e fluxo real no emulador (criar, aceitar, revogar, limites) provados. Sem teste de UI real com dois aparelhos |

Ordem sugerida: T-011 e T-012 e T-013 em paralelo → T-014 → T-015.

## Etapas do fim do projeto (pré-release)
| | Task | O que faz |
|---|---|---|
| ⬜ 👤 | T-017 CI automático + proteção do `main` | CI em PR/push, testes das Rules no CI, gitleaks, Dependabot, actions por SHA, proteção do `main`, secrets de CI. Fazer **depois** das etapas de teste do app |

## Plan 0002 — Conteúdo do app (tarefas, listas, atividade, offline, notificações)
Plan: [0002](../plans/0002-conteudo-tarefas-listas.md). Começa quando a T-014 e a T-015 terminarem.
| | Task | O que faz | Depende de |
|---|---|---|---|
| ✅ | T-018 Tarefas | App, Rules reais e cenário offline provados. Falta deploy do índice novo de `tasks` (na nuvem) e teste manual de teclado e datas |
| ✅ | T-019 Listas e itens | App + Rules reais provadas (incl. `count()` com limit). Falta só testar o arrastar num aparelho |
| ✅ | T-020 Atividade | Aba com histórico por dia, paginado, filtro por pessoa; Free = 7 dias. Testes de widget e repository |
| ✅ | T-021 Offline e sincronização | Canal central de escritas rejeitadas + faixa global; **teste crítico A online / B offline passou 4/4 no emulador** (dois clientes). Roteiro manual com 2 aparelhos como complemento |
| ✅ 👤 | T-022 Lembretes locais | Reconciliação por stream, alarme inexato (sem permissão de alarme exato), permissão pedida em Configurações. **Falta você:** roteiro manual de 8 passos num aparelho |
| 🟡 👤 | T-023 Push de eventos (FCM) | Triggers (tarefa criada/atribuída/concluída, item) + token + toque abre o destino; testes passando. **Falta você:** deploy das Functions no `dev` (Blaze já ativo), `google-services.json` e teste em dois aparelhos | T-018, T-019 |
| 🟡 👤 | T-024 Jobs agendados | `lifecycleJob`, `purgeJob`, `cleanupJob` com relógio injetável; testes no emulador passando. **Falta:** deploy na nuvem (Scheduler) e ligar os avisos ao push | T-013, T-015 |

Paralelizáveis: T-018 + T-019 · T-020 + T-021 · T-022 + T-023 + T-024.

## Plan 0003 — Conta, assinatura, qualidade e publicação
Plan: [0003](../plans/0003-conta-assinatura-publicacao.md). Começa quando o plan 0002 terminar.
| | Task | O que faz | Depende de |
|---|---|---|---|
| ✅ 👤 | T-025 Exclusão de conta (LGPD) | Função `deleteAccount` (12 testes novos no emulador) + tela com confirmação dupla e reautenticação (16 testes). **Falta você:** testar a reautenticação com o Google real (junto do login, T-011) |
| ⬜ 👤 | T-026 Transferência e ciclo de vida | Transferir ownership, `frozen`, regularização 30 dias. **Exige Blaze** | T-013, T-024 |
| ⬜ 👤 | T-027 Billing no servidor | `verifyPurchase`, RTDN, reconciliação. **Exige conta Play, produtos, service account** | T-026 |
| ⬜ 👤 | T-028 Billing no app | Tela de plano, compra, transferência, preços reais do Play | T-027 |
| ⬜ 👤 | T-029 Qualidade e segurança | Custo, performance, acessibilidade, `/security-review`, **ligar App Check** | T-028 |
| ⬜ 👤 | T-030 Publicação na Play Store | Assinatura de release, política de privacidade, Data safety, teste interno → produção | T-029 |

## No fim de tudo
A T-017 (CI automático, proteção do `main`, Dependabot) fecha o projeto antes do lançamento.
Functions na nuvem e jobs agendados exigem plano **Blaze**: até a T-023 usamos só emuladores.

## Decisões recentes (2026-09-30)
- **Sem publicação por enquanto:** app instalado via APK manual; Play/billing só depois (ver [backlog](../backlog.md)).
- Índices do Firestore já publicados no `dev`. 2FA do GitHub e budget/chaves de API: feitos.
- Rascunhos de política de privacidade e termos em `docs/legal/`.

## Onde você entra (resumo)
- **Agora, se quiser:** testar o login real com Google no emulador (T-011), o roteiro de lembretes num aparelho (T-022) e confirmar o 2FA do GitHub (T-016).
- **Blaze:** quando chegarmos à T-023 (push) e T-024 (jobs). Eu explico os passos e o custo antes.
- **Conta Google Play (US$ 25), produtos e service account:** a partir da T-027 (billing) e na publicação (T-030).
- **Textos legais** (política de privacidade, termos) e **domínio:** antes da publicação.
- **Console Firebase:** restringir as chaves de API e configurar budget alerts (T-007); ligar o enforcement do App Check (T-029).
