---
id: T-025
title: Exclusão de conta e de dados (LGPD)
status: done
plan: 0003
depends_on: [T-013]
area: functions
parallel_ok: true
---

## Objetivo
Cumprir M11 (`docs/security.md`) e `docs/specs/cloud-functions.md` §2.10.

## Critérios de aceite
- [x] Callable `deleteAccount` (online-only, App Check): bloqueia com `OWNER_HAS_MEMBERS` se o usuário é owner de família com outros membros ativos (oferece transferir antes)
- [x] Famílias que ele possui e sem outros membros: exclusão em cascata (casas, tarefas, listas, itens, activity, members, billing, convites)
- [x] Famílias alheias: sai como `leaveFamily` (remove acesso, `member_left`)
- [x] Apaga `users/{uid}/*` (devices, memberships) e o doc do usuário; anonimiza `displayName/photoUrl` em `members` e `actorName` em activity
- [x] Apaga o usuário do Firebase Auth por último; operação idempotente e retomável (BulkWriter)
- [x] Assinatura ativa não é cancelada pelo backend: o app avisa para cancelar na Play antes (app: aviso na tela; "Gerenciar assinatura" só abre instruções, sem billing ainda)
- [x] App: tela "Excluir conta" (`/settings/delete-account`) com confirmação dupla, reautenticação se `requires-recent-login`, explicação do que será apagado e bloqueio com explicação quando owner com membros
- [x] Limpa persistência do Firestore, contexto ativo e lembretes locais ao concluir (app; `SessionActions.endSessionAfterAccountDeleted`)
- [x] (servidor) Testes de integração no emulador: `functions/test/integration/account.test.ts` (owner solo, owner com membros, membro alheio, retomada, REQUIRES_RECENT_LOGIN, rate limit)
- [x] Teste de widget da tela (16 testes em `test/delete_account_test.dart` e `test/delete_account_mapper_test.dart`)
- [x] Nenhum dado pessoal em logs

## Notas de implementação (app)
- Testes de widget da tela feitos (`test/delete_account_test.dart`, `test/delete_account_mapper_test.dart`); **pendente**: integração no emulador (owner solo, owner com membros, membro alheio) e o item correspondente acima.
- Decisão: `AuthRepository.deleteAccount()` (que só fazia `user.delete()`) foi removido. O servidor apaga o usuário no Auth; o cliente só faz `signOut` + limpeza local. Entrou `AuthRepository.reauthenticate()` (refaz o login do provedor atual via adapter e renova o ID token) e `AccountRepository.deleteAccount()` (callable, `features/auth`).
- `reason: REQUIRES_RECENT_LOGIN` do servidor é mapeado para `RequiresRecentLoginFailure` (`firebase_error_mapper.dart`); a tela reautentica e repete a chamada uma única vez (sem laço).
- Bloqueio de owner com participantes: a UI antecipa usando `Family.memberCount > 1` das famílias possuídas e também trata `OWNER_HAS_MEMBERS` do servidor. Transferência de ownership ainda não existe: o texto orienta a transferir/remover participantes e oferece "Ir para Membros".
- "Gerenciar assinatura" é só informativo (diálogo com o caminho na Play); sem `url_launcher`/billing neste passo.
