---
id: T-023
title: Push de eventos compartilhados (FCM)
status: in-progress
plan: 0002
depends_on: [T-018, T-019]
area: functions
parallel_ok: true
---

## Pré-requisito (👤)
Ativar o plano **Blaze** no projeto `dev` com budget alert baixo (ex.: US$ 5). Antes disso, só emulador.

## Critérios de aceite
- [x] Registro do token FCM em `users/{uid}/devices/{deviceId}` (campo `fcmToken`; `deviceId` = id de instalação em SharedPreferences), com atualização em `onTokenRefresh` e limpeza no logout (apaga o doc e invalida o token; exclusão de conta invalida o token)
- [x] Triggers v2 de Firestore (região `southamerica-east1`): tarefa criada/atribuída/concluída, item adicionado → FCM para quem tem acesso à casa (`accessUids` ∪ owner) **exceto o autor** (`functions/src/triggers/`)
- [x] Payload só com ids e tipo (`{type, familyId, householdId, targetId}`); texto montado no app (i18n, ARB `push*`); mensagens só de dados (app em primeiro plano mostra via notificação local; em segundo plano/encerrado, handler `planlyPushBackgroundHandler`)
- [x] Remoção de tokens inválidos devolvidos pelo FCM
- [x] Respeita preferências por tipo de notificação do usuário (se existirem): **não existem ainda**; gancho único documentado em `functions/src/triggers/pushPreferences.ts`
- [x] Toque na notificação abre o destino (GoRouter: `/home/task/:id` ou `/lists/:id`) e ajusta o contexto ativo (`lib/app/push_navigation.dart`)
- [x] Nenhum dado sensível no payload nem em logs (logger com allowlist + contadores)
- [x] Testes de integração (triggers no emulador, 6 cenários, FCM trocado por `_pushOutbox` via `PUSH_FAKE_IN_EMULATOR`) e do app (14 testes)
- [ ] 👤 Teste manual em dois aparelhos (exige Blaze/deploy das Functions no `dev` e `google-services.json` do flavor)

## Notas
- Tipos: `task_created`, `task_assigned`, `task_completed`, `list_item_added` (`targetId` = id da tarefa, ou da lista no último).
- Tarefa criada atribuída a outra pessoa: o responsável recebe só `task_assigned`; os demais `task_created`.
- Limitação: o doc da tarefa não guarda quem editou. Em reatribuição o autor é aproximado por `createdBy` (criador atribuindo a si mesmo não notifica ele). Se o modelo ganhar `updatedBy`, ajustar `sharedEvents.ts`.
- `collapseKey`/id da notificação local por tipo+alvo: vários itens na mesma lista não empilham.
- Ao rodar no aparelho real, o Android 13+ ainda depende da permissão `POST_NOTIFICATIONS` (fluxo de Configurações > Lembretes, T-022).
