---
id: T-011
title: Autenticação Google
status: done
plan: 0001
depends_on: [T-007]
area: app
parallel_ok: true
---

## Critérios de aceite
- [x] `AuthRepository` abstrato com implementação Google (outros provedores plugáveis depois)
- [x] Telas splash e login; estado de sessão via provider; logout
- [ ] Documento `users/{uid}` criado/atualizado — **movido**: pelo data-model §8 o doc é criado pela Function `bootstrapUser` (T-013); o upsert dos campos do cliente (`displayName`, `photoUrl`, `locale`, `timezone`) junto do fluxo de bootstrap fica na T-014. Nada disso é feito pelo cliente na T-011.
- [x] Testes de unidade/widget (18 passando)

## Notas de implementação
- `lib/features/auth/`: `domain/` (`AuthRepository`, `AuthState` sealed Loading/SignedOut/SignedIn, `AuthUser`, `AuthProviderId`), `data/` (`FirebaseAuthRepository`, `AuthProviderAdapter`, `GoogleAuthAdapter`, `mapAuthError`), `application/auth_providers.dart` (`authRepositoryProvider`, `authStateProvider`, `currentUserProvider`, `currentUidProvider`, `SignInController`, `SignOutController`), `presentation/` (`SplashPage`, `LoginPage`).
- Novo provedor = novo `AuthProviderAdapter` + valor no enum + registro em `authRepositoryProvider`; a tela de login itera `availableProviders` (só o rótulo em `LoginPage._label` precisa de um case).
- `google_sign_in` 7.2.0 (API nova: `GoogleSignIn.instance.initialize()` + `authenticate()`; Credential Manager no Android). O `serverClientId` vem do `default_web_client_id` gerado pelo plugin google-services a partir do `google-services.json` do flavor — nenhum ID no código. Só `idToken` é usado.
- Erros: `core/error/app_failure.dart` (sealed) + `core/l10n_helpers/failure_message.dart` (AppFailure -> ARB). Cancelar o login não é erro.
- Router: `app/router/guards.dart` tem `resolveRedirect` puro (spec §2.2 ordens 1–3). **Ponto de extensão T-014:** `postAuthGuardsProvider` em `app_router.dart` (lista de `PostAuthGuard`, rodam só logado, após a regra 3) e `RouterRefreshNotifier` (hoje só escuta `authStateProvider`; adicionar `ref.listen` de bootstrap/contexto ativo). Rota inicial `/splash`.
- Logout: só `signOut` (Firebase + Google). **Não** limpa persistência do Firestore nem `activeContext` (T-014: aviso de escritas pendentes). Botão de sair provisório na AppBar do `HomePage` até existir Configurações.
- Teste sem login real: `authRepositoryProvider.overrideWithValue(FakeAuthRepository())` (`test/support/fake_auth_repository.dart`). Nenhum botão/bypass de login falso no app.
- `test/architecture_test.dart` garante que `firebase_auth`/`cloud_firestore`/`cloud_functions`/`google_sign_in` só são importados em `data/` e `core/firebase/`.
- Dependências: `google_sign_in`, `firebase_auth_mocks` (dev). `flutter analyze` limpo; `flutter test` 18/18; APK `flutter build apk --debug --flavor dev -t lib/main_dev.dart` compila e o app abre no emulador sem crash.
- `deleteAccount()` no repository só faz `user.delete()` e mapeia `requires-recent-login`; fluxo completo (Function `deleteAccount`, reautenticação) é de tarefa futura.

## Depende de teste manual do usuário
- Login Google real no emulador Android (precisa de conta Google no emulador) ou em aparelho físico: exige `google-services.json` do flavor com o **SHA-1 debug** cadastrado no app Android do Firebase e o provedor Google habilitado no Auth do projeto `planly-dev`; sem isso o erro esperado na UI é "O login não está configurado neste aparelho".
- Com o Auth Emulator (flavor dev): conferir que o usuário aparece no Emulator UI após o login e que o logout volta ao login.
- Sem internet: tocar em "Entrar com Google" deve mostrar a mensagem de sem conexão.
