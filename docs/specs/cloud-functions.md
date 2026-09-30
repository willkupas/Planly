# Spec — Cloud Functions (MVP)

**Status:** rascunho para revisão · **Task:** T-005 · **Depende de:** [data-model.md](data-model.md), [security-rules.md](security-rules.md) · **ADRs:** 0003, 0005

Functions é a única camada server-side. Escreve com Admin SDK (ignora Rules), portanto **cada função valida autenticação, papel, status da família e limites por conta própria**.

## 1. Convenções gerais

- **Runtime:** Node.js 22, TypeScript, `firebase-functions` v2 (2nd gen). Região `southamerica-east1` (Firestore trigger deve estar na região do banco).
- **Callables** (`onCall`): `enforceAppCheck: true`, `request.auth` obrigatório (`unauthenticated` se ausente). Todas retornam `{ok: true, ...dados}`; falhas são `HttpsError`.
- **Transações:** toda mutação que envolve contador/limite/acesso roda em transação Firestore (ou batch atômico). Nunca ler-e-depois-escrever fora de transação.
- **Idempotência:** operações naturalmente idempotentes (`bootstrapUser`, `acceptInvitation` repetido pelo mesmo uid, `removeMember` de quem já saiu) retornam sucesso sem duplicar efeitos.
- **Planos:** fonte única em `functions/src/domain/plans.ts` (`maxMembers`, `maxHouseholds`, `features`), espelhada em `billing/entitlement`. Preços não vivem aqui (vêm do Play).
- **Estrutura sugerida:**
  ```
  functions/src/
    callable/   bootstrapUser, households, invitations, members, transfer, billing, account
    jobs/       lifecycle, purge, cleanup
    triggers/   playNotifications (Pub/Sub), notifications (Sprint 6)
    billing/    PlayBillingClient (interface + impl + fake p/ testes)
    domain/     plans, familyState, errors
    lib/        logger, authz, tx helpers
  ```

### 1.1 Modelo de erro
`HttpsError(code, message, { reason })`. `reason` é string estável que o app traduz (i18n), nunca texto para exibir.

| code | reason | quando |
|---|---|---|
| `unauthenticated` | — | sem `auth` |
| `permission-denied` | `NOT_OWNER`, `NOT_MEMBER` | papel insuficiente |
| `failed-precondition` | `FAMILY_FROZEN`, `FEATURE_NOT_IN_PLAN`, `PLAN_LIMIT_MEMBERS`, `PLAN_LIMIT_HOUSEHOLDS`, `OWNER_HAS_MEMBERS`, `LAST_HOUSEHOLD`, `OWNER_CANNOT_LEAVE`, `TRANSFER_PENDING`, `BOOTSTRAP_REQUIRED` | regra de negócio |
| `not-found` | `FAMILY_NOT_FOUND`, `HOUSEHOLD_NOT_FOUND`, `INVITE_NOT_FOUND`, `MEMBER_NOT_FOUND` | |
| `already-exists` | `ALREADY_MEMBER` | |
| `deadline-exceeded` | `INVITE_EXPIRED`, `TRANSFER_EXPIRED` | |
| `resource-exhausted` | `RATE_LIMITED` | limite de tentativas |
| `invalid-argument` | campo | validação de entrada |

### 1.2 Logging
Log estruturado por chamada: `{function, uid, familyId, householdId, operation, result: "ok"|"error", errorReason, durationMs}`. **Nunca** logar: e-mail, tokens (FCM, Play), `purchaseToken` (usar hash), conteúdo de tarefas. `uid` aceito (não é PII direta).

### 1.3 Rate limit
Docs internos `_rateLimits/{uid}_{fn}` (`count`, `windowStart`), **negados a qualquer cliente** nas Rules (`allow read, write: if false` já cobre via default-deny). Limites: `acceptInvitation` 10/h por uid; `createInvitation` 20/h por família; `bootstrapUser` 5/h.

## 2. Callables

