---
id: T-012
title: Implementar Security Rules + testes
status: done
plan: 0001
depends_on: [T-003, T-008]
area: firebase
parallel_ok: true
---

## Critérios de aceite
- [x] `firebase/firestore.rules` e `firestore.indexes.json` conforme spec
- [x] Testes no emulator: permissões positivas e todos os testes de negação da T-003 (50 negações `N01..N50` + 15 positivos `P01..P15`; 65/65 passando)
- [ ] Executa na CI (pendente: o workflow manual da T-009 ainda não chama estes testes; ver "Como rodar")

## Como rodar
```
# Node 22 no PATH; a partir da raiz do repo
cd firebase/rules-tests && npm install && cd ../..
firebase emulators:exec --config firebase/firebase.rules-test.json --only firestore --project demo-planly-rules "npm --prefix firebase/rules-tests test"
```
Config dedicada `firebase/firebase.rules-test.json` (Firestore 8181, hub 4401, logging 4501, UI desligada) para não colidir com o emulador de dev. Runner: `node:test` + `@firebase/rules-unit-testing` (v5) + `firebase` (v12). `npm audit`: 0 vulnerabilidades.

## Entregue
- `firebase/firestore.rules`: deny-by-default, helpers do spec §7, create por chaves exatas, update por lista branca (`affectedKeys().hasOnly`), `family.status == 'active'` para toda escrita de conteúdo, soft delete/restauração, activity append-only, invitations só `list` por `createdBy`.
- `firebase/firestore.indexes.json`: 4 índices compostos do data-model §5.
- `firebase/rules-tests/` (seed fixo do spec §8) e `firebase/firebase.rules-test.json`.

## Notas / desvios / ambiguidades
Onde o spec era ambíguo, foi escolhida a opção mais restritiva.
1. **Prevalece data-model §8 sobre security-rules.md:** tipos de activity ampliados (`task_assigned`, `list_deleted`, `item_deleted` entram; `household_created`/`member_*` só Function); `targetType` coerente com o prefixo do `type`.
2. **Activity `get`/`list`:** `list` exige `limit <= 50` (activity) / `<= 100` (tasks, lists) / `<= 200` (items); query sem `limit` é negada. O cliente deve sempre usar `limit`.
3. **`families/{f}`:** só `get` (sem `list`); o app descobre as famílias via `users/{uid}/memberships`. Owner renomeia sem `get()` extra (usa `resource.data.ownerId/status`).
4. **`invitations`:** só `list` com `where createdBy == uid`; `get` por código é negado até ao criador (o convidado envia o código à Function).
5. **`users/{uid}` update** exige `updatedAt == request.time` (o cliente deve enviar `serverTimestamp()`); `users` não tem `list`/`create`/`delete` (criação pela Function `bootstrapUser`).
6. **Tasks:** `description` opcional; `notification` obrigatória; `schedule` só com chaves `type/scheduledAt/timezone`. `assignedTo` só é revalidado no update quando muda. Concluir/reabrir por não-autor: só `status/completedAt/completedBy/updatedAt` e apenas se `assignedTo == uid` ou `null`. Edição completa: autor ou admin da casa/owner. Reabrir não exige ser quem concluiu.
7. **Lists:** update de autor/admin pode alterar `name` e `type`. Items: não se verifica se a lista-pai está soft-deleted (gap aceito).
8. **Casa soft-deleted:** D/E não leem conteúdo (`deletedAt != null`), owner lê; escrita bloqueada. A leitura do próprio doc da casa continua dependendo de `accessUids` (a Function o esvazia, data-model §8 #7).
9. **Devices:** `deviceId` deve casar `^[A-Za-z0-9_-]{1,128}$`; `lastSeenAt == request.time` a cada escrita; `createdAt` imutável.
10. **Seed:** adicionada a casa **H4** em F2 (`access = {}`) além das do spec, porque N09 exige "outra casa de F2 sem acesso" para U1 (U1 tem acesso `member` em H3).
11. **N10:** como U1 tem acesso `member` a H3 (seed do spec), a leitura de H3 é legítima; o teste verifica que o papel de owner de F1 não vaza (não renomeia H3, não edita/soft-deleta tarefa de outro, não lista casas de F2).
12. **N16 (gap conhecido):** membro `removed` ainda em `accessUids` perde leitura de família/members/entitlement, mas **mantém leitura de conteúdo** até a Function limpar `access/accessUids`. Teste documenta o comportamento; mitigação = `removeMember` atômico (data-model §8 #3).
13. **N23:** o teste usa `status: 'frozen'` (e não `'active'`, como no spec) porque gravar o mesmo valor atual é no-op e não aparece em `affectedKeys`. Em família congelada, qualquer update do owner já é negado (N31).
14. **Não implementados (Fase 2 / fora de escopo):** `tasks/{t}/occurrences` (negado pelo catch-all); `regularizeBy` (data-model §8 #20) é campo protegido por estar fora da lista branca de `families`. `features.*` do entitlement não são checados (§8 #14).
15. Índice de activity: `actorId ASC, createdAt DESC` (igualdade primeiro); a consulta só por `createdAt DESC` usa o índice automático.
16. Prints de "evaluation error" no log do emulador durante negações (ex.: `isNow(null)`/campo ausente) são esperados: erro de avaliação = negação.
17. **CI:** falta plugar esses testes no workflow (T-009/T-017); comando acima é o que deve rodar (requer JDK + Node 22).
