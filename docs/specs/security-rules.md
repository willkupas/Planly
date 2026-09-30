# Spec — Security Rules (Firestore)

**Status:** rascunho para revisão · **Task:** T-003 · **Depende de:** [data-model.md](data-model.md) (fonte da verdade dos campos) · **ADRs:** 0003, 0005

Este documento define *o que* as Rules devem permitir/negar. O código real das Rules é da T-012 (`firebase/firestore.rules`); os trechos abaixo são ilustrativos. Regra geral: **negar por padrão** (`match /{document=**} { allow read, write: if false; }`), nenhuma coleção global de conteúdo, autorização sempre por `request.auth.uid` (nunca e-mail).

## 1. Papéis considerados

| Sigla | Papel | Como é determinado |
|---|---|---|
| **A** | Não autenticado | `request.auth == null` |
| **B** | Autenticado sem vínculo | logado, sem `families/{f}/members/{uid}` ativo naquela família |
| **C** | Member da família, sem acesso à casa | `members/{uid}.status == "active"` e `uid ∉ household.accessUids` |
| **D** | Member com acesso `member` na casa | `household.access[uid] == "member"` |
| **E** | `admin` da casa | `household.access[uid] == "admin"` |
| **F** | Owner da família | `family.ownerId == uid` (acesso `admin` implícito a todas as casas, sem depender de `access`) |

Um mesmo usuário pode ser F numa família, D em outra e B em uma terceira: os papéis são avaliados **por família/casa**, nunca globalmente.

## 2. Matriz de permissões

Legenda: **L** = ler (get/list) · **C** = criar · **U** = editar · **D** = excluir · **—** = negado · **✱** = exige `family.status == "active"` (§3) · **fn** = somente Cloud Function (Admin SDK).
Toda célula "—" vale também para A (não autenticado), que **nunca** acessa nada.

### 2.1 Dados do usuário (independem de família)

| Coleção | A | B/C/D/E/F (qualquer logado) |
|---|---|---|
| `users/{uid}` | — | **próprio doc:** L · U (só `displayName`, `photoUrl`, `locale`, `timezone`) · C fn* · D fn. Doc de outro uid: — |
| `users/{uid}/memberships/{familyId}` | — | **próprio:** L. C/U/D: fn |
| `users/{uid}/devices/{deviceId}` | — | **próprio:** L · C · U · D (não sofre efeito de `frozen`). Doc de outro uid: — |

\* Ver ambiguidade #1 (quem cria `users/{uid}`).

### 2.2 Família

| Coleção | A | B | C | D | E | F |
|---|---|---|---|---|---|---|
| `families/{f}` | — | — | L | L | L | L · U✱ (só `name`) · C fn · D fn |
| `families/{f}/members/{uid}` | — | — | L | L | L | L · C/U/D fn |
| `billing/subscription` | — | — | — | — | — | L · C/U/D fn |
| `billing/entitlement` | — | — | L | L | L | L · C/U/D fn |
| `invitations/{code}` | — | — | — | — | — | L (só `createdBy == uid`, via query) · C/U/D fn |

Notas:
- "Membro" nas linhas `families`, `members` e `entitlement` = `members/{uid}` existe com `status == "active"`. Membro `removed` volta a ser B.
- Convites: nenhum papel escreve; criar/aceitar/revogar é callable. O convidado (B) não lê o convite: envia o `code` à Function.
- `subscription` é legível só pelo owner e nunca contém token em claro (`purchaseTokenHash`).

### 2.3 Casas e conteúdo

