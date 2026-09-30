# Spec — Modelo de dados (Firestore)

**Status:** rascunho para revisão · **Task:** T-002 · **Região:** `southamerica-east1`

Convenções do CLAUDE.md valem aqui: todo doc tem `createdAt`/`updatedAt` (`Timestamp`), `schemaVersion` (int, começa em 1), `deletedAt` (nullable) onde houver soft delete, IDs gerados pelo Firestore (exceto onde indicado). "🔒 server" = só Cloud Functions escrevem (Admin SDK); o cliente nunca escreve esse campo/doc.

## 1. Visão geral

```
users/{uid}
  ├─ memberships/{familyId}                 🔒 espelho p/ listar "minhas famílias"
  └─ devices/{deviceId}                     tokens FCM

families/{familyId}
  ├─ members/{uid}
  ├─ billing/subscription                   🔒 owner lê
  ├─ billing/entitlement                    🔒 membros leem
  └─ households/{householdId}
       ├─ tasks/{taskId}
       │    └─ occurrences/{occId}          (Fase 2, reservado)
       ├─ lists/{listId}
       │    └─ items/{itemId}
       └─ activity/{activityId}             append-only

invitations/{code}                          🔒 exceção: única coleção de topo com leitura restrita
```

Não existe coleção global de conteúdo (`/tasks` etc.). O conteúdo vive sempre sob `families/{f}/households/{h}`.

## 2. Decisões de modelagem (novas, derivadas deste spec)

1. **Roles em dois níveis.**
   - Família: `owner` | `member`. (`admin` de família = o owner; não existe admin separado no MVP.)
   - Casa: `admin` | `member`. `admin` edita/exclui conteúdo de qualquer autor e renomeia a casa; `member` cria, conclui e edita o próprio conteúdo. O owner tem acesso `admin` implícito a todas as casas.
2. **Acesso por casa embutido no doc da casa** (`access` + `accessUids`), escrito só por Function. Motivo: Security Rules não conseguem filtrar uma *query* de listagem por `get()` dependente do id de cada doc; com `accessUids` (array) a query `where accessUids array-contains uid` é provável pelas Rules, e cada checagem de conteúdo custa um único `get()` da casa. O array é mutável mas de escrita rara e só por Function (sem contenção). A entidade lógica `HouseholdAccess` é esse par de campos.
3. **Atividade escrita pelo cliente** no mesmo batch da ação (atômico e funciona offline), com Rules validando `actorId == auth.uid` e tipo permitido; append-only. Evita depender de Functions/Blaze para o histórico. Risco aceito: um membro pode forjar evento *em seu próprio nome*.
4. **Limites com contadores transacionais** (`memberCount`, `householdCount` no doc da família), mantidos só por Function; limites vêm do `entitlement`.
5. **Operações só-online** (Functions): criar família, criar casa, convidar/aceitar, remover membro, transferir ownership. Primeiro acesso exige internet. Todo conteúdo (tasks/lists/items/activity) é client-direct e funciona offline.

## 3. Coleções

### 3.1 `users/{uid}`  (uid = Firebase Auth UID)
| Campo | Tipo | Notas |
|---|---|---|
| displayName | string | do provedor, editável |
| email | string | só identificação; **nunca** usado para autorização |
| photoUrl | string? | |
| locale | string | ex.: `pt-BR` |
| timezone | string | IANA, ex.: `America/Sao_Paulo` |
| freeFamilyId | string? | 🔒 garante no máximo 1 Family Free por usuário |
| deletedAt, createdAt, updatedAt, schemaVersion | | |

Cliente escreve apenas `displayName`, `photoUrl`, `locale`, `timezone`.

### 3.2 `users/{uid}/memberships/{familyId}`  🔒
Espelho mantido por Function para listar as famílias do usuário sem collection group.
`familyName`, `role` (`owner|member`), `familyStatus`, `plan`, `joinedAt`, `updatedAt`.

### 3.3 `users/{uid}/devices/{deviceId}`
`fcmToken`, `platform` (`android`), `appVersion`, `locale`, `timezone`, `lastSeenAt`, `createdAt`. Cliente escreve o próprio doc. `deviceId` = id de instalação gerado no app.

