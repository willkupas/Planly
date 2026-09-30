---
id: T-008
title: Firebase Emulator Suite
status: done
plan: 0001
depends_on: [T-007]
area: firebase
parallel_ok: true
---

## Critérios de aceite
- [x] `firebase.json` com emuladores Auth (9099), Firestore (8080), Functions (5001) e UI (4000); `.firebaserc` com aliases dev/staging/prod
- [x] `firebase/firestore.rules` provisório (nega tudo) e `firebase/firestore.indexes.json`; regras reais na T-012
- [x] Esqueleto de Functions em TypeScript (`functions/`, Node 22, firebase-functions 7, firebase-admin 14, 0 vulnerabilidades no `npm audit`) com `healthCheck` para validar o ambiente
- [x] App dev aponta para os emuladores (`lib/core/firebase/emulators.dart`, chamado só quando `Flavor.useEmulators`); `INTERNET` + cleartext só no manifest de debug
- [x] Documentado como subir o ambiente local (abaixo)
- [x] Verificado: Firestore nega acesso sem login (403); `healthCheck` → UNAUTHENTICATED sem token e `{ok:true}` com usuário do Auth emulator

## Como usar
```bash
# 1) subir os emuladores (primeira vez baixa os JARs; precisa Node 22 + JDK — o wrapper resolve)
firebase emulators:start --only auth,firestore,functions --project planly-dev-d8533
# UI: http://127.0.0.1:4000
# 2) rodar o app dev no emulador Android (host 10.0.2.2 por padrão)
flutter run --flavor dev -t lib/main_dev.dart
# celular físico: adb reverse tcp:9099 tcp:9099 (idem 8080, 5001) ou --dart-define=EMULATOR_HOST=<ip-do-pc>
```
Functions: depois de editar `functions/src`, `npm --prefix functions run build` (ou `build:watch`).

## Notas
- Na primeira execução a descoberta das Functions estourou o timeout de 10 s porque o download da UI concorria; na segunda subiu normal.
- A conexão app ↔ emuladores só é exercitada de ponta a ponta no login (T-011); aqui só se verificou boot sem erro.
- `package.json` das Functions tem `overrides: { uuid: ^11.1.1 }` para corrigir advisory moderado transitivo (gaxios); remover quando o firebase-admin atualizar.
- Dados do emulador são descartados ao encerrar (sem `--export-on-exit`).
