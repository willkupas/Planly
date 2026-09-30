---
id: T-024
title: Jobs agendados (ciclo de vida, purge, limpeza, avisos)
status: todo
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