### 3.4 `families/{familyId}`
| Campo | Tipo | Notas |
|---|---|---|
| name | string | cliente (owner) pode editar |
| ownerId | string | 🔒 |
| status | `active` \| `frozen` \| `deleting` | 🔒 ver §4 |
| plan | `free` \| `family` \| `family_plus` | 🔒 espelho do entitlement (p/ UI) |
| memberCount | int | 🔒 membros ativos |
| householdCount | int | 🔒 casas não excluídas |
| frozenAt | timestamp? | 🔒 |
| deleteAfter | timestamp? | 🔒 `frozenAt + 90 dias` |
| pendingTransfer | map? `{toUid, createdAt, expiresAt}` | 🔒 |
| deletedAt, createdAt, updatedAt, schemaVersion | | |

### 3.5 `families/{familyId}/members/{uid}`
`role` (`owner|member`) 🔒, `status` (`active|removed`) 🔒, `displayName`, `photoUrl` (snapshot p/ UI, atualizado por Function), `joinedAt`, `invitedBy`, `createdAt`, `updatedAt`.
O `owner` é sempre membro (criado junto com a família).

### 3.6 `families/{familyId}/billing/subscription`  🔒 (owner lê)
`provider` (`google_play`), `productId`, `purchaseTokenHash` (nunca o token em claro), `purchasedBy` (uid), `state` (`active|grace|on_hold|canceled|expired`), `autoRenewing`, `expiresAt`, `lastVerifiedAt`, `createdAt`, `updatedAt`. Família Free não tem este doc.

### 3.7 `families/{familyId}/billing/entitlement`  🔒 (membros leem)
| Campo | Free | Família | Família+ |
|---|---|---|---|
| plan | free | family | family_plus |
| maxMembers | 1 | 4 | 8 |
| maxHouseholds | 1 | 3 | null (ilimitado) |
| features.invites | false | true | true |
| features.recurringTasks | false | true | true |
| features.fullHistory | false | true | true |

Mais `source` (`default|subscription`), `updatedAt`. Valores vêm de config server-side (Remote Config/const em Functions), não do cliente.
> Nota: o brainstorm coloca recorrência/histórico completo no Family; o flag existe já, mas recorrência só é implementada na Fase 2.

### 3.8 `families/{f}/households/{householdId}`
| Campo | Tipo | Notas |
|---|---|---|
| name | string | editável por owner/admin da casa |
| access | map `{uid: "admin"\|"member"}` | 🔒 |
| accessUids | array<string> | 🔒 derivado de `access` (p/ queries e Rules) |
| createdBy | string | |
| deletedAt, createdAt, updatedAt, schemaVersion | | soft delete (30 dias → hard delete por job) |

### 3.9 `.../households/{h}/tasks/{taskId}`
| Campo | Tipo | Notas |
|---|---|---|
| title | string (1–200) | |
| description | string | |
| createdBy | string | |
| assignedTo | string? | uid; `null` = qualquer pessoa |
| status | `pending` \| `done` | |
| schedule | map? | `null` = sem horário (tarefa rápida). `{type: "datetime", scheduledAt: Timestamp(UTC), timezone: "America/Sao_Paulo"}`. Outros tipos (`relative`, `today`) são UI sobre `datetime` |
| recurrence | map? | `null` no MVP (Fase 2: ver §6) |
| notification | map | `{enabled: bool, offsetMinutes: int}` |
| completedAt, completedBy | timestamp?, string? | |
| deletedAt, createdAt, updatedAt, schemaVersion | | |

Tarefa rápida: `status=pending, schedule=null, assignedTo=<criador>`.

### 3.10 `.../households/{h}/lists/{listId}` e `.../items/{itemId}`
Lista: `name`, `type` (`shopping|general`), `createdBy`, soft delete, timestamps.
Item (doc separado — nunca array): `name`, `completed`, `completedBy?`, `completedAt?`, `createdBy`, `order` (double, p/ reordenação sem reescrever tudo), soft delete, timestamps. Isso evita conflito quando duas pessoas editam a mesma lista.

