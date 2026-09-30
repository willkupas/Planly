# Spec — App Flutter (Android)

**Status:** rascunho para revisão · **Task:** T-004 · **Depende de:** `data-model.md` (T-002)

Fonte da verdade dos dados: `docs/specs/data-model.md`. Decisões: CLAUDE.md e ADRs 0002–0005. Este spec define telas, rotas, camadas, providers, estados, i18n, listeners, auth e testes. Não contém código do app.

## 1. Mapa de telas e fluxos (MVP)

| # | Tela | Conteúdo / ações | Só-online? |
|---|---|---|---|
| 1 | Splash | Inicializa Firebase/App Check, lê sessão. Sem UI de erro própria (vai p/ login ou bootstrap) | não |
| 2 | Login | Botão "Entrar com Google" (único provedor no MVP) | sim |
| 3 | Bootstrap (1º acesso) | Chama `createFamily` (Function). Resultado: Family Free + casa inicial. Estados: carregando / erro com "Tentar de novo" / sem internet com aviso claro | sim |
| 4 | Dashboard (Início) | Casa ativa no topo (seletor), "Hoje", "Próximas", "Minhas tarefas" (toggle), resumo de listas, FAB `+`, indicador de sync | não |
| 5 | Criar tarefa rápida | Bottom sheet: campo de texto → ✓ (`status=pending`, `schedule=null`, `assignedTo=currentUser`). Link "Mais opções" expande | não |
| 6 | Mais opções (na mesma sheet) | Descrição, data/hora (`schedule`), responsável (membros com acesso à casa ou "Qualquer pessoa"), notificar (`notification.enabled/offsetMinutes`). Recorrência: escondida no MVP (Fase 2) | não |
| 7 | Detalhe/edição de tarefa | Ver/editar campos, concluir/reabrir, excluir (soft delete), autor e datas | não |
| 8 | Listas | Lista de listas da casa (nome, tipo, contagem de pendentes), criar lista | não |
| 9 | Detalhe da lista | Itens (pendentes antes dos concluídos), adicionar item inline, marcar, reordenar (`order`), excluir | não |
| 10 | Atividade | Histórico paginado ("quem fez o quê"), filtro por pessoa (Fase 2 se índice existir); sem ranking/competição. No Free: limite de histórico (`features.fullHistory=false`) com nota de upsell | não |
| 11 | Família (hub) | Plano atual, uso (`memberCount/maxMembers`, `householdCount/maxHouseholds`), atalhos | leitura offline ok |
| 12 | Família > Plano | Detalhes do entitlement; **upsell no Free** (cards Família / Família+ com `maxMembers`/`maxHouseholds` vindos do entitlement, preço do Play); assinar → Play Billing → Function valida | sim |
| 13 | Família > Membros | Lista de membros (role, casas vinculadas). Owner: convidar, remover, transferir ownership, editar acesso por casa | ações: sim |
| 14 | Convidar | Owner escolhe casas (`grants` com role `admin/member`) → gera código/link (24h) → compartilhar (share sheet). Bloqueado no Free (mostra upsell) | sim |
| 15 | Entrar com código | Convidado digita código → Function `acceptInvitation` → vai para a família/casa | sim |
| 16 | Família > Casas | Lista de casas; owner: criar (respeita `maxHouseholds`), renomear, excluir (soft delete, 30 dias) | criar/excluir: sim |
| 17 | Acesso por casa | Para cada casa, membros vinculados e role (`admin|member`); owner altera (Function) | sim |
| 18 | Troca de família/casa ativa | Bottom sheet a partir do seletor do dashboard: famílias (de `users/{uid}/memberships`) → casas acessíveis (`accessUids array-contains uid`). Persiste a escolha em SharedPreferences | não |
| 19 | Configurações | Conta (nome, foto, e-mail), idioma (pt-BR; lista extensível), timezone (auto, editável), notificações, sair, excluir conta, versão/licenças | sair: não; excluir: sim |
| 20 | Excluir conta | Confirmação dupla; bloqueada com explicação se owner com outros membros (oferece "Transferir ownership") | sim |
| 21 | Banner Family frozen | Faixa fixa no topo de todas as telas da família: "Somente leitura — assinatura expirada. Exclusão em N dias." CTA: owner "Reassinar / Transferir"; membro "Avisar o owner" (informativo). Ver §2.3 | não |
| 22 | Aceitar transferência | Membro com `pendingTransfer.toUid == uid` vê card no hub → assina com a própria conta → Function conclui | sim |

### Fluxos principais
1. **Primeiro acesso:** Splash → Login → (sem família) Bootstrap → Dashboard. Sem internet: Bootstrap mostra estado Offline e bloqueia até reconectar (data-model §2.5).
2. **Acessos seguintes:** Splash → (sessão + família ativa em SharedPreferences) → Dashboard direto, lendo do cache.
3. **Convidado:** Login → (sem família própria ainda) Bootstrap cria a Free *e* o usuário pode usar "Entrar com código". Ordem: Bootstrap só cria a Free se `users/{uid}.freeFamilyId` for nulo; o código pode ser inserido logo após o login (ver §11 item 3).
4. **Tarefa rápida:** `+` → teclado abre já focado → digitar → ✓ → sheet fecha; tarefa aparece otimisticamente (escrita local). Meta: ≤ 3 toques.
5. **Concluir:** checkbox no item → update `status=done, completedAt=serverTimestamp, completedBy` + doc `activity` no mesmo `WriteBatch`.

