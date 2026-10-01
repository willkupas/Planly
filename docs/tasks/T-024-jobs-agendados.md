---
id: T-024
title: Jobs agendados (ciclo de vida, purge, limpeza, avisos)
status: in-progress
plan: 0002
depends_on: [T-013, T-015]
area: functions
parallel_ok: true
---

## Pré-requisito (👤)
Plano **Blaze** (Cloud Scheduler). Em dev local os jobs são exportados também como funções invocáveis para teste.

## Critérios de aceite (docs/specs/cloud-functions.md §4)
- [ ] `lifecycleJob` diário: assinatura expirada → downgrade Free (só owner e ≤ 1 casa) ou `frozen` (`frozenAt`, `deleteAfter = +90d`); `regularizeBy` (plano reduzido, 30 dias); transferências pendentes expiradas
- [ ] Avisos (FCM + flag in-app): expiração D-7; frozen D+0; exclusão D-60/-30/-7/-1; sem repetição (`notifiedAt`)
- [ ] `purgeJob`: casas e conteúdo soft-deleted há 30 dias; famílias `deleting` em cascata (BulkWriter, idempotente e retomável)
- [ ] `cleanupJob`: convites `pending` vencidos → `expired`; `_rateLimits` antigos; `devices` sem uso há 90 dias
- [ ] Política TTL de `invitations.purgeAt` aplicada e validada na nuvem (`firebase deploy --only firestore:indexes`)
- [ ] Testes com dados simulados (relógio injetável) no emulador
- [ ] Logs estruturados sem dados sensíveis

## Progresso (parte Cloud Functions)
- Implementado e compilando (`npm --prefix functions run build`; `test:unit` 19/19 incl. `test/unit/lifecycle.test.ts`): `functions/src/jobs/{lifecycle,purge,cleanup,cascade,notify,jobLog,paging,scheduled,testEndpoints}.ts`, regras puras em `domain/lifecycle.ts`, relogio injetavel em `lib/clock.ts`; exports em `index.ts`; overrides de indice (collection group `deletedAt`, `devices.lastSeenAt`) em `firebase/firestore.indexes.json`.
- Testes de integracao **escritos, nao executados**: `functions/test/integration/jobs.test.ts` (usa o endpoint de teste `runScheduledJob`, so existe no emulador, relogio simulado via `nowMs`).
- Avisos: so a flag in-app (`families/{id}.notifiedAt.<tipo>`) + gancho `notify` (`jobs/notify.ts`, apenas log). FCM fica para integrar com T-023.
- Pendente: rodar integracao no emulador; deploy de indices/TTL e do scheduler (Blaze) e validacao na nuvem; `notifiedAt`/`regularizeBy` nas Rules (campos 🔒 do servidor) e em security-rules.md.
