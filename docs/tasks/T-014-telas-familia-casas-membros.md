---
id: T-014
title: Telas de dashboard, casas e membros
status: in-progress
plan: 0001
depends_on: [T-011, T-013]
area: app
parallel_ok: false
---

## Critérios de aceite
- [x] Fluxo primeiro acesso: login → Family Free + casa inicial → dashboard (app pronto, testado com fakes; falta rodar contra as Functions reais — ver "Falta")
- [x] Listar/criar casas e membros respeitando limites do plano (upsell no Free)
- [x] Estados Loading/Empty/Error/Offline e banner de Family `frozen`
- [x] Textos via ARB

## Notas de implementação (lado do app)

### Arquitetura
- Features `family` e `household` (+ `settings`, `auth/user_profile`) em `lib/features/*/{domain,data,application,presentation}`. Telas só falam com providers; SDKs só em `data/` e `core/firebase/` (`test/architecture_test.dart` continua verde).
- `core/firebase/callable_invoker.dart`: `CallableInvoker` (injetável) sobre `FirebaseFunctions.instanceFor(region: 'southamerica-east1')`; mapeia erro para `AppFailure` (`firebase_error_mapper.dart`). `AppFailure` ganhou `BusinessFailure(reason)`; `failure_message.dart` traduz cada `reason` do cloud-functions.md §1.1 via ARB. `invalid-argument` (reason = nome do campo) vira `UnknownFailure`.
- Novos núcleos: `core/connectivity` (`connectivityProvider`, `ensureOnline` = guarda só-online, espera a 1ª leitura), `core/sync/sync_status.dart` (regra pura do indicador), `core/sync/local_data_service.dart` (+ impl Firestore), `core/time/{clock,device_timezone}.dart`, `core/widgets/` (`AsyncValueView`, `LoadingSkeleton`, `EmptyState`, `ErrorState`, `OfflineBanner`, `SyncIndicator`, `runUiAction`, diálogos).
- Riverpod 3: `ProviderScope(retry: (_, _) => null)` em `bootstrap()` (sem retry automático silencioso; erro vira estado na UI com "Tentar de novo").

### Sessão, guards e contexto ativo
- `app/session/session_phase.dart`: `SessionPhase {loading, error, needsBootstrap, noAccess, ready}` (puro em `computeSessionPhase`, provider `sessionPhaseProvider`). `app/router/guards.dart`: `sessionGuard` (ordens 4–6 da spec §2.2) plugado em `postAuthGuardsProvider`; `RouterRefreshNotifier` agora também escuta a fase da sessão. Semântica nova: um guard que devolve a própria `location` significa "ficar aqui" (evita loop splash↔home).
- Bootstrap pendente = `users/{uid}.freeFamilyId == null` **e** sem memberships. `/no-access` só para rotas de conteúdo (`Routes.contentRoutes`, hoje `/home`); família/configurações seguem livres. Família `deleting` → `/no-access`; `frozen` **não** redireciona (modo leitura, `familyWriteAccessProvider`). Lista de casas vazia vinda só do cache não conta como "sem acesso" (evita falso `/no-access` antes do servidor).
- `/session-error` (extra à spec): falha ao ler perfil/memberships sem cache → tentar de novo ou sair.
- `activeContextProvider` (SharedPreferences, **chaves por uid**: `activeContext.<uid>.familyId/householdId`). Resolução validada: `activeFamilyIdProvider` (escolha guardada → Free do usuário → primeira membership) e `activeHouseholdProvider` (escolha guardada → primeira acessível). Troca de família/casa em bottom sheet a partir do seletor do dashboard (`showSwitchContextSheet`, sem rota `/switch`).
- `BootstrapController`: online-only, retry com backoff só para `NetworkFailure` (1s, 3s), demais erros por `reason` sem retry; após sucesso seleciona família/casa devolvidas e faz **upsert dos campos do cliente** em `users/{uid}` (`displayName/photoUrl/locale/timezone` + `updatedAt: serverTimestamp()`, best-effort) — fecha a pendência da T-011. Timezone IANA via `flutter_timezone`.