## 2. Rotas GoRouter e guards

### 2.1 Tabela de rotas

| Path | Tela | Parâmetros |
|---|---|---|
| `/splash` | Splash | — |
| `/login` | Login | — |
| `/bootstrap` | Bootstrap 1º acesso | — |
| `/join` | Entrar com código | `?code=` opcional (deep link futuro) |
| `/` | Shell com `StatefulShellRoute` (bottom nav: Início, Listas, Atividade, Família) | — |
| `/home` | Dashboard (branch Início) | — |
| `/home/task/new` | Sheet de criar tarefa (rota de diálogo) | `?expand=1` |
| `/home/task/:taskId` | Detalhe/edição | `taskId` |
| `/lists` | Listas | — |
| `/lists/:listId` | Detalhe da lista | `listId` |
| `/activity` | Atividade | — |
| `/family` | Hub da família | — |
| `/family/plan` | Plano/upsell | — |
| `/family/members` | Membros | — |
| `/family/members/invite` | Convidar | — |
| `/family/households` | Casas | — |
| `/family/households/:householdId/access` | Acesso por casa | `householdId` |
| `/family/transfer` | Transferência de ownership | — |
| `/switch` | Troca de família/casa (modal) | — |
| `/settings` | Configurações | — |
| `/settings/delete-account` | Excluir conta | — |
| `/no-access` | "Sem acesso a esta casa" | `?householdId=` |

Família/casa ativas **não** vão no path; vêm do provider `activeContextProvider` (persistido). Motivo: bottom nav estável e deep links simples. Exceção: links de notificação usam `?familyId=&householdId=` em `/home/task/:taskId` e o guard ajusta o contexto ativo antes de entrar.

### 2.2 Guards (redirect global, ordem de avaliação)
O `GoRouter` usa `refreshListenable` ligado a um `RouterRefreshNotifier` que escuta `authStateProvider`, `bootstrapStateProvider` e `activeContextProvider`.

| Ordem | Condição | Destino |
|---|---|---|
| 1 | Auth ainda resolvendo | `/splash` |
| 2 | Não autenticado e rota ≠ `/login` | `/login` |
| 3 | Autenticado e rota = `/login`/`/splash` | `/home` (ou `/bootstrap` se pendente) |
| 4 | Bootstrap pendente (`users/{uid}.freeFamilyId == null` **e** sem memberships) e rota ∉ {`/bootstrap`,`/join`,`/settings*`} | `/bootstrap` |
| 5 | Rota com `householdId` (ou contexto ativo) sem `accessUids` contendo uid | `/no-access` |
| 6 | Família `frozen`/`deleting` | **não redireciona**: navega normalmente em modo leitura (ver 2.3); `deleting` → `/no-access` |

