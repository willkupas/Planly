---
id: T-025
title: Exclusão de conta e de dados (LGPD)
status: todo
plan: 0003
depends_on: [T-013]
area: functions
parallel_ok: true
---

## Objetivo
Cumprir M11 (`docs/security.md`) e `docs/specs/cloud-functions.md` §2.10.

## Critérios de aceite
- [ ] Callable `deleteAccount` (online-only, App Check): bloqueia com `OWNER_HAS_MEMBERS` se o usuário é owner de família com outros membros ativos (oferece transferir antes)
- [ ] Famílias que ele possui e sem outros membros: exclusão em cascata (casas, tarefas, listas, itens, activity, members, billing, convites)
- [ ] Famílias alheias: sai como `leaveFamily` (remove acesso, `member_left`)
- [ ] Apaga `users/{uid}/*` (devices, memberships) e o doc do usuário; anonimiza `displayName/photoUrl` em `members` e `actorName` em activity
- [ ] Apaga o usuário do Firebase Auth por último; operação idempotente e retomável (BulkWriter)
- [ ] Assinatura ativa não é cancelada pelo backend: o app avisa para cancelar na Play antes
- [ ] App: tela "Excluir conta" (`/settings/delete-account`) com confirmação dupla, reautenticação se `requires-recent-login`, explicação do que será apagado e bloqueio com explicação quando owner com membros
- [ ] Limpa persistência do Firestore, contexto ativo e lembretes locais ao concluir
- [ ] Testes de integração no emulador (owner solo, owner com membros, membro de família alheia) e de widget da tela
- [ ] Nenhum dado pessoal em logs