### 2.1 `bootstrapUser`  (substitui `createFamily` do plano)
**Quem:** qualquer logado · **Online-only** · **Idempotente**.
**Entrada:** `{ displayName?, locale?, timezone?, householdName? }`.
**Efeito (transação):**
1. Cria/atualiza `users/{uid}` (`email` do token Auth, `createdAt`, `schemaVersion`).
2. Se `users.freeFamilyId` já existe → devolve ids existentes (idempotência).
3. Senão cria: `families/{f}` (`plan: free`, `status: active`, `ownerId: uid`, `memberCount: 1`, `householdCount: 1`), `members/{uid}` (`owner`), `users/{uid}/memberships/{f}`, `billing/entitlement` (Free), primeira casa (`name = householdName ?? "Minha casa"`, `access: {}`, `accessUids: []` — owner é implícito), seta `users.freeFamilyId`. Activity `household_created`.
**Saída:** `{familyId, householdId}`. **Erros:** `RATE_LIMITED`.
**Nota:** todo usuário ganha Family Free, inclusive quem chega por convite (data-model §8 #15).

### 2.2 `createHousehold`
**Quem:** owner · **Entrada:** `{familyId, name}` (1–100).
**Valida:** família `active` (`FAMILY_FROZEN`); `householdCount < maxHouseholds` (`null` = ilimitado; senão `PLAN_LIMIT_HOUSEHOLDS`).
**Efeito:** cria casa (`access: {}`), `householdCount++`, activity `household_created`. **Saída:** `{householdId}`.

### 2.3 `deleteHousehold`
**Quem:** owner · **Entrada:** `{familyId, householdId}`.
**Valida:** não é a última casa (`LAST_HOUSEHOLD`); família `active`.
**Efeito:** soft delete (`deletedAt`), `deletedAccess = access`, zera `access`/`accessUids`, `householdCount--`. Hard delete em 30 dias (job §4.2).
`restoreHousehold({familyId, householdId})` (owner, dentro dos 30 dias): recompõe `access` a partir de `deletedAccess`, revalida `maxHouseholds`.

### 2.4 `setHouseholdAccess`
**Quem:** owner · **Entrada:** `{familyId, householdId, targetUid, role: "admin"|"member"|null}` (`null` = revogar).
**Valida:** família `active`; `targetUid` é membro ativo e **não é o owner** (owner é implícito); casa não deletada.
**Efeito (transação):** atualiza `access[targetUid]` e `accessUids` via `arrayUnion/arrayRemove` (nunca set do array). **Saída:** `{}`.

### 2.5 `createInvitation`
**Quem:** owner · **Entrada:** `{familyId, grants: [{householdId, role}]}` (≥ 1 casa, todas da família).
**Valida:** família `active`; `entitlement.features.invites` (`FEATURE_NOT_IN_PLAN` no Free); `memberCount + convitesPendentes < maxMembers` (`PLAN_LIMIT_MEMBERS`).
**Efeito:** gera `code` (10 chars base32, CSPRNG, sem caracteres ambíguos), cria `invitations/{code}` (`expiresAt = now + 24h`, `status: pending`).
**Saída:** `{code, link, expiresAt}` — `link` = `https://<domínio>/join/<code>` (deep link na fase posterior; MVP usa o código + share sheet).
`revokeInvitation({code})`: owner criador; `status: revoked`.

### 2.6 `acceptInvitation`
**Quem:** logado, **depois de `bootstrapUser`** (`BOOTSTRAP_REQUIRED`) · **Online-only** · rate limit.
**Entrada:** `{code}` (normalizado: maiúsculas, sem hífen/espaço).
**Transação:**
1. Convite existe e `pending` (`INVITE_NOT_FOUND`); `expiresAt > now` (`INVITE_EXPIRED`, marca `expired`).
2. Família `active`; usuário ainda não é membro (`ALREADY_MEMBER`); `memberCount < maxMembers` (`PLAN_LIMIT_MEMBERS`; o limite pode ter caído desde a criação).
3. Cria `members/{uid}` (`role: member`), `memberships/{f}`, `memberCount++`, aplica `grants` em `access/accessUids` das casas, convite → `accepted` (`acceptedBy/At`).
4. Activity `member_joined` por casa concedida; aciona notificação ao owner (§5).
**Saída:** `{familyId, householdIds}`. Mensagens de erro não distinguem "código inexistente" de "já usado" para não permitir sondagem.

### 2.7 `removeMember` / `leaveFamily`
- `removeMember({familyId, targetUid})` — owner remove outro membro. `leaveFamily({familyId})` — membro sai (owner recebe `OWNER_CANNOT_LEAVE`: deve transferir).
- **Transação única:** `members.status = removed`, remove de `access/accessUids` em **todas** as casas, apaga/atualiza `memberships`, `memberCount--`, activity `member_left`. Sem janela de acesso residual (data-model §8 #3).
- Permitido mesmo com família `frozen` (sair nunca é bloqueado).

### 2.8 Transferência de ownership
- `startOwnershipTransfer({familyId, toUid})` — owner; `toUid` é membro ativo; define `pendingTransfer {toUid, createdAt, expiresAt: +7d}`; notifica o destinatário. Um pendente por vez (`TRANSFER_PENDING`).
- `cancelOwnershipTransfer({familyId})` — owner ou destinatário recusa.
- **Conclusão:** não é callable própria — ocorre dentro de `verifyPurchase` (§2.9) quando a compra é do `toUid` para a família com `pendingTransfer.toUid == uid` e ainda não expirada. Transação: `ownerId = toUid`; roles em `members` e `memberships` (antigo → `member`, mantém acessos; novo owner sai de `access` pois é implícito); substitui `billing/subscription`; revoga convites pendentes; limpa `pendingTransfer`; `status` volta a `active` (sai de `frozen`, zera `frozenAt/deleteAfter`); recalcula entitlement.
- A assinatura antiga **não é cancelada pelo backend** (é da conta do antigo owner): o app orienta a cancelar na Play; ela expira sozinha e o evento correspondente é ignorado porque `purchasedBy` ≠ owner atual da assinatura corrente.

### 2.9 `verifyPurchase` (billing)
**Quem:** logado · **Entrada:** `{productId, purchaseToken, familyId?, familyName?}`.
**Fluxos:**
- **A. Upgrade da Free:** `familyId` é a Family Free do próprio uid (owner).
- **B. Nova Family paga:** `familyId` ausente → cria Family (`familyName`) + casa inicial, com o plano do produto.
- **C. Retomar/assumir:** `familyId` de família `frozen` cujo owner é o uid (reassinar), **ou** com `pendingTransfer.toUid == uid` (conclui transferência §2.8).
**Passos:** (1) valida o token na **Google Play Developer API** (`purchases.subscriptionsv2.get`) com service account; `obfuscatedExternalAccountId` deve == uid (definido pelo app na compra); (2) mapeia `productId → plan` (`family` / `family_plus`); (3) **acknowledge** a compra se pendente (Play cancela em 3 dias se não); (4) transação: escreve `billing/subscription` (`purchaseTokenHash`, nunca o token), `billing/entitlement`, `families.plan`, espelho em `memberships`; (5) um `purchaseToken` só pode estar ligado a uma família (índice por hash; reuso em outra família → `failed-precondition`).
**Downgrade entre planos pagos:** troca de produto na Play gera novo token/estado; se os limites novos forem menores que o uso atual (ex.: 6 membros → plano de 4), a família define `regularizeBy = now + 30d` e entra em **modo restrito** (Rules/Functions bloqueiam criar o que excede; só remover membros/casas e ajustar acesso). Regularizado → limpa `regularizeBy`. O `lifecycleJob` (§4.1) congela quem passar do prazo.
**Saída:** `{familyId, plan, status}`.

### 2.10 `deleteAccount`
**Quem:** logado · **Online-only.**
**Valida:** owner de alguma família (Free ou paga) **com outros membros ativos** → `OWNER_HAS_MEMBERS` (deve transferir antes). Assinatura ativa não é cancelada pelo backend: o app avisa para cancelar na Play.
**Efeito:** para cada família que possui e sem outros membros → exclusão em cascata; sai (como `leaveFamily`) das famílias alheias; apaga `users/{uid}/*` (devices, memberships); anonimiza `displayName/photoUrl` em `members` e `actorName` em activity; apaga o usuário do Firebase Auth por último.

## 3. Triggers

### 3.1 `onPlayNotification` (Pub/Sub — Real-time Developer Notifications)
Recebe eventos da Play (renovada, cancelada, em grace, em hold, expirada, revogada/reembolsada, recuperada). Para cada um: busca `billing/subscription` pelo `purchaseTokenHash`, **reconsulta a Play API** (não confia no payload), atualiza `state/expiresAt/autoRenewing` e entitlement. **Não congela imediatamente**: só atualiza datas; o congelamento é decidido pelo job de ciclo de vida. Reembolso/revogação (`revoked`) → expira na hora.
Requer Blaze (Pub/Sub).

### 3.2 Notificações de eventos compartilhados
Especificadas na Sprint 6. Já reservado: `onDocumentCreated` em `tasks/items` (e conclusão) → FCM para `accessUids ∪ owner` exceto o autor, lendo tokens em `users/{uid}/devices`, removendo tokens inválidos da resposta do FCM.

## 4. Jobs agendados (Cloud Scheduler → onSchedule, Blaze)

### 4.1 `lifecycleJob` (diário, 03:00 America/Sao_Paulo)
Para cada família paga não `deleting`:
1. **Expiração:** assinatura `expired` (passou grace/hold) sem outra válida →
   - **Aprovado:** só owner como membro **e** `householdCount ≤ 1` → vira Free (`status active`, `plan free`, entitlement Free, remove `billing/subscription`);
   - caso contrário → `status: frozen`, `frozenAt = now`, `deleteAfter = now + 90d`.
2. **Avisos** (FCM + flag para banner in-app): expiração em D-7 (owner e membros); congelada em D+0; exclusão em `deleteAfter` D-60, D-30, D-7, D-1. Marcar `notifiedAt[tipo]` para não repetir.
3. **Exclusão:** `frozen` com `deleteAfter <= now` → `status: deleting` → dispara cascata (§4.2). Reassinatura/transferência antes disso desfaz.
4. Transferências pendentes com `expiresAt <= now` → limpa `pendingTransfer`.

### 4.2 `purgeJob` (diário)
- Casas com `deletedAt + 30d` → hard delete recursivo (tasks, lists, items, activity).
- tasks/lists/items com `deletedAt + 30d` → hard delete.
- Famílias `deleting` → hard delete em cascata (casas, members, billing, convites, `memberships` dos usuários); em lotes (`BulkWriter`), idempotente e retomável.
- **Antes** de apagar família com assinatura ainda ativa: nunca (assinatura ativa impede `frozen`).

### 4.3 `cleanupJob` (diário)
Convites `pending` com `expiresAt < now` → `expired`; política **TTL** do Firestore apaga convites em `expiresAt + 7d`. Limpa `_rateLimits` antigos. Remove `devices` sem uso há > 90 dias.

### 4.4 `reconcileBillingJob` (diário)
Reconsulta na Play as assinaturas `active/grace/on_hold` com `lastVerifiedAt` > 24h, como rede de segurança para RTDN perdida.

## 5. Notificações de sistema (mínimo do MVP)
Além das de tarefas/listas (Sprint 6): convite aceito (owner), transferência recebida/aceita/recusada, avisos de assinatura (§4.1). Canal Android separado para "Conta e plano". Payload só com ids e tipo (`{type, familyId, householdId?, targetId?}`); texto montado no app (i18n).

## 6. Ambiente e testes
- **Dev local:** Emulator Suite (Auth/Firestore/Functions). Callables e triggers Firestore rodam local sem Blaze. **Scheduler e Pub/Sub não disparam sozinhos**: os jobs são exportados também como funções invocáveis em dev (flag) e testados chamando-as diretamente. `PlayBillingClient` tem implementação **fake** para testes e dev; a real só em staging/prod.
- **Testes:** unitários de `domain/` (plans, máquina de estados da família, cálculo de `deleteAfter`/avisos); integração com emulator por callable (caminho feliz + cada `reason` de erro + idempotência + concorrência: dois `acceptInvitation` simultâneos no último slot → só um vence).
- **Segredos:** service account da Play em Secret Manager (nunca no repositório); variáveis por ambiente (`dev|staging|prod`).
- **Deploy:** `firebase deploy --only functions` por projeto; Blaze necessário a partir do primeiro deploy real (estratégia: emuladores até a Sprint 5).

## 7. Pontos em aberto
1. **Regularização:** prazo de 30 dias é proposta; detalhar a UX do modo restrito na Sprint 8 e incluir `regularizeBy` nas Rules (T-012 não precisa dele).
2. **Link de convite** exige domínio e Android App Links (`assetlinks.json`); no MVP só código + share sheet.
3. **Apple/iOS:** `verifyPurchase` e RTDN são Play-only; App Store Server API entra com iOS.
4. **Produtos da Play:** ids (`family_monthly`, `family_plus_monthly`…) e períodos anuais a definir na Sprint 8.