### 3.11 `.../households/{h}/activity/{activityId}`  (append-only)
`type` ∈ cliente: `task_created|task_assigned|task_completed|task_reopened|task_updated|task_deleted|list_created|list_deleted|item_added|item_completed|item_deleted` · Function (Admin SDK): `member_joined|member_left|household_created`, `actorId`, `actorName` (snapshot), `targetType` (`task|list|item|member|household`), `targetId`, `targetTitle` (snapshot), `createdAt` (serverTimestamp), `schemaVersion`. Snapshots evitam reads extras e sobrevivem à exclusão/renomeio do alvo. Histórico paginado (`limit` + cursor por `createdAt`).

### 3.12 `invitations/{code}`  🔒
`code` é o docId: 10 caracteres base32 gerados no servidor (~50 bits) — não enumerável na prática, agravado por App Check + rate limit na Function.
`familyId`, `grants` (lista de `{householdId, role}`), `createdBy`, `status` (`pending|accepted|revoked|expired`), `expiresAt` (createdAt + 24h), `acceptedBy?`, `acceptedAt?`, `createdAt`.
Única coleção de topo legível pelo cliente, e só por `createdBy == auth.uid` (owner lista os convites que criou). Aceitar = Function callable (o convidado ainda não tem acesso à família). Política **TTL** do Firestore em `expiresAt + 7d` limpa convites antigos; job diário marca `expired`.

## 4. Ciclo de vida da Family

```
        bootstrapUser (1º login)
               ↓
   ┌────── active ◄──────────────────────────┐
   │   (Free, ou paga com assinatura vigente) │
   │                                          │ owner reassina  OU
   │ assinatura expira (após grace)           │ transferência concluída
   ▼                                          │
 frozen ──────────────────────────────────────┘
   │ somente leitura; frozenAt; deleteAfter = frozenAt + 90d
   │ avisos: D-60, D-30, D-7, D-1 (owner e membros)
   ▼ (deleteAfter atingido)
 deleting → hard delete em cascata (job)
```

- **Cancelar renovação** não muda `status`: a família segue `active` até `expiresAt` (+ grace/account hold da Play).
- **Somente leitura** é imposto pelas Rules: toda escrita de conteúdo exige `family.status == "active"`.
- **Proposta a confirmar (nova):** se ao expirar a família só tem o owner como membro **e** `householdCount <= 1`, ela faz **downgrade automático para Free** (`active`) em vez de `frozen`. Sem isso, um owner solo que só perdeu a assinatura ficaria congelado sem ter a quem transferir. Família com outros membros ou mais de 1 casa → `frozen`.
- **Ownership transfer:** owner chama `startOwnershipTransfer(toUid)` → `pendingTransfer` (expira em 7 dias) → o membro aceita e assina com a própria conta → `completeOwnershipTransfer` (após validação da compra) troca `ownerId`, roles em `members` e `memberships`, substitui `billing/subscription`, e leva a família para `active`. O dono anterior vira `member` (mantém os acessos às casas que tinha).
- **Exclusão de conta do owner:** bloqueada enquanto houver outros membros. Família só com o owner é excluída junto.
- **Família Free** nunca é congelada.

## 5. Índices compostos

Automáticos (campo único) cobrem `accessUids array-contains`, `createdAt` etc. Compostos necessários:

| Coleção | Campos | Uso |
|---|---|---|
| tasks | `deletedAt` ASC, `status` ASC, `schedule.scheduledAt` ASC | lista "próximas tarefas" |
| tasks | `deletedAt` ASC, `assignedTo` ASC, `status` ASC, `schedule.scheduledAt` ASC | "minhas tarefas" |
| items | `deletedAt` ASC, `completed` ASC, `order` ASC | itens pendentes antes dos concluídos |
| activity | `createdAt` DESC (+ `actorId` ASC) | histórico e filtro por pessoa |

Consultas sempre com `limit`. Listeners mínimos: dashboard observa tarefas da casa ativa e lista de casas; telas de detalhe abrem listener só quando visíveis.

## 6. Recorrência (Fase 2 — reservado)
Task doc = *definição*; `recurrence` ganha `{type: none|interval|daily|weekly|monthly, interval, unit, weekDays[], time, timezone}`. Ocorrências em `tasks/{t}/occurrences/{occId}` (`dueAt` UTC, `status`, `completedAt/By`), geradas por job agendado (Blaze) e por agendamento local complementar. No MVP o status fica no próprio doc da tarefa; a migração usa `schemaVersion` (2).

