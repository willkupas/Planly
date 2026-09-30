---
id: T-023
title: Push de eventos compartilhados (FCM)
status: todo
plan: 0002
depends_on: [T-018, T-019]
area: functions
parallel_ok: true
---

## Pré-requisito (👤)
Ativar o plano **Blaze** no projeto `dev` com budget alert baixo (ex.: US$ 5). Antes disso, só emulador.

## Critérios de aceite
- [ ] Registro do token FCM em `users/{uid}/devices/{deviceId}` (Rules já permitem), com atualização em `onTokenRefresh` e limpeza no logout
- [ ] Triggers v2 de Firestore (região `southamerica-east1`): tarefa criada/atribuída/concluída, item adicionado → FCM para quem tem acesso à casa (`accessUids` ∪ owner) **exceto o autor**
- [ ] Payload só com ids e tipo (`{type, familyId, householdId, targetId}`); texto montado no app (i18n)
- [ ] Remoção de tokens inválidos devolvidos pelo FCM
- [ ] Respeita preferências por tipo de notificação do usuário (se existirem)
- [ ] Toque na notificação abre o destino (deep link interno via GoRouter) e ajusta o contexto ativo
- [ ] Nenhum dado sensível no payload nem em logs
- [ ] Testes de integração (triggers no emulador) e teste manual em dois aparelhos