| Coleção | A | B | C | D (member) | E (admin da casa) | F (owner) |
|---|---|---|---|---|---|---|
| `households/{h}` | — | — | — | L · U✱ nenhum | L · U✱ (só `name`) | L · U✱ (só `name`) |
| ↳ criar/excluir casa, mudar `access`/`accessUids` | — | — | — | fn | fn | fn |
| `tasks/{t}` | — | — | — | L · C✱ · U✱ (†) · D✱ soft (‡) | L · C✱ · U✱ · D✱ soft | L · C✱ · U✱ · D✱ soft |
| `lists/{l}` | — | — | — | L · C✱ · U✱ (†) · D✱ soft (‡) | L · C✱ · U✱ · D✱ soft | L · C✱ · U✱ · D✱ soft |
| `lists/{l}/items/{i}` | — | — | — | L · C✱ · U✱ (§) · D✱ soft (‡) | L · C✱ · U✱ · D✱ soft | L · C✱ · U✱ · D✱ soft |
| `activity/{a}` | — | — | — | L · C✱ (append) | L · C✱ (append) | L · C✱ (append) |
| `tasks/{t}/occurrences/{o}` (Fase 2) | — | — | — | negado até a spec da Fase 2 | | |

Restrições comuns a toda a tabela 2.3:
- **D (hard delete) de conteúdo é sempre negado ao cliente.** "D soft" = update setando `deletedAt` (§6).
- **Activity:** U e D sempre negados a todos, inclusive owner (append-only).
- **Casa soft-deleted** (`deletedAt != null`): conteúdo fica ilegível/imutável para D e E; F só lê (para restauração por Function). Ver ambiguidade #9.
- (†) **Member edita o próprio conteúdo:** `createdBy == uid`. Exceção proposta para **tarefas**: member também pode alterar `status/completedAt/completedBy` (concluir/reabrir) se for o `assignedTo` ou se `assignedTo == null`. E/F editam qualquer tarefa/lista. Ver ambiguidade #5.
- (‡) Soft delete: autor (`createdBy == uid`) ou E/F.
- (§) **Itens:** por serem colaborativos (lista de compras), qualquer D/E/F com acesso pode criar itens e alternar `completed`/editar `name`/`order` de qualquer item. Só soft delete segue (‡). Ver ambiguidade #5.
- D/E/F só passam se a casa existe e `deletedAt == null` (escrita) e, para D/E, `uid ∈ accessUids`.

## 3. Congelamento (`family.status`)

