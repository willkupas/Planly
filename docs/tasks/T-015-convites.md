---
id: T-015
title: Convites
status: in-progress
plan: 0001
depends_on: [T-013, T-014]
area: functions
parallel_ok: false
---

## Critérios de aceite
- [x] Callables `createInvitation` / `revokeInvitation` / `acceptInvitation` (cloud-functions.md §2.5–2.6) com código de 10 chars e expiração de 24h (servidor)
- [x] Bloqueado no Free (backend: `FEATURE_NOT_IN_PLAN`)
- [ ] UI mostra upsell no Free — pendente: telas
- [x] Ao aceitar, os `grants` do convite definem o acesso às casas (`access`/`accessUids`, HouseholdAccess)
- [ ] Telas de convidar / aceitar código / lista de convites — pendente: telas
- [~] Limpeza de convites expirados: política TTL em `invitations.purgeAt` (= `expiresAt + 7d`) declarada em `firebase/firestore.indexes.json` (**pendente: aplicar/validar na nuvem**); o job diário que marca `expired` (cleanupJob, §4.3) **não** foi feito (Scheduler exige Blaze; a marcação já acontece de forma preguiçosa no aceite e convites vencidos não contam no limite)
- [x] Testes com emulator (unit + integração)

## Entregue (servidor)
`functions/src/callable/invitations.ts`, `domain/invitations.ts` (alfabeto, geração CSPRNG, normalização), `config.ts` (`INVITE_LINK_BASE`), `lib/db.ts` (paths), exports em `index.ts`. Testes: `functions/test/unit/invitations.test.ts`, `functions/test/integration/invitations.test.ts`.

## Notas e decisões
- Convite: `invitations/{code}` com `familyId, grants, createdBy, status, expiresAt, purgeAt, createdAt, schemaVersion` (código só como docId, nunca em campo nem em log).
- **Alfabeto de 31 símbolos** (2-9 + A-Z sem I, L, O) em vez de 32: excluir os ambíguos não fecha base32 exato; ~49,5 bits (spec: ~50). Sorteio via `crypto.randomInt`. Colisão de docId: até 5 tentativas.
- **Link**: `https://planly.app/join/<code>` é PLACEHOLDER (domínio não existe; deep links/App Links ficam para depois). Configurável em `config.ts` / env `INVITE_LINK_BASE`. `expiresAt` é devolvido como string ISO-8601.
- **Pendentes no limite**: `memberCount + pendentes ativos < maxMembers`; consulta só por igualdade (`familyId`, `status`), expiração filtrada em memória (sem índice composto; teto de 100 lidos).
- **Rate limit de aceite** roda em transação separada, antes da principal, para contar também as tentativas inválidas (senão o erro desfaria o incremento e o limite não frearia sondagem). O de criação (20/h por família) fica na transação principal.
- **Não distingue** inexistente / usado / revogado / expirado-já-marcado / formato inválido: todos `INVITE_NOT_FOUND`. Só o primeiro aceite de um convite vencido devolve `INVITE_EXPIRED` (e grava `expired`; o retorno é feito após o commit, pois lançar dentro da transação desfaria a marcação).
- `acceptInvitation` repetido pelo mesmo uid (ainda membro ativo) = sucesso idempotente, sem duplicar efeitos. Membro `removed` pode voltar com novo convite (reativa `members/{uid}`).
- Casa excluída entre a criação e o aceite: grant ignorado (sem acesso restrito); `householdIds` retornado só lista as concedidas. Se nenhuma restar, o usuário entra sem acesso a casas (owner concede depois).
- `revokeInvitation` por quem não é o criador/owner atual, ou sobre convite já aceito/expirado, devolve `INVITE_NOT_FOUND` (não vaza existência; restritivo). Repetir em convite já revogado = sucesso.
- `grants`: 1..20, sem casa repetida, role `admin|member`; casa de outra família/inexistente/excluída = `HOUSEHOLD_NOT_FOUND`.
- A notificação ao owner ("convite aceito", §2.6 passo 4) depende do FCM (Sprint 6) e não foi implementada.
- Formato do `fieldOverrides` TTL segue o padrão do export do Firebase CLI; **não validado** contra a nuvem (precisa de projeto/login). Ativar o TTL também exige `firebase deploy --only firestore:indexes` (e leva até ~24h para começar a apagar). O arquivo foi reformatado (indentação) ao inserir o bloco.
