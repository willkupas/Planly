# Plan 0001 — Fundação (Android)

**Objetivo:** sair do brainstorm para specs fechadas + projeto Flutter/Firebase rodando no Android com login Google, Family/casa criadas e regras seguras — base do MVP.

**Status:** ativo — tasks T-001 a T-015 criadas em `docs/tasks/` (todas `todo`)

## Fase A — Specs (sem código; paralelizável)

| Task | Descrição | Depende de |
|------|-----------|------------|
| T-001 | ADRs 0001–0005 a partir do brainstorm e decisões do CLAUDE.md (inclui Family como unidade de plano) | — |
| T-002 | Spec do modelo Firestore: Family (com `status` active/frozen), FamilyMember, Household, HouseholdAccess, Entitlement (`maxMembers`, `maxHouseholds`), tasks/lists/activity, índices, soft delete, schemaVersion → `docs/specs/data-model.md`. Fechar perguntas em aberto do CLAUDE.md | — |
| T-003 | Spec de Security Rules (matriz por role; campos protegidos: role, ownerId, limites do plano) → `docs/specs/security-rules.md` | T-002 |
| T-004 | Spec Flutter: telas, rotas GoRouter, providers, repositories, models → `docs/specs/flutter-app.md` | T-002 |
| T-005 | Spec Cloud Functions MVP (createFamily no primeiro login, createHousehold, inviteMember, acceptInvite, removeMember) | T-002, T-003 |

T-002 primeiro; T-003/T-004 em paralelo (2 subagentes); T-005 depois.

## Fase B — Infra (Sprint 1)

| Task | Descrição | Depende de |
|------|-----------|------------|
| T-006 | Criar projeto Flutter (Android), pastas feature-first, Material 3, i18n (ARB, pt-BR), Riverpod + GoRouter | T-004 |
| T-007 | Projetos Firebase dev/staging/prod + FlutterFire + flavors Android | T-006 |
| T-008 | Firebase Emulator Suite + `firebase.json` | T-007 |
| T-009 | CI GitHub Actions: analyze + test + build apk | T-006 |
| T-010 | App Check + Crashlytics + Analytics | T-007 |

## Fase C — Conta, Family e casa (Sprint 2)

| Task | Descrição | Depende de |
|------|-----------|------------|
| T-011 | Auth Google (AuthRepository extensível + splash/login) | T-007 |
| T-012 | Implementar Security Rules + testes de negação no emulator | T-003, T-008 |
| T-013 | Functions: criação da Family Free + casa inicial, gestão de casas/membros respeitando limites | T-005, T-008 |
| T-014 | Telas: dashboard, casas, membros | T-011, T-013 |
| T-015 | Convites (function + UI código/link com expiração); bloqueado no Free, upsell na UI | T-013, T-014 |

## Fora deste plan
Tarefas (Sprint 3), Listas (4), Offline (5), Notificações (6), Histórico (7), Billing (8), Qualidade (9), Play Store (10).

## Decisões tomadas
- applicationId: `app.with.planly` (flavors `.dev` / `.staging`).
- Região: `southamerica-east1`. i18n desde o T-006.
- Auth: só Google, AuthRepository extensível.
- **Family = unidade de plano; um owner por Family; cada usuário é owner de no máximo uma Family; pode ser convidado em outras.** Free = só o owner, 1 casa, sem convites. Família = 4 pessoas/3 casas. Família+ = 8 pessoas/casas ilimitadas.

- Acesso por casa: membro só vê casas vinculadas pelo owner (`HouseholdAccess`); owner vê todas.
- Sem limite de Families pagas por usuário; no máximo 1 Family Free por usuário. Pode ser membro de Families alheias.
- Cancelar não congela na hora (ativa até fim do período pago + grace da Play). Ao expirar sem transferência: `frozen` (somente leitura) por 90 dias, depois exclusão, com avisos.
- Transferência = convite ao membro, que assina com a própria conta; backend valida a compra e muda o ownership. Exclusão de conta do owner bloqueada enquanto houver outros membros.

## Progresso
- **Fase A concluída:** T-001 a T-005 (specs em `docs/specs/`). Próximo: Fase B (T-006 em diante).
- Ambiente local pronto (Flutter, Android Studio + emulador `planly_pixel`, Firebase CLI via wrapper Node 22).

## Decisões em aberto (produto)
Downgrade automático solo→Free, limite de histórico no Free e timezone ao viajar (ver data-model §8). Nenhuma bloqueante. Detalhes (estados da Family, jobs de expiração/exclusão, avisos) serão especificados na T-002/T-005.

## Riscos
- Rules mal modeladas → vazamento entre families: T-003/T-012 exigem testes de negação.
- Decisão comercial de preços em aberto: não bloqueia (limites vêm do Entitlement).