- **Toda escrita de conteúdo exige `family.status == "active"`**: `tasks`, `lists`, `items`, `activity` (C, U, D-soft) e `families/{f}` (`name`). `frozen` **e** `deleting` bloqueiam (a regra é `== "active"`, nunca `!= "frozen"`).
- **Leitura continua permitida** em `frozen` (e em `deleting`, até o hard delete) para todos que já podiam ler, inclusive owner, que precisa exportar/decidir transferência.
- Não são afetados pelo congelamento (não são conteúdo da família): `users/{uid}` (perfil), `devices`, leitura de `memberships`/`entitlement`/`subscription`. Operações de Function (reassinar, transferência, sair da família) seguem funcionando: Admin SDK ignora Rules.
- Família **Free nunca congela** (data-model §4). Downgrade automático solo→Free (proposta ADR 0005) é decisão da Function; para as Rules basta `status == "active"`.
- O `status` é lido do doc `families/{f}` via `get()` (não do cliente). Escrita offline enfileirada que chega após o congelamento é **rejeitada pelo servidor** (`permission-denied`): o cliente deve tratar como erro de sync e mostrar a tarefa como não sincronizada (ver ambiguidade #10).

## 4. Campos protegidos (cliente nunca escreve)

| Doc | Campos protegidos |
|---|---|
| `users/{uid}` | `freeFamilyId`, `email`\*, `createdAt`, `schemaVersion`, `deletedAt` |
| `families/{f}` | `ownerId`, `status`, `plan`, `memberCount`, `householdCount`, `frozenAt`, `deleteAfter`, `pendingTransfer`, `deletedAt`, `createdAt`, `schemaVersion` (cliente owner só altera `name` e `updatedAt`) |
| `members/{uid}` | tudo (`role`, `status`, snapshots, `joinedAt`, `invitedBy`) |
| `memberships/*`, `billing/*`, `invitations/*` | tudo |
| `households/{h}` | `access`, `accessUids`, `createdBy`, `deletedAt`, `createdAt`, `schemaVersion` (cliente E/F só altera `name` e `updatedAt`) |
| `tasks/lists/items` | `createdBy`, `createdAt`, `schemaVersion` (imutáveis após criar); `completedBy/completedAt` só coerentes com `status` (§4.2) |
| `activity` | qualquer campo após criado |

### 4.1 Como impor

**Update: lista branca de campos alterados** (protege contra escrita em campo não listado, inclusive campos novos):

```
// families/{f}: owner só muda name
allow update: if isFamilyOwner(f) && familyActive(f)
  && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['name','updatedAt'])
  && request.resource.data.name is string
  && request.resource.data.name.size() >= 1 && request.resource.data.name.size() <= 100
  && request.resource.data.updatedAt == request.time;
```

**Create: chaves exatas** (`keys().hasOnly([...])` + `hasAll([...obrigatórias])`), para o cliente não injetar campo protegido na criação:

```
allow create: if ... 
  && request.resource.data.keys().hasOnly(['title','description','createdBy','assignedTo','status',
       'schedule','recurrence','notification','completedAt','completedBy',
       'deletedAt','createdAt','updatedAt','schemaVersion'])
  && request.resource.data.createdBy == request.auth.uid
  && request.resource.data.status == 'pending'
  && request.resource.data.completedAt == null && request.resource.data.completedBy == null
  && request.resource.data.deletedAt == null
  && request.resource.data.createdAt == request.time && request.resource.data.updatedAt == request.time
  && request.resource.data.schemaVersion == 1;
```

**Imutabilidade:** em todo update de conteúdo, `request.resource.data.createdBy == resource.data.createdBy` e `createdAt == resource.data.createdAt`; `updatedAt == request.time`.

**Papel/`access` nunca vindos do cliente:** como `households`, `members` e `families` (campos sensíveis) só aceitam a lista branca acima, não há caminho para o cliente virar `admin`, alterar `ownerId` ou `maxMembers`.

### 4.2 Validação de tipos e tamanhos (conteúdo)

| Campo | Regra |
|---|---|
| `tasks.title` | string, 1–200 |
| `tasks.description` | string, ≤ 5000 |
| `tasks.status` | `in ['pending','done']`; `done` ⇒ `completedBy == uid` e `completedAt == request.time`; `pending` ⇒ ambos `null` |
| `tasks.assignedTo` | `null` ou string de uid presente em `accessUids` da casa (ou `== family.ownerId`) |
| `tasks.schedule` | `null` ou map com `type == 'datetime'`, `scheduledAt is timestamp`, `timezone is string` (1–64) |
| `tasks.recurrence` | **`== null` no MVP** (recorrência é Fase 2; flag `features.recurringTasks` não é checado pelas Rules) |
| `tasks.notification` | map `{enabled: bool, offsetMinutes: int}`, `offsetMinutes` entre 0 e 10080 |
| `lists.name` / `items.name` | string, 1–200 |
| `lists.type` | `in ['shopping','general']` |
| `items.completed` | bool; `order` é `number` |
| `households.name`, `families.name` | string, 1–100 |
| `users.displayName` | string, 1–100; `locale` ≤ 10; `timezone` ≤ 64; `photoUrl` string ≤ 2048 ou null |
| `devices` | `fcmToken` string ≤ 4096, `platform in ['android']` (ampliar depois), doc id == `deviceId` |
| todo doc | `schemaVersion is int` (== 1 na criação); nenhum campo extra (`hasOnly`) |

Limites de tamanho protegem também o custo. Timestamps de autoria usam `request.time` (serverTimestamp do SDK).

## 5. Operações exclusivas de Cloud Functions (Admin SDK)

Clientes nunca escrevem nestes caminhos/campos; as Functions ignoram Rules, então **validam entitlement, role e status por conta própria** (contratos: T-005).

1. **Criar família** (Free automática no 1º login): `families/{f}`, `members/{owner}`, `memberships`, `billing/entitlement`, `users.freeFamilyId`, primeira casa, contadores.
2. **Criar / excluir (soft) / restaurar casa**; hard delete após 30 dias (job); `householdCount`.
3. **Gerenciar acesso por casa:** escrever `access` e `accessUids` (conceder, revogar, mudar `member`↔`admin`).
4. **Convites:** criar, revogar, aceitar (`invitations/*`, `members`, `memberships`, `memberCount`, `access`), expirar (job + TTL).
5. **Membros:** remover membro, sair da família, sync de snapshot (`displayName/photoUrl`) em `members`, limpeza de `accessUids` de quem saiu.
6. **Transferência de ownership:** `startOwnershipTransfer`, `completeOwnershipTransfer` (`ownerId`, roles, `pendingTransfer`, substituir `subscription`).
7. **Billing:** validar compra Play, escrever `billing/subscription` e `billing/entitlement`, espelhar `plan`, `maxMembers`, `maxHouseholds`.
8. **Ciclo de vida da família:** `status` (`active`/`frozen`/`deleting`), `frozenAt`, `deleteAfter`, downgrade automático, avisos, hard delete em cascata.
9. **Espelhos e contadores:** `memberships/*`, `memberCount`, `householdCount`.
10. **Activity de sistema:** `member_joined`, `member_left` (o cliente não cria estes tipos).
11. **Conta:** bloqueio/exclusão de conta do owner, `users.deletedAt`, limpeza de `devices`, preenchimento de `users.email`.
12. **Hard delete de qualquer conteúdo** (tasks, lists, items) após retenção.

## 6. Regras específicas

### 6.1 Activity (append-only)
- **Ler:** D/E/F da casa (mesma checagem de conteúdo). Queries sempre com `limit` (a Rule pode exigir `request.query.limit <= 50`).
- **Criar (C✱):** `request.auth.uid` com acesso à casa e família `active`; `actorId == request.auth.uid`; `type ∈ {task_created, task_completed, task_reopened, task_updated, task_deleted, list_created, item_added, item_completed}` (**não** `member_joined/left`); `targetType ∈ {task, list, item}` coerente com o `type`; `createdAt == request.time`; `schemaVersion == 1`; `actorName`, `targetTitle` string ≤ 200; `keys().hasOnly([type, actorId, actorName, targetType, targetId, targetTitle, createdAt, schemaVersion])`.
- **Editar/excluir:** `allow update, delete: if false` para todos, inclusive owner. Remoção só por Function (job de retenção/hard delete da casa).
- **Risco aceito** (data-model §2.3): um membro pode forjar evento **em seu próprio nome**, mas nunca em nome de outro (`actorId`) nem com `createdAt` no passado/futuro. Hardening opcional pós-MVP: `getAfter()` para exigir que o evento acompanhe a mudança do alvo no mesmo batch.

### 6.2 Soft delete
- Cliente só **seta** `deletedAt`: update com `affectedKeys().hasOnly(['deletedAt','updatedAt'])`, `resource.data.deletedAt == null`, `request.resource.data.deletedAt == request.time`. Autor ou E/F.
- **Restaurar** (`deletedAt` → `null`): mais conservador, só E/F (proposta; ver ambiguidade #8).
- Documento com `deletedAt != null` não pode receber outros updates (exceto restauração).
- `allow delete: if false` em todo conteúdo. Hard delete: só Function (job de retenção/casa expirada em 30 dias/família em `deleting`).
- Queries do app filtram `deletedAt == null` (índices em data-model §5); as Rules **não** escondem docs deletados de quem tem acesso (não é possível filtrar query por Rule sem forçar a cláusula na query), portanto soft delete não é confidencialidade.

## 7. Funções helper e custo de `get()`

Pseudocódigo (nomes sugeridos; `f`, `h` vêm do path, portanto **as queries de listagem são prováveis** pelas Rules):

```
function isSignedIn()      { return request.auth != null; }
function uid()             { return request.auth.uid; }

function familyDoc(f)      { return get(/databases/$(database)/documents/families/$(f)).data; }
function householdDoc(f,h) { return get(/databases/$(database)/documents/families/$(f)/households/$(h)).data; }

function isFamilyOwner(f)  { return isSignedIn() && familyDoc(f).ownerId == uid(); }
function familyActive(f)   { return familyDoc(f).status == 'active'; }

// membro ativo da família (usado em families/members/entitlement)
function isFamilyMember(f) {
  return isSignedIn() && get(/databases/$(database)/documents/families/$(f)/members/$(uid())).data.status == 'active';
}

// D/E: acesso via doc da casa; F: owner
function hasHouseholdAccess(f,h) {
  return isSignedIn() && (uid() in householdDoc(f,h).accessUids || isFamilyOwner(f));
}
function isHouseholdAdmin(f,h) {
  return isSignedIn() && (householdDoc(f,h).access[uid()] == 'admin' || isFamilyOwner(f));
}
function householdLive(f,h) { return householdDoc(f,h).deletedAt == null; }

function canWriteContent(f,h) { return hasHouseholdAccess(f,h) && householdLive(f,h) && familyActive(f); }
```

### 7.1 Custo em `get()`
| Operação | gets | Detalhe |
|---|---|---|
| Ler conteúdo (D/E) | **1** | doc da casa (`accessUids`); `||` evita o get da família |
| Ler conteúdo (F, se `uid ∉ accessUids`) | 2 | casa + família (owner não precisa estar em `access`) |
| Escrever conteúdo (qualquer papel) | **2** | casa (acesso, `deletedAt`, `access[uid]`) + família (`status`, `ownerId`) |
| Listar casas (D/E) | 0 | `allow list: if uid() in resource.data.accessUids` + query `where('accessUids','array-contains',uid)` |
| Listar casas (F) | 1 | `allow list: if isFamilyOwner(f)` (client escolhe a query pelo `role` em `memberships`) |
| Ler família/members/entitlement | 1 | `members/{uid}` (ou `ownerId` do doc) |
| Ler `subscription` | 1 | `isFamilyOwner` |

- Múltiplas chamadas a `get()` do **mesmo path** dentro de uma avaliação são deduplicadas e cobradas uma vez (verificar na T-012 com o emulator/profile); mesmo assim o pior caso é 2 gets por escrita e 1 por leitura, conforme data-model §7.
- **Por que `accessUids`:** Rules não fazem `get()` dependente do id de cada doc retornado numa query. Para listagem de **casas**, a Rule usa `resource.data.accessUids`; para listagem de **conteúdo**, os ids `f`/`h` são do path, então um `get()` único vale para toda a query.
- Se pesar: denormalizar `familyStatus`/`ownerId` no doc da casa via Function (escrever é raro; troca gets por escritas em N casas).
- Limites de listener/`limit` protegem custo de leitura (CLAUDE.md).

## 8. Testes para o Emulator (T-012)

Cada teste roda com `@firebase/rules-unit-testing` e um seed fixo: famílias `F1` (owner U1; members U2, U3), `F2` (owner U4; U1 é member), casas `H1`, `H2` em F1 (H1: `access = {U2: member, U3: admin}`; H2: `access = {}`), `H3` em F2 (`access = {U1: member}`), usuário `U9` sem vínculo, `F1` também testada em `frozen`.

### 8.1 Testes de negação (todos devem falhar com `permission-denied`)

**Autenticação / vínculo**
1. Não autenticado: ler `users/U1`, `families/F1`, `tasks` de H1, `invitations/{code}`.
2. Não autenticado: criar/editar qualquer doc.
3. U9 (sem vínculo) lê `families/F1`, `members`, `entitlement`, `households/H1`.
4. U9 lê/escreve `tasks`, `lists`, `items`, `activity` de H1.
5. U9 faz query `collection(F1/households/H1/tasks)` sem filtro (não deve retornar nada; deve falhar).
6. Usuário lê/escreve `users/U2` (perfil de outro).
7. Usuário lê `users/U2/memberships` e `users/U2/devices`; escreve em `devices` de outro uid.

**Acesso cruzado entre famílias/casas**
8. U2 (member de F1) lê `families/F2`, `members` de F2, `households/H3`.
9. U1 (owner de F1, member de F2 com acesso só a H3) lê `tasks` de outra casa de F2 sem acesso; e escreve como se fosse owner em F2 (`families/F2` name).
10. Owner de F1 lê/escreve conteúdo de `F2/households/H3` (papel não vaza entre famílias).
11. Criar task em `F1/households/H1` usando `familyId` de F2 no path com `createdBy` de membro de F2 (path e vínculo devem casar).
12. Mover conteúdo: criar em H1 doc cujo campo `assignedTo` é U9 (não está em `accessUids`).

**Membro sem acesso à casa**
13. U2 (C em H2) lê `households/H2` e queries de `tasks/lists/items/activity` de H2.
14. U2 cria/edita/soft-deleta task em H2.
15. U2 faz query `households` da família sem `array-contains` (deve falhar); com `array-contains U2` retorna só H1.
16. Membro removido (`members/U3.status == "removed"`, mas ainda em `accessUids` por atraso da Function): documentar/verificar comportamento (gap conhecido; ver ambiguidade #3).

**Escalada de papel**
17. U2 (`member` em H1) atualiza `households/H1` para `access.U2 = "admin"` ou adiciona U2 a `accessUids`.
18. U2 atualiza `households/H1.name` (member não renomeia casa).
19. U3 (admin da casa) tenta editar `access`/`accessUids` de H1, ou criar/excluir casa.
20. U2 atualiza `members/U2.role = "owner"` e `families/F1.ownerId = U2`.
21. U2/U3 criam doc em `members/{uid}` (auto-adicionar-se à família) ou `memberships`.
22. Não-owner (U2, U3) edita `families/F1.name`.

**Campos protegidos**
23. Owner U1 atualiza `families/F1` com `status: "active"`, `plan: "family_plus"`, `memberCount`, `householdCount`, `pendingTransfer`, `frozenAt`, `deleteAfter`.
24. Owner U1 escreve em `billing/entitlement` (ex.: `maxMembers: 99`) e `billing/subscription`.
25. U1 atualiza `users/U1.freeFamilyId`, `email`, `createdAt`.
26. Update de task incluindo `createdBy` de outro, `createdAt` alterado ou campo inexistente no schema.
27. Criar task com `createdBy != auth.uid`, `status: "done"` pré-preenchido, `completedBy` de outro, `recurrence` não-null, `schemaVersion: 2`.
28. Criar task com `title` vazio e com 201 caracteres; `notification.offsetMinutes` string; `status: "archived"`.
29. Update com `updatedAt` arbitrário (≠ `request.time`).

**Congelamento**
30. Em `F1` `frozen`: U2 e U3 (D/E) criam/editam/soft-deletam task, lista, item.
31. Em `F1` `frozen`: U1 (owner) cria/edita task e edita `families/F1.name`.
32. Em `F1` `frozen`: qualquer membro cria `activity`.
33. Em `F1` `deleting`: mesmas escritas negadas.

**Activity**
34. Forjar `actorId` (U2 grava evento com `actorId = U3`).
35. `createdAt` client-side (`Timestamp` fixo passado/futuro) em vez de `request.time`.
36. `type` inválido ou `member_joined`/`member_left` vindos do cliente; `targetType` incoerente com `type`.
37. Update e delete de qualquer activity (inclusive owner e autor).
38. Activity com campo extra ou `actorName` > 200 caracteres.

**Soft delete**
39. `delete` (hard) de task/lista/item/casa por autor, E ou F.
40. Soft delete de task alheia por D (member não-autor); soft delete com `deletedAt` ≠ `request.time`; soft delete alterando outro campo junto.
41. D restaura (`deletedAt = null`) item soft-deletado (se restaurar for só E/F).
42. Update de doc já soft-deletado (que não seja restauração).

**Billing / convites / devices**
43. U2 (member não-owner) lê `billing/subscription` de F1.
44. U9 lê `billing/entitlement` de F1.
45. U2 lê `invitations/{code}` criado por U1; U1 lista `invitations` sem `where createdBy == U1`; owner de F2 lê convite do owner de F1.
46. Qualquer cliente cria, edita ou revoga `invitations`.
47. Cliente escreve `devices/{deviceId}` com `platform` inválido ou `fcmToken` gigante.

**Regras de conteúdo por autoria**
48. U2 (member) edita task/lista criada por U3 que não está atribuída a ele (título, descrição), quando não é o `assignedTo`.
49. U2 conclui task com `completedBy = U3`.
50. U2 soft-deleta lista criada por U3.

### 8.2 Testes positivos (devem passar)
1. U1 (owner) lê `families/F1`, `members`, `entitlement`, `billing/subscription`, todas as casas (query por owner) e conteúdo de H1 e H2, mesmo sem estar em `access`.
2. U2 (member de H1) lê `families/F1`, `entitlement`, `households/H1`; query `households` com `array-contains U2` retorna só H1.
3. U2 cria task em H1 (`createdBy = U2`, `status pending`, `schedule = null`, `assignedTo = U2`) e activity `task_created` no mesmo batch.
4. U2 edita e conclui a própria task (`completedBy = U2`), e reabre; edita título respeitando 1–200.
5. U2 conclui task com `assignedTo == null` criada por U3.
6. U2 soft-deleta a própria task; U3 (admin da casa) soft-deleta task de U2 e edita qualquer lista.
7. U2 adiciona/completa/reordena itens em lista criada por U3.
8. U1 (owner) atualiza `families/F1.name` e `households/H2.name` (família `active`).
9. U3 (admin da casa) renomeia `households/H1`.
10. U2 atualiza o próprio `users/U2` (`displayName`, `locale`, `timezone`) e cria/atualiza/remove o próprio `devices/{id}`.
11. Em `frozen`: U1, U2, U3 **leem** tasks/lists/items/activity/família normalmente; U2 continua editando o próprio perfil e device.
12. U1 lista os convites com `where('createdBy','==',U1)`.
13. Usuário lê o próprio `users/{uid}/memberships`.
14. Task criada offline (batch task + activity) sincroniza com sucesso quando a família está `active`.
15. Owner atribui task a member presente em `accessUids`.

## 9. Pontos de atenção / ambiguidades (no data-model.md ou derivadas)

1. **Quem cria `users/{uid}`?** O data-model diz que o cliente escreve só `displayName/photoUrl/locale/timezone`, mas não define a criação do doc (nem `email`, `createdAt`, `schemaVersion`). Assumido aqui: Function (`bootstrapUser`/trigger de Auth) cria; cliente só faz update.
2. **`admin` de família:** o CLAUDE.md cita roles `owner/admin/member`; o data-model define família = `owner|member` e `admin` só na casa. Consistente com o ADR 0003, mas o CLAUDE.md deveria ser alinhado.
3. **Membro removido/saiu:** as Rules de conteúdo checam só `accessUids` (1 get), não `members/{uid}.status`. Se a Function falhar/atrasar a limpeza de `accessUids`, o ex-membro mantém acesso. Exigir atomicidade (transação/batch) em `removeMember`, ou aceitar o gap.
4. **Owner e `access`:** o data-model diz "acesso `admin` implícito", mas não diz se o owner entra em `access/accessUids`. Aqui: **não entra**, e as Rules usam `|| isFamilyOwner`. Isso custa 2 gets para o owner ler conteúdo e exige que o cliente use query diferente para listar casas (owner vs. member). Alternativa (owner em `access`) obriga reescrever N casas na transferência (ilimitado em Família+). Confirmar.
5. **Escopo de "edita o próprio conteúdo":** o data-model diz só "member cria, conclui e edita o próprio conteúdo". Isso impediria, literalmente, concluir tarefa atribuída a você mas criada por outro e marcar itens de lista de compras compartilhada. Aqui foi ampliado (§2.3 † e §): concluir tarefa se `assignedTo == uid` ou `null`; itens de lista colaborativos. Precisa ser confirmado (e refletido no data-model).
6. **Tipos de `activity` incompletos:** faltam `list_updated/deleted`, `item_updated/deleted`, `task_assigned`, e eventos de casa (`household_created`, etc.). Mudanças sem tipo correspondente ficam sem histórico ou exigem ampliar a lista fechada nas Rules.
7. **`member_joined/left` e `actorId == auth.uid`:** o data-model exige `actorId == auth.uid` para activity, mas esses eventos são gerados por Function (actor = sistema/convidado). Assumido: só Function escreve esses tipos (Admin SDK ignora Rules).
8. **Soft delete de tasks/lists/items:** o data-model fixa 30 dias apenas para a casa. Não define retenção/hard delete de tasks/lists/items nem quem pode **restaurar**. Aqui: hard delete só por Function e restaurar só E/F (proposta).
9. **Soft delete e leitura:** Rules não conseguem ocultar `deletedAt != null` em query; e casa soft-deleted continua no doc (`accessUids` intacto), então membros ainda "passam" nas Rules. Definir se a Function esvazia `accessUids` ao excluir a casa (recomendado) ou se as Rules checam `deletedAt` (aqui: escrita bloqueada, leitura mantida ao owner).
10. **Escritas offline e `frozen`:** operações enfileiradas offline que chegam após o congelamento serão rejeitadas. O data-model diz que o offline "nunca bloqueia", mas não define UX/rollback local dessas escritas. Também um desligamento de flag (`features.*`) não é verificável nas Rules sem `get(entitlement)` (+1 get).
11. **`features.*` do entitlement sem enforcement:** `recurringTasks` e `fullHistory` são só flags; Rules só travam `recurrence == null` no MVP. `fullHistory` (limite do Free) só pode ser imposto por `request.query.limit`/cliente, não por Rule estrita.
12. **`accessUids` é array mutável**, contrário ao princípio "nunca arrays mutáveis num doc". Mitigado por escrita rara só por Function, mas mudanças concorrentes de acesso (convites aceitos ao mesmo tempo) exigem `FieldValue.arrayUnion` ou transação.
13. **Quem lê `members`:** qualquer membro ativo da família lê a lista completa de membros (nome/foto), mesmo os sem acesso a nenhuma casa em comum. Confirmar que é aceitável em termos de privacidade.
14. **`families/{f}` `name` em `frozen`:** aqui o owner não pode renomear em `frozen`. Se for desejável, abrir exceção.
15. **`memberships.familyStatus/plan` são espelho:** sem transação com `families`, podem ficar defasados; não usar em Rules (Rules devem ler `families/{f}`).
16. **`invitations` e o requisito "só por `createdBy`":** a Rule de list exige a query `where createdBy == uid`; o owner de uma família *transferida* deixa de ser dono dos convites pendentes. Definir se a transferência revoga convites pendentes.
17. **Casas: `createdBy` sem regra de imutabilidade** no data-model, e sem definir o que ocorre com `createdBy` quando o criador sai (afeta o "próprio conteúdo" dos members que saíram: só E/F editam depois).
