# Teste de integração: app (dev) + Emulator Suite

Prova, sem credenciais reais, que o app do flavor `dev` funciona de ponta a ponta contra o
Emulator Suite com as **Functions** (`functions/`) e as **Security Rules** (`firebase/firestore.rules`)
reais. Fecha a T-014 ("integração com as Functions reais"). Só fala com `127.0.0.1`/`10.0.2.2`.

## O que é real e o que é trocado
- Real: Firebase Auth/Firestore/Functions (emuladores), `FirebaseAuthRepository`, repositories
  Firestore, `CallableInvoker`, Riverpod, router, telas.
- Trocado: só o botão do Google. `FakeGoogleAdapter` (`integration_test/support/env.dart`) devolve
  `GoogleAuthProvider.credential(idToken: '<JSON>')`; o Auth Emulator aceita um JSON sem assinatura, p.ex.
  `{"sub":"uid-teste-dono","email":"dono@exemplo.test","email_verified":true,"name":"Dono Teste"}`.
  Sem `bootstrap()` completo: não roda App Check/Crashlytics/Analytics (o resto do caminho dev é igual).

## Passo a passo (Windows / PowerShell)
```powershell
# 0) Functions compiladas (Node 22) e emuladores de pé
$env:PATH="C:\dev\tools\bin;C:\Users\willk\.config\herd\bin\nvm\v22.23.3;$env:PATH"
npm --prefix functions run build
C:\dev\tools\bin\firebase.cmd emulators:start --only auth,firestore,functions --project planly-dev-d8533
#   aguarde "All emulators ready!" (o projeto DEVE ser planly-dev-d8533)

# 1) Em outro terminal, com o emulador Android (planly_pixel) ligado:
.\integration_test\run_emulator_tests.ps1        # seed + flutter test integration_test/emulator_e2e_test.dart --flavor dev
```
O script roda o seed, lê os ids que ele imprime e os passa por `--dart-define` (`SEED_*`). O app fala
com o PC em `10.0.2.2`. Rodar o teste de novo **exige** re-seed (o script já faz: o seed zera Auth e
Firestore do emulador antes). Argumentos extras do `flutter test`: `-ExtraArgs "--no-dds"`.
Ao terminar, encerre só os processos (java/node) do emulador que você iniciou.

### Seed (`integration_test/seed/seed.mjs`)
Node 22, usa o `firebase-admin` já instalado em `functions/node_modules` (nenhuma dependência nova no root).
1. Limpa Auth e Firestore (`DELETE /emulator/v1/...`, só existem no emulador).
2. Cria contas via `signInWithIdp` com o mesmo idToken JSON do app.
3. Usa as Functions reais: `bootstrapUser`, `createHousehold`, `createInvitation`, `acceptInvitation`,
   `setHouseholdAccess`. Só o "billing" é simulado com Admin SDK (plano `family` + entitlement).

Cenário (e-mails `@exemplo.test`): *dono* com "Família Dono" (plano Família, casas Principal e Praia), *ana* (membro, só
Principal), *beto* (membro sem casa); "Família Congelada" (`frozen`, Ana é membro) e "Família Excluindo" (`deleting`, Beto
é membro). A conta *novo* não existe: o teste faz o primeiro acesso pelo app.

## O que o teste cobre (`integration_test/emulator_e2e_test.dart`, 7 testes)
| Teste | Prova |
|---|---|
| A | login (credencial falsa) -> `bootstrapUser` real -> Dashboard com a casa inicial; `users/{uid}` com upsert do cliente (`locale`, `timezone`, `updatedAt` serverTimestamp aceito pelas Rules); queries memberships / households (owner sem where, membro com `array-contains`) / members `status==active`; envelope `{ok:true, familyId, householdId}` e idempotência; `details.reason` chega ao app como `BusinessFailure` (`PLAN_LIMIT_HOUSEHOLDS`, `LAST_HOUSEHOLD`, `FEATURE_NOT_IN_PLAN`, `OWNER_CANNOT_LEAVE`); Free: criar casa abre upsell sem chamar a Function |
| A2 | logout limpo e logout com escrita pendente ("Sair mesmo assim"); `terminate()+clearPersistence()` na mesma sessão **reabre apontando para o emulador** (leitura `Source.server` ok no relogin), sem cair no fallback `pendingClear`; escrita pendente descartada |
| D | membro sem casa: Rules negam listagem total de casas e `billing/subscription`, aceitam `array-contains`, entitlement e members; UI cai em `/no-access` |
| F | família `deleting` -> `/no-access` (texto de exclusão); `leaveFamily` permitido |
| E | família `frozen`: banner, leitura ok, sair da família pela UI |
| B | owner em plano Família: uso 3/4 pessoas e 2/3 casas; criar casa (Function), limite na UI e `PLAN_LIMIT_HOUSEHOLDS` no servidor, renomear (update com Rules), excluir (`deleteHousehold`), `setHouseholdAccess` pela sheet (confere `access/accessUids`), `removeMember` pela UI (idempotente; `OWNER_CANNOT_LEAVE`) |
| C | membro numa família paga: só a casa liberada, sem botões de gestão, Rules/Functions negam gestão (`NOT_OWNER`), `leaveFamily` pela UI e perda de acesso |

## Não coberto (ainda)
- Modo avião durante o bootstrap e queda de rede no meio do fluxo (o emulador do Android não tem como cortar
  só a rede do PC de forma confiável aqui; cobertos por testes de widget com fakes).
- Convites pela UI (outra task) e App Check real (emuladores ignoram).

## Problemas conhecidos do ambiente
- O AVD `planly_pixel` tem ~2,5 GB de RAM e fica lento/offline após várias execuções (sintomas: "Failed to start
  Dart Development Service", `VmServiceDisappearedException`, `device offline`, pendurar em "Installing"). Correção:
  `adb reboot` e repetir.