### 2.3 Modo leitura (Family frozen)
Não é rota, é estado: `familyWriteAccessProvider` (`bool`) = `family.status == active` **e** o usuário tem role de escrita na casa. Todas as telas de conteúdo leem esse provider para: esconder FAB `+`, desabilitar checkboxes/swipe/edição/reordenação, trocar botões de edição por visualização, e mostrar o banner (#21). As Rules são a barreira real; o cliente só evita tentativas inúteis. Ações permitidas em frozen: ler, trocar contexto, sair da família, reassinar (owner), aceitar transferência (membro convidado), configurações.

### 2.4 Regras extras
- Erro de permissão (`permission-denied`) em qualquer repositório → `AppFailure.permissionDenied` → UI oferece "Recarregar contexto"; se persistir, `/no-access`.
- Back button: dentro do shell volta ao branch raiz antes de sair do app.

## 3. Estrutura de pastas `lib/`

```
lib/
  main_dev.dart  main_staging.dart  main_prod.dart   # entry points por flavor (§10)
  app/
    app.dart                 # MaterialApp.router, tema, l10n
    router/                  # app_router.dart, guards.dart, routes.dart
    bootstrap.dart           # init Firebase, App Check, emuladores (dev), ProviderScope
    flavor.dart              # Flavor enum + AppConfig
  core/
    error/                   # AppFailure (sealed), mapeamento FirebaseException
    result/                  # Result/AsyncValue helpers
    firebase/                # providers: firestore, auth, functions, messaging (únicos que importam SDK fora de data/)
    time/                    # Clock abstrata, conversão UTC<->timezone IANA
    ids/                     # deviceId, gerador de IDs
    sync/                    # SyncStatus, hasPendingWrites helpers
    logging/                 # logger sem dados sensíveis
    theme/                   # ColorScheme, typography, componentes
    l10n_helpers/
    widgets/                 # AsyncValueView, SyncIndicator, OfflineBanner, EmptyState, ErrorState
  features/
    auth/          {data,application,domain,presentation}
    family/        {...}
    household/     {...}
    tasks/         {...}
    lists/         {...}
    activity/      {...}
    notifications/ {...}
    subscription/  {...}
    settings/      {presentation, application}   # sem domain próprio
  shared/                    # extensões, constantes, widgets genéricos sem regra de negócio
  l10n/                      # app_pt.arb (template), app_en.arb (futuro)
```

**Camadas (dependência só para dentro):**
- `presentation` (widgets, páginas, controllers de UI) → `application` (use cases/notifiers que orquestram) → `domain` (entidades puras, interfaces `Repository`, regras) ← `data` (implementações Firestore/Functions, DTOs).
- **Regra dura:** nada em `presentation/`, `application/`, `domain/` importa `cloud_firestore`, `firebase_auth`, `cloud_functions`. Só `features/*/data/` e `core/firebase/`. Verificável com lint de import (ex.: `custom_lint`/`import_lint` ou teste de arquitetura que varre `lib/` por imports proibidos — ver §10).
- `application` existe onde há orquestração (batch tarefa+atividade, bootstrap, aceitar convite); para CRUD simples o controller de presentation chama direto o repository via provider, sem use case vazio.

## 4. Por feature: models, repositories, providers

### 4.1 Modelagem (recomendação)
- **Entidades de domínio:** classes imutáveis com `freezed` (copyWith, igualdade, unions). Enums/uniões como `sealed class` ou enums `freezed` (`TaskSchedule`, `AppFailure`, `AuthState`).
- **DTOs (data/):** `json_serializable` + conversores de `Timestamp`↔`DateTime` UTC. Mapper DTO↔entidade explícito em `data/`. Entidade de domínio não conhece `Timestamp`.
- `schemaVersion` fica só no DTO; o mapper trata versões futuras (ignora campos desconhecidos).
- Campos 🔒 server são somente-leitura nas entidades; o repository não os inclui em writes (senão Rules negam).
- Geração: `build_runner`; arquivos `*.freezed.dart`/`*.g.dart` ignorados pelo lint.

### 4.2 auth
| Item | Definição |
|---|---|
| Domain | `AuthUser{uid, displayName, email, photoUrl}`, `AuthProviderId` (enum: `google`; futuro `password`, `apple`), `AuthState` (sealed: `Loading`, `SignedOut`, `SignedIn(AuthUser)`) |
| Repository | `AuthRepository` (ver §8); impl `FirebaseAuthRepository` com `AuthProviderAdapter`s |
| Providers | `authRepositoryProvider` (Provider), `authStateProvider` (StreamProvider<AuthState>, observa `authStateChanges`), `currentUserProvider` (Provider<AuthUser?>), `currentUidProvider` |
| Controllers | `SignInController` (AsyncNotifier<void>: `signIn(AuthProviderId)`), `SignOutController`, `DeleteAccountController` |

### 4.3 family
| Item | Definição |
|---|---|
| Domain | `Family` (id, name, ownerId, status, plan, memberCount, householdCount, frozenAt, deleteAfter, pendingTransfer), `FamilyMembership` (de `users/{uid}/memberships`: familyId, familyName, role, familyStatus, plan), `FamilyMember` (uid, role, status, displayName, photoUrl, joinedAt), `Entitlement` (plan, maxMembers, maxHouseholds?, features), `Invitation` (code, grants, status, expiresAt), `FamilyStatus`/`FamilyRole` enums |
| Repository | `FamilyRepository`: `watchMemberships(uid)`, `watchFamily(id)`, `watchMembers(id)`, `watchEntitlement(id)`, `watchMyInvitations(uid)` (owner), `updateFamilyName` (client), **callables:** `createFamily()`, `createInvitation(familyId, grants)`, `revokeInvitation(code)`, `acceptInvitation(code)`, `removeMember(familyId, uid)`, `leaveFamily(familyId)`, `startOwnershipTransfer(familyId, toUid)`, `cancelOwnershipTransfer`, `acceptOwnershipTransfer`, `updateMemberAccess(familyId, uid, grants)`. Impl: `FirestoreFamilyRepository` + `FamilyFunctionsClient` |
| Providers | `membershipsProvider` (StreamProvider<List<FamilyMembership>>), `activeContextProvider` (NotifierProvider<ActiveContext{familyId, householdId}>, persiste em SharedPreferences, valida contra memberships), `activeFamilyProvider` (StreamProvider<Family>, observa `watchFamily(activeFamilyId)`), `activeEntitlementProvider`, `isOwnerProvider`, `familyMembersProvider(familyId)` (autoDispose, só Família>Membros), `familyWriteAccessProvider` (§2.3), `bootstrapStateProvider` |
| Controllers | `BootstrapController` (AsyncNotifier: `createFamily` com retry/backoff manual), `InviteController`, `MemberActionsController`, `OwnershipTransferController` |

### 4.4 household
| Item | Definição |
|---|---|
| Domain | `Household` (id, name, access: Map<uid, HouseholdRole>, createdBy, deletedAt), `HouseholdRole` (`admin|member`) |
| Repository | `HouseholdRepository`: `watchAccessibleHouseholds(familyId, uid)` (query `accessUids array-contains uid`, `deletedAt == null`, limit), `watchHousehold(familyId, id)`, `rename` (client, se Rules permitirem), **callables:** `createHousehold`, `deleteHousehold`, `updateHouseholdAccess` |
| Providers | `accessibleHouseholdsProvider` (StreamProvider, observa família ativa + uid), `activeHouseholdProvider` (Provider derivado de `activeContext` + lista; se a casa ativa sumir → primeira acessível ou `/no-access`), `myHouseholdRoleProvider` (`admin|member|owner-implícito`), `canEditContentProvider(authorUid)` |
| Controllers | `HouseholdAdminController` (criar/renomear/excluir; verifica `maxHouseholds` localmente só para UX — backend decide) |

### 4.5 tasks
| Item | Definição |
|---|---|
| Domain | `Task` (id, title, description, createdBy, assignedTo?, status, schedule?, notification, completedAt?, completedBy?, deletedAt), `TaskSchedule` (`scheduledAt` UTC + `timezone` IANA), `TaskNotification{enabled, offsetMinutes}`, `TaskStatus`, `TaskDraft` (input de criação). `recurrence` fica `null`/ignorado no MVP (campo opaco preservado ao editar) |
| Repository | `TaskRepository`: `watchTasks(ctx, TaskFilter, limit)`, `watchTask(ctx, id)`, `create(ctx, draft)`, `update(ctx, id, patch)`, `complete`, `reopen`, `softDelete`. **Cada mutação escreve a tarefa + doc `activity` no mesmo `WriteBatch`** (data-model §2.3). Impl grava `serverTimestamp` em `createdAt/updatedAt/completedAt` |
| Providers | `tasksTodayProvider`, `tasksUpcomingProvider`, `myTasksProvider` (todos `StreamProvider.autoDispose.family` com `limit`; observam `activeContext`), `taskProvider(id)` (autoDispose, só no detalhe), `taskFilterProvider` (UI: todas/minhas) |
| Controllers | `QuickAddController` (Notifier: estado do texto + `submit()`), `TaskFormController` (campos de "Mais opções", validação título 1–200), `TaskActionsController` (completar/reabrir/excluir com undo via snackbar) |

Conversão de horário: a UI trabalha no timezone do usuário; o domínio recebe `DateTime` local + IANA e converte para UTC antes de gravar. `Clock` injetável nos testes.

### 4.6 lists
| Item | Definição |
|---|---|
| Domain | `TaskList` (id, name, type `shopping|general`, createdBy, deletedAt), `ListItem` (id, name, completed, completedBy?, completedAt?, order, createdBy) |
| Repository | `ListRepository`: `watchLists`, `watchList`, `createList`, `renameList`, `deleteList`; `watchItems(listId, limit)`, `addItem`, `toggleItem`, `renameItem`, `reorderItem` (recalcula `order` como ponto médio entre vizinhos; renumeração só se precisão esgotar), `deleteItem`. Mutações também escrevem `activity` (`list_created`, `item_added`, `item_completed`) no mesmo batch |
| Providers | `listsProvider`, `listProvider(id)`, `listItemsProvider(id)` (autoDispose; só com a tela aberta) |
| Controllers | `ListActionsController`, `ItemEditorController` (debounce, §7) |

### 4.7 activity
| Item | Definição |
|---|---|
| Domain | `ActivityEntry` (id, type, actorId, actorName, targetType, targetId, targetTitle, createdAt), `ActivityType` enum |
| Repository | `ActivityRepository`: `watchLatest(ctx, limit)`, `fetchPage(ctx, startAfter, limit)`. **Escrita de atividade não é exposta**: fica dentro dos repositories de tasks/lists (mesmo batch); `ActivityWriter` interno de `data/` monta o doc |
| Providers | `activityFeedProvider` (AsyncNotifier com paginação: lista acumulada + `loadMore()` com cursor; 1ª página via stream curto, demais via `get`), `activityFilterProvider` (por pessoa, opcional) |
| Controllers | Próprio `ActivityFeedNotifier` |

### 4.8 notifications
| Item | Definição |
|---|---|
| Domain | `DeviceRegistration` (deviceId, fcmToken, locale, timezone), `ReminderSchedule` (taskId, fireAt UTC) |
| Repository | `DeviceRepository` (grava `users/{uid}/devices/{deviceId}` no login e em `onTokenRefresh`; remove no logout), `LocalNotificationScheduler` (abstração sobre `flutter_local_notifications`: `schedule/cancel` por taskId) |
| Providers | `fcmTokenSyncProvider` (mantém o doc do device atualizado, vive com a sessão), `notificationPermissionProvider`, `reminderSyncProvider` (observa tarefas da casa ativa com `notification.enabled` e agenda/cancela locais — complementar, não a única fonte), `notificationRouteHandlerProvider` (mensagens FCM/cliques → `router.go` com `familyId/householdId/taskId`) |
| Controllers | `NotificationSettingsController` (permissão Android 13+ `POST_NOTIFICATIONS`, canal, horário) |

Lembretes pessoais = notificação local; eventos compartilhados = FCM enviado por Function (não há código de envio no app).

### 4.9 subscription
| Item | Definição |
|---|---|
| Domain | `SubscriptionInfo` (state, autoRenewing, expiresAt, productId — visível só ao owner), `PlanOffer` (plano, `productId`, preço localizado do Play, `maxMembers`, `maxHouseholds`) |
| Repository | `SubscriptionRepository`: `watchSubscription(familyId)` (owner), `loadOffers()` (via `in_app_purchase`), `purchase(offer, familyId)`, `restore()`; após compra envia o `purchaseToken` à Function `verifyPurchase(familyId, token)`; **nunca** grava entitlement no cliente |
| Providers | `subscriptionProvider` (autoDispose, só owner), `planOffersProvider`, `purchaseStreamProvider` |
| Controllers | `PurchaseController` (AsyncNotifier: `buy`, estados `idle/purchasing/verifying/success/error`). Entitlement muda só quando a Function atualizar o doc; a UI aguarda via stream |

## 5. Estados de tela e sync

### 5.1 Estados obrigatórios
Toda tela de dados usa o widget `AsyncValueView<T>` (core/widgets) com 5 slots:

| Estado | Condição | UI |
|---|---|---|
| Loading | `AsyncLoading` sem dado em cache | Skeleton/shimmer (não spinner de tela cheia) |
| Empty | dado carregado, lista vazia | Ilustração + texto + CTA (ex.: "Adicione sua primeira tarefa") |
| Success | dados | conteúdo; se `isFromCache` e offline, continua normal |
| Error | `AsyncError` | mensagem mapeada de `AppFailure` (i18n) + "Tentar de novo" |
| Offline | `connectivityProvider == offline` | **não bloqueia**: banner discreto "Sem conexão — alterações ficam salvas neste dispositivo". Ações só-online mostram aviso (ver 5.3) |

### 5.2 Indicador de sync
Os repositories expõem, junto do dado, `SyncMeta{hasPendingWrites, isFromCache}` obtido de `SnapshotMetadata` (streams com `includeMetadataChanges: true` **somente** nos streams que alimentam o indicador — não em todos, por custo de rebuild).

| Estado exibido | Regra |
|---|---|
| "Salvo neste dispositivo" | `hasPendingWrites == true` e offline (ou `isFromCache`) |
| "Sincronizando…" | `hasPendingWrites == true` e online |
| "Sincronizado" | `hasPendingWrites == false` e `isFromCache == false` |

`syncStatusProvider` (Provider<SyncStatus>) combina `connectivityProvider` com o `SyncMeta` do stream principal da tela (tarefas da casa ativa no dashboard, itens na tela de lista). `SyncIndicator` fica na AppBar do dashboard; por item, um ícone sutil de "pendente" (relógio) quando `hasPendingWrites` do doc for true. "Sincronizado" some após ~2 s para não poluir.
Observação: `hasPendingWrites` só é `false` depois que o servidor confirma; `waitForPendingWrites()` pode ser usado em testes de integração, não na UI.

### 5.3 Operações só-online
`OnlineOnlyGuard`: antes de chamar callables (createFamily, createHousehold, convites, aceitar, remover, transferir, verifyPurchase, excluir conta), o controller checa `connectivityProvider`. Offline → não dispara; mostra diálogo/snackbar "Precisa de internet para isso" e mantém os botões **habilitados** com estado explicativo (melhor que desabilitar sem motivo). Se a conexão cair durante a chamada → `AppFailure.network` com retry. Callables não são enfileiradas automaticamente (sem fila própria — ADR 0002); usuário repete. Operações de conteúdo nunca usam essa guarda.

## 6. i18n, tema e acessibilidade

- **i18n:** `flutter_localizations` + `gen-l10n` (`l10n.yaml`, template `app_pt.arb`, `nullable-getter: false`). pt-BR padrão; nenhum texto fixo em widgets (lint: `avoid_hardcoded_strings` via custom lint ou revisão em PR). Usar ICU plural/select (ex.: "{n, plural, =0{Nenhuma tarefa} =1{1 tarefa} other{{n} tarefas}}"). Chaves por feature: `tasks_quickAdd_hint`. Mensagens de erro vêm de `AppFailure` → chave ARB, nunca string do SDK. Datas/horas com `intl` (`DateFormat` por locale). Textos de notificações locais também via ARB; notificações FCM: Function escolhe texto pelo `locale` do device (campo em `devices`). `users.locale` define idioma inicial; seletor em Configurações sobrescreve (SharedPreferences) — "Sistema" como opção padrão.
- **Tema:** Material 3 (`useMaterial3: true`), `ColorScheme.fromSeed` com seed da marca (a definir), claro/escuro seguindo o sistema, dynamic color opcional (`dynamic_color`) — decidir em §11. Componentes: `NavigationBar`, `FloatingActionButton`, `ModalBottomSheet`, `SegmentedButton`, `SnackBar` com undo. Tokens (espaçamento, raios) em `core/theme`.
- **Acessibilidade básica:** alvos ≥ 48 dp; contraste AA; suporte a `textScaler` até 200% sem overflow (layouts flexíveis, sem alturas fixas em linhas de texto); `Semantics`/`tooltip` em ícones (FAB, checkbox com label da tarefa); estado não transmitido só por cor (concluída = riscado + ícone); foco lógico no teclado ao abrir a sheet de criação; testes de widget com `meetsGuideline(androidTapTargetGuideline)` e `labeledTapTargetGuideline`.

## 7. Política de listeners e custo

| Regra | Detalhe |
|---|---|
| Listeners permanentes (sessão) | `authStateProvider`, `membershipsProvider`, `activeFamilyProvider` + `activeEntitlementProvider` (família ativa), `accessibleHouseholdsProvider`, tarefas da casa ativa (quando Dashboard montado). No máximo ~5 |
| Só quando visível | Detalhe de tarefa, itens de lista, membros, atividade, assinatura: `autoDispose` + (opcional) `ref.onCancel/keepAlive` com timeout curto ao sair da tela |
| Troca de família/casa | Providers `family`-parametrizados por `activeContext` cancelam os listeners anteriores automaticamente |
| Segundo plano | App em background → listeners cancelados (`AppLifecycleState.paused` → `listenersPausedProvider`); ao voltar, retomam lendo do cache primeiro. FCM cobre o que for urgente |
| Queries | Sempre `limit` (padrão 50 tarefas pendentes; 30 itens/pág; 20 atividades/pág); `deletedAt == null` no servidor; usar os índices de data-model §5 |
| Histórico | Paginação por cursor (`startAfterDocument` em `createdAt` DESC); infinite scroll com `loadMore()`; sem listener em páginas antigas |
| Edição de texto | Debounce 600–800 ms (título/descrição de tarefa em edição, nome de item/lista) com flush no `dispose`/ao sair da tela; criação rápida só grava no ✓ (sem debounce). Sem escrita por tecla |
| Escritas | Preferir `update` parcial; batch de tarefa+atividade; evitar reescrever o doc da lista ao mudar item |
| Dedup | Um stream por query via provider compartilhado; telas usam `select` para evitar rebuild |
| Medição | Contador de reads em debug (dev) e revisão com Emulator UI; budget alert no Firebase |

## 8. AuthRepository e sessão

### 8.1 Interface (domínio)
```
AuthRepository
  Stream<AuthState> authStateChanges()
  AuthUser? get currentUser
  Set<AuthProviderId> get availableProviders          // {google} no MVP; UI de login desenha um botão por provedor
  Future<AuthUser> signIn(AuthProviderId provider, [AuthCredentialsInput? input])
  Future<void> signOut()
  Future<void> deleteAccount()                         // re-autenticação se necessário
  Future<String?> getIdToken({bool forceRefresh})
```
- Implementação `FirebaseAuthRepository` compõe `AuthProviderAdapter` (interface: `id`, `Future<firebase.AuthCredential> obtainCredential(input)`). MVP: `GoogleAuthAdapter` (`google_sign_in`). Futuros: `EmailPasswordAdapter`, `AppleAdapter` entram registrando no mapa — sem alterar repository, providers nem telas (a tela de login itera `availableProviders`).
- Após login, `AuthRepository` não cria dados; `UserProfileRepository` (em auth/data) faz upsert de `users/{uid}` (`displayName`, `photoUrl`, `locale`, `timezone` — únicos campos do cliente) e `DeviceRepository` registra o token.

### 8.2 Fluxo de sessão
1. Splash: aguarda primeiro evento de `authStateChanges`.
2. `SignedOut` → `/login`. `SignedIn` → upsert perfil → lê `users/{uid}` e `memberships` (cache primeiro).
3. Sem `freeFamilyId` e sem memberships → `/bootstrap` (`createFamily`, online). Sucesso → memberships emite → `activeContext` escolhe a Free e a casa inicial → `/home`.
4. `activeContext` restaurado de SharedPreferences; se inválido (família removida/sem acesso) → fallback para primeira membership/casa acessível.
5. Token FCM registrado; `reminderSync` inicia.

### 8.3 Logout
Cancela listeners (providers dependem de `authStateProvider`, então são invalidados), remove o doc do device do usuário (best-effort, online) e cancela notificações locais agendadas; limpa `activeContext` do SharedPreferences; chama `signOut` (Firebase + Google). Cache do Firestore: `clearPersistence()` no logout (evita vazamento entre contas no mesmo aparelho), exigindo que nenhum listener esteja ativo — executar após invalidar providers e antes do próximo login; se falhar, agenda limpeza no próximo start.

### 8.4 Exclusão de conta
- Pré-checagem (online): Function `precheckAccountDeletion` retorna `{blocked: bool, reason}`. **Bloqueada** se o usuário é owner de Family com outros membros → tela explica e leva a `/family/transfer`. Família só com o owner é excluída junto (confirmação informa que as casas e dados serão apagados).
- Execução: Function `deleteAccount` (server-side: soft delete em `users`, exclusão/transferência conforme regra, remoção de memberships/devices, `deleteUser` Auth). O cliente pode precisar de **re-autenticação recente** (Google) antes; tratar `requires-recent-login` reautenticando com o mesmo adapter.
- Membro (não owner): sai de todas as famílias (`leaveFamily`) automaticamente como parte da Function.
- Sempre online; dupla confirmação com digitar palavra-chave (i18n).

## 9. Dependências sugeridas (sem versões)

| Pacote | Uso / motivo |
|---|---|
| `flutter_riverpod`, `riverpod_annotation` (+ `riverpod_generator`) | Estado/DI decididos; geração reduz boilerplate e dá `autoDispose`/`family` tipados |
| `go_router` | Navegação decidida; redirect + `StatefulShellRoute` |
| `freezed_annotation`/`freezed`, `json_annotation`/`json_serializable`, `build_runner` | Modelos imutáveis, unions, DTOs |
| `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_messaging`, `firebase_app_check`, `firebase_crashlytics`, `firebase_analytics`, `firebase_remote_config` | Backend decidido (todos via FlutterFire; configurar flavors com `flutterfire configure`) |
| `google_sign_in` | Provedor Google (adapter) |
| `flutter_local_notifications`, `timezone`, `flutter_timezone` | Lembretes locais com TZ IANA correta; obter TZ do aparelho |
| `in_app_purchase` (+ `in_app_purchase_android`) | Play Billing; validação no backend |
| `shared_preferences` | Preferências e contexto ativo (ADR 0002) |
| `connectivity_plus` | Indicador offline (complementar; o sinal real de sync vem do `SnapshotMetadata`) |
| `intl`, `flutter_localizations` | i18n e formatação |
| `share_plus` | Compartilhar código/link de convite |
| `package_info_plus` | Versão no doc do device e tela de configurações |
| `url_launcher` | Política de privacidade/termos, links da Play |
| `dynamic_color` (opcional) | Material You |
| **Dev/teste:** `flutter_test`, `integration_test`, `mocktail`, `fake_cloud_firestore` (só unit de repos simples; comportamento de cache/pendingWrites se testa com emulador), `firebase_auth_mocks`, `riverpod_lint`/`custom_lint`, `flutter_lints`, `golden_toolkit` ou goldens nativos (opcional) | Qualidade e testes |

Evitar: `hive`/`isar`/JSON local (proibido como banco — ADR 0002), bibliotecas de fila/sync próprias.

## 10. Testes, flavors e ponto de entrada

### 10.1 Flavors
| Flavor | `applicationId` | Entry point | Firebase project | Emuladores |
|---|---|---|---|---|
| dev | `app.with.planly.dev` | `lib/main_dev.dart` | `planly-dev` | **Sim** (Auth, Firestore, Functions) via `useAuthEmulator/useFirestoreEmulator/useFunctionsEmulator` no `bootstrap.dart`, host `10.0.2.2` no emulador Android; flag `--dart-define=USE_EMULATORS=true` (padrão true em dev) |
| staging | `app.with.planly.staging` | `lib/main_staging.dart` | `planly-staging` | não |
| prod | `app.with.planly` | `lib/main_prod.dart` | `planly-prod` | nunca |

Cada `main_*.dart` só define `Flavor` + `FirebaseOptions` do flavor (`firebase_options_<flavor>.dart`) e chama `bootstrap(flavor)`. `AppConfig` (flavor, nome, uso de emuladores) é um provider. Flavors no Gradle (`productFlavors`) com `google-services.json` por flavor. Persistência do Firestore habilitada explicitamente (`Settings(persistenceEnabled: true, cacheSizeBytes: limitado)`). Proteção: build prod falha (assert) se `USE_EMULATORS=true`. Crashlytics/Analytics desativados em dev.

### 10.2 Plano de testes
| Nível | Escopo | Como |
|---|---|---|
| Unit | Conversão de timezone/UTC (`Clock`), mapeadores DTO↔entidade, cálculo de `order` (ponto médio), regra de `sync status`, `familyWriteAccessProvider`, mapeamento `FirebaseException`→`AppFailure`, guards de redirect (função pura recebe estado → destino), debounce, paginação | `flutter_test` + `mocktail`, `ProviderContainer` com overrides de repositories |
| Widget | Criar tarefa rápida (+ → texto → ✓; validação vazio/200+), concluir/reabrir, "Mais opções", listas e itens, estados Loading/Empty/Error/Offline de cada tela, banner frozen escondendo ações, upsell Free, acessibilidade (tap targets, semantics), i18n (pump com locale pt-BR; teste que falha se há texto fixo em golden/finders) | `flutter_test` com repositories fake |
| Arquitetura | Nenhum import de `cloud_firestore`/`firebase_auth`/`cloud_functions` fora de `data/` e `core/firebase/` | Teste que varre `lib/` |
| Integration (device/emulador Android + Emulator Suite) | Login (usuário de teste do Auth Emulator) → bootstrap (Function emulada) → casa → criar tarefa → concluir; **A online / B offline cria tarefa → B volta online → A recebe** (2 instâncias/usuários; offline via `FirebaseFirestore.disableNetwork()`/`enableNetwork()`); convite → aceitar; família frozen (seed) = somente leitura | `integration_test` + Emulator Suite, rodados no CI (job "emulator tests") |
| Rules | Fora deste spec (T-003), mas os testes de integração cobrem o caminho feliz e `permission-denied` | |
| Manual (checklist) | Airplane mode real, troca de família/casa, notificação local com app fechado, compra em faixa de teste do Play, dark mode, fonte grande | Antes de cada release |

CI (CLAUDE.md): analyze → test → build → emulator tests; cobertura mínima de domínio/unit a definir.

## 11. Pontos em aberto / ambiguidades

1. **Roles: CLAUDE.md × data-model.** CLAUDE.md cita roles `owner/admin/member` na Family; data-model define família `owner|member` e casa `admin|member`. Este spec segue o data-model. CLAUDE.md deveria ser alinhado (não alterado aqui).
2. **`createFamily` do convidado.** CLAUDE.md diz que a Family Free é criada automaticamente no primeiro acesso, inclusive de quem só quer ser convidado. Confirmar se convidados também recebem Free (gera família vazia que talvez nunca usem) ou se o bootstrap pode ser adiado quando o usuário já tiver membership via convite. Assumido aqui: sempre cria a Free no 1º acesso (idempotente via `freeFamilyId`), `/join` liberado antes do bootstrap.
3. **Aceitar convite antes do bootstrap.** Se o usuário entra por link sem nenhuma família, o guard 4 permite `/join`; falta definir se o bootstrap da Free roda em paralelo ou depois.
4. **Free e "Família" sem convite × dados compartilhados.** Free não convida, mas o tier Free tem `features.fullHistory=false`; não está definido o limite concreto do histórico Free (dias/quantidade). Definir para a tela Atividade.
5. **Recorrência.** Entitlement tem `features.recurringTasks`, mas o MVP não implementa; a UI esconde o campo. Confirmar que não haverá teaser "Premium" no MVP.
6. **Downgrade automático para Free** (data-model §4, ADR 0005) ainda é "proposta": afeta textos do banner frozen e fluxos pós-expiração. UI só trata `active`/`frozen`/`deleting`; se aprovada, adicionar aviso "sua família voltou ao plano Free".
7. **Atividade com `member_joined/member_left`:** quem escreve? data-model diz que atividade é escrita pelo cliente, mas entrada/saída de membro acontece em Function; as Rules/Functions precisam permitir que a Function escreva esses tipos. Alinhar com T-003/T-005.
8. **Forja de atividade:** um membro pode forjar evento em seu próprio nome (risco aceito em data-model §2.3); a UI de atividade não deve ser tratada como auditoria.
9. **Família frozen × membro:** data-model §4 diz "toda escrita de conteúdo exige `family.status == active`"; não especifica se o membro pode **sair** da família em frozen (assumido: sim, via Function) nem se `devices`/preferências seguem graváveis (assumido: sim, não são conteúdo).
10. **Preços na UI:** CLAUDE.md lista preços (R$ 29,90/49,90) como decisão comercial em aberto; o app deve exibir o preço do Play (`ProductDetails`), nunca fixo. Definir `productId`s.
11. **`clearPersistence()` no logout** exige sem listeners ativos e app parado de gravar; se houver escritas pendentes não sincronizadas, elas seriam perdidas. Definir política (bloquear logout com pendências + aviso? esperar `waitForPendingWrites`?). Proposta: avisar e oferecer "Sair mesmo assim".
12. **Contexto ativo em multi-família:** não há decisão sobre qual família/casa abrir por padrão quando o usuário tem várias (assumido: última usada; senão a própria Free/primeira casa).
13. **Timezone:** `users.timezone` vs timezone por tarefa (`schedule.timezone`). Assumido: nova tarefa usa o timezone atual do aparelho; edição preserva o timezone original da tarefa. Confirmar comportamento ao viajar.
14. **`activity` denormaliza `actorName`** e `members.displayName` por snapshot: o fluxo de atualização de nome (Function) não está coberto; UI deve tolerar nomes desatualizados.
15. **Deep links/notificação com `familyId/householdId`:** payload FCM precisa trazer ambos os IDs; contrato a fechar em T-005.
16. **Seed/branding do tema**, suporte a dynamic color e idiomas além de pt-BR: sem definição.
17. **Brainstorm (seções 66–68, 93–94, UX):** usado como referência geral; nenhuma contradição identificada além das já supersedidas pelo ADR 0003.