## 7. Custo das Rules
Cada `get()` em Rules conta como leitura. Conteúdo: leitura = 1 get (casa); escrita = 2 gets (casa + família, p/ `status`). Aceitável no volume esperado; se pesar, denormalizar `familyStatus` no doc da casa via Function.

## 8. Resoluções da revisão (T-003/T-004)

Fecham as ambiguidades levantadas em `security-rules.md` §9 e `flutter-app.md` §11. Itens marcados ❓ aguardam decisão de produto.

| # | Tema | Resolução |
|---|---|---|
| 1 | Quem cria `users/{uid}` | A Function `bootstrapUser` (bootstrap do 1º login) cria `users/{uid}` (`email`, `createdAt`, `schemaVersion`). Cliente só faz update dos campos permitidos. |
| 2 | Owner em `access` | **Não** entra em `access/accessUids`; Rules usam `|| isFamilyOwner`. Transferência não reescreve N casas. Cliente owner lista casas por query de owner (role vem de `memberships`). |
| 3 | Membro removido | `removeMember` é uma transação/batch única: `members.status=removed` + remove de `access`/`accessUids` em todas as casas + espelhos + contador. Sem janela de acesso residual. |
| 4 | "Edita o próprio conteúdo" | Member: edita o que criou; **pode concluir/reabrir** tarefa se for o `assignedTo` ou se `assignedTo == null`; **itens de lista são colaborativos** (qualquer acesso cria/completa/edita/reordena). Soft delete: autor ou admin/owner. |
| 5 | Activity | Tipos ampliados (§3.11). `member_joined/left/household_created` só por Function. |
| 6 | Retenção de soft delete | tasks/lists/items: 30 dias, depois hard delete por job. Restaurar: só admin da casa/owner. |
| 7 | Casa soft-deleted | A Function copia `access` para `deletedAccess` e **esvazia `accessUids`/`access`** (para de aparecer/ser acessível); restaurar recompõe. |
| 8 | `accessUids` mutável | Só Function escreve, sempre via transação ou `arrayUnion/arrayRemove` (nunca set do array inteiro). |
| 9 | Transferência e convites | `completeOwnershipTransfer` revoga convites pendentes da família; o novo owner gera os seus. |
| 10 | `createdBy` | Imutável em todos os docs. Conteúdo de quem saiu só é editável por admin/owner. |
| 11 | `members` legível | Todo membro ativo lê a lista de membros da família (nome/foto). Aceito. |
| 12 | Renomear em `frozen` | Não permitido (tudo somente leitura). |
| 13 | Escrita offline rejeitada | Se chegar após `frozen`, o servidor rejeita; o app marca o item como "não sincronizado" e oferece descartar (UX em `flutter-app.md`). |
| 14 | `fullHistory` / `recurringTasks` | Flags não impostos por Rules no MVP; recorrência travada em `null`; limite de histórico no Free aplicado por `limit` no cliente. |
| 15 | Convidado e Family Free | **Todo usuário ganha sua Family Free no 1º login**, inclusive quem entra por convite (a Free é o espaço pessoal dele; Free não impede ser convidado em outras). `/join` pode ser aberto antes do bootstrap, mas o aceite roda após `bootstrapUser`. |
| 16 | Logout com escritas pendentes | Avisar e oferecer "Sair mesmo assim" antes de limpar o cache do Firestore. |
| 17 | Downgrade solo → Free | **Aprovado.** Ao expirar, só owner e ≤ 1 casa → Free (`active`); senão `frozen`. |
| 18 | Histórico no Free | **Aprovado:** últimos 7 dias. |
| 19 | Timezone ao viajar | **Aprovado:** tarefa guarda o fuso de criação; UI exibe no fuso do aparelho. |
| 20 | Plano pago reduzido (uso > novo limite) | **Período de regularização** antes de congelar: Family fica `active` com `regularizeBy = now + 30d` e modo restrito (só remover membros/casas e ajustar acessos; criação bloqueada no que excede). Excedeu o prazo sem regularizar → `frozen` (90 dias até exclusão). Prazo de 30 dias é proposta ajustável. Campo `regularizeBy` 🔒 na Family. |

## 9. Fora deste spec
Regras de segurança → `security-rules.md` (T-003). Contratos das Functions → `cloud-functions.md` (T-005). Telas/providers → `flutter-app.md` (T-004).
