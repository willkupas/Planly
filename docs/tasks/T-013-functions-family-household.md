---
id: T-013
title: Functions de Family, casas e membros
status: done
plan: 0001
depends_on: [T-005, T-008]
area: functions
parallel_ok: true
---

## Critérios de aceite
- [x] `bootstrapUser` (Free + casa inicial, idempotente, rate limit 5/h), `createHousehold`, `deleteHousehold` + `restoreHousehold`, `setHouseholdAccess` (era "grantHouseholdAccess" no rascunho; nome do spec §2.4), `removeMember` + `leaveFamily`
- [x] Limites via Entitlement (`billing/entitlement`, fallback no plano da família); erros tipados (`reason` estável, spec §1.1)
- [x] Logs estruturados sem dados sensíveis (`lib/logger.ts`: só function/uid/familyId/householdId/operation/result/errorReason/durationMs)
- [x] Testes com emulator (Auth + Firestore + Functions): 34 integração + 8 unitários

## Estrutura entregue (`functions/src/`)
`config.ts` (região + initializeApp, importado primeiro) · `callable/{bootstrapUser,households,members}.ts` · `domain/{plans,errors,model}.ts` · `lib/{callable,authz,db,logger,rateLimit,validate,activity}.ts`. Pronto para receber `callable/invitations|transfer|billing|account`, `jobs/`, `triggers/`.

## Como rodar os testes
Node 22 no PATH e Firebase CLI disponível. Em `functions/`:
- `npm run test:unit` (sem emulador)
- `npm run test:integration` (build + `emulators:exec` com `firebase.test.json`: auth 9099, firestore 8080, functions 5001, hub 4400, logging 4510, UI desligada; projeto `demo-planly-functions`)
- `npm test` roda os dois. Testes compilam para `.test-build/` (fora do `lib/` de deploy; ambos ignorados no git).

## Notas e decisões
- **App Check no emulador NÃO é ignorado** (firebase-functions 7): com `enforceAppCheck: true` o emulador exige o header `X-Firebase-AppCheck` (decodifica sem verificar). Os testes enviam um JWT falso. Consequência para o app em dev/emulador: o cliente precisa enviar token de App Check (provider debug) mesmo contra emuladores; se isso atrapalhar, decidir depois (não afrouxar em prod). Há teste garantindo recusa sem o header.
- `healthCheck` (esqueleto) continua sem `enforceAppCheck` (comportamento anterior preservado).
- Autorização: não-membro -> `NOT_MEMBER`; membro ativo não-owner -> `NOT_OWNER` (ambos `permission-denied`). Membro `removed` conta como não-membro.
- `FAMILY_FROZEN` vale para `status != active` (inclui `deleting`). `removeMember`/`leaveFamily` funcionam em qualquer status.
- Idempotência adicional (escolha): `deleteHousehold` de casa já excluída, `restoreHousehold` de casa ativa, `removeMember`/`leaveFamily` de quem já saiu -> sucesso sem efeito. Permite retry seguro após falha de rede.
- `restoreHousehold` fora da janela de 30 dias -> `HOUSEHOLD_NOT_FOUND` (o hard delete é iminente).
- `removeMember`: além de `access/accessUids` das casas ativas, remove o uid de `deletedAccess` das casas excluídas (senão voltaria a ter acesso ao restaurar). Limpa `pendingTransfer` se o destinatário for removido. Activity `member_left` é gravada em cada casa ativa onde o membro tinha acesso (`actorId` = membro que saiu, mesmo quando removido pelo owner).
- `setHouseholdAccess` usa `FieldPath('access', uid)` + `arrayUnion/arrayRemove` dentro de transação; `targetUid == owner` -> `invalid-argument` (reason `targetUid`), pois o owner é implícito.
- Activity de sistema usa `targetType: "household"` para `household_created` (o enum do data-model §3.11 só lista task/list/item/member; Function ignora Rules, mas o spec de data-model deveria ganhar `household`).
- `bootstrapUser`: família criada com nome `"Minha família"` e casa `"Minha casa"` (textos default server-side, pt-BR; o app pode renomear depois). Rate limit conta toda chamada (inclusive idempotentes): o app deve chamar `bootstrapUser` só quando faltar `freeFamilyId`/memberships, não a cada abertura. O id da casa devolvido na re-chamada é a mais antiga não excluída (leitura de até 50 casas ordenadas por `createdAt`, sem índice composto).
- Nenhum índice composto novo é necessário (só consultas por campo único/`orderBy createdAt`).
- Fora de escopo (T-015/sprints futuras): convites, transferência, billing, jobs, `deleteAccount`.

## Desvios/ambiguidades para revisão
1. Nome `setHouseholdAccess` (spec) em vez de `grantHouseholdAccess` (rascunho da task).
2. `household` como `targetType` de activity (ver acima).
3. Emulador exige header de App Check (ver acima).

## Decisão do coordenador (App Check no emulador)
O firebase-functions 7 exige o header `X-Firebase-AppCheck` também no emulador quando `enforceAppCheck: true`; o app em dev não consegue o token sem registrar o token de debug no console. Decisão: `ENFORCE_APP_CHECK` (`functions/src/config.ts`) é **sempre verdadeiro na nuvem**; no emulador fica desligado, salvo `ENFORCE_APP_CHECK_IN_EMULATOR=true`. `npm run test:integration` (via `scripts/run-integration.mjs`) liga a variável, então os testes continuam provando a recusa sem token. O `firebase` precisa estar no PATH (wrapper `C:\dev\tools\bin`).