### Dados (conforme Rules reais de `firebase/firestore.rules`)
- Famílias do usuário: `users/{uid}/memberships` (limit 50). `families/{f}`: só `get/snapshots` de documento. `billing/entitlement` e `members` (where `status == active`, limit 50). Casas: owner lista todas (limit 50, filtra `deletedAt` no cliente); membro usa `where accessUids array-contains uid` (limit 50). `deletedAt == null` não vai no servidor para evitar índice composto com array-contains; casa excluída tem `accessUids` vazio (data-model §8 #7).
- Rename de casa = update direto `name + updatedAt`, tratado como só-online (offline a escrita ficaria pendente sem erro visível de Rules).
- Streams de casas usam `includeMetadataChanges: true` (alimenta `SyncIndicator`); demais, não.

### Telas entregues
Bootstrap, Dashboard (casa ativa + seletor + placeholders honestos "Em breve"; sem FAB até a Sprint 3), Família (hub: plano, `memberCount/maxMembers`, `householdCount/maxHouseholds`), Casas (criar com limite/upsell, renomear, excluir), Membros (owner: remover, acesso por casa em bottom sheet via `setHouseholdAccess`, convidar; membro: sair), banner frozen, `/no-access`, Configurações mínima (conta, idioma fixo pt-BR, sair). O botão de logout provisório saiu do dashboard; `SignOutController` foi removido (logout vive em `features/settings/application/session_actions.dart`).
- Logout: `hasPendingWrites` (`waitForPendingWrites` com timeout de 2s) → aviso + "Sair mesmo assim"; ao sair limpa o contexto ativo, `signOut` e depois `terminate()+clearPersistence()` (se falhar, agenda a limpeza para o próximo start: `runPendingFirestoreClear` no `bootstrap()`).

### Ponto de extensão da T-015 (convites)
`MembersPage._invite`: Free/sem `features.invites` → upsell; plano pago hoje só mostra "convites chegam na próxima etapa". A T-015 troca por `context.push(Routes.familyInvite)` (constante já reservada em `routes.dart`). Aceitar convite (`/join`) é liberado pelo guard de bootstrap pendente.

### Testes
`flutter analyze` limpo; `flutter test` 109/109. Novos: guards/fase de sessão (puro), mapeamento de erros, regra de sync, repositories com `fake_cloud_firestore` (dev_dependency nova) e callables via `CallableInvoker` fake, `BootstrapController` (retry/offline/reason), fluxos de widget (bootstrap, frozen, `/no-access`, deleting, contexto ativo/troca, limites Free/pago + upsell, owner vs membro, remover/sair/acesso por casa, offline, logout com/sem pendências). Fakes em `test/support/` (`FakeBackend` implementa os 3 repositories; `TestApp` monta o app com overrides).
APK dev (`flutter build apk --debug --flavor dev -t lib/main_dev.dart`) compila e abre no emulador `planly_pixel` sem crash.

### Dependências novas
`connectivity_plus`, `flutter_timezone` (app); `fake_cloud_firestore` (dev). O Gradle baixou o Android SDK Platform 35 no primeiro build após elas.

## Desvios da spec (opção mais simples/restritiva)
- Sem rota `/switch` (bottom sheet) e sem rota `/family/households/:id/access` (sheet dentro de Membros); `/family/plan` (upsell com compra) fica para a Sprint 8 — o upsell é um diálogo sem preços/limites fixos.
- Shell com só 2 abas (Início, Família); Listas/Atividade entram nas Sprints 3–4.
- Banner frozen é informativo (sem CTA de reassinar/transferir: dependem de billing/transferência).
- `/no-access` também é destino de `SessionPhase.noAccess` para família `deleting`.

## Falta (depende de integração/teste manual)
- [ ] Integração com as Functions reais no Emulator Suite (T-013): `bootstrapUser` → `users/{uid}` + Family Free + casa; `createHousehold` (limite Free/Família), `deleteHousehold` (`LAST_HOUSEHOLD`), `setHouseholdAccess`, `removeMember`, `leaveFamily`. Conferir que `details.reason` chega ao app (o mapper lê `FirebaseFunctionsException.details['reason']`) e que o envelope `{ok:true,...}` inclui `familyId/householdId`.
- [ ] Conferir as queries contra as Rules reais no emulador: memberships, `households` (owner sem `where` e membro com `array-contains`), `members where status==active`, `users/{uid}` update com `updatedAt`. Se o emulador pedir índice para `members where status`, avisar (é índice de campo único, deve ser automático).
- [ ] Teste manual no emulador Android (dev, com Auth Emulator): primeiro login → dashboard; modo avião no bootstrap; troca de família/casa; logout com escrita pendente ("Sair mesmo assim") e verificar que o Firestore volta a funcionar no login seguinte (o `clearLocalData` faz `terminate()+clearPersistence()` na mesma sessão; se a instância nativa não reabrir com as settings do emulador, cair no fallback de limpar só no próximo start).
- [ ] Família `frozen`/`deleting` com seed real (banner, leitura só, sair da família em frozen).
