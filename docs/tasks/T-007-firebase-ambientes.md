---
id: T-007
title: Firebase dev/staging/prod + FlutterFire + flavors
status: in-progress
plan: 0001
depends_on: [T-006]
area: firebase
parallel_ok: false
---

## Objetivo
Três projetos Firebase em `southamerica-east1` ligados ao app via flavors.

## Critérios de aceite
- [x] Projetos criados: dev `planly-dev-d8533`, staging `planly-staging`, prod `planly-prod-be861`; Firestore `(default)` em `southamerica-east1` nos três (verificado pela CLI)
- [x] Authentication com provedor Google ativado nos três
- [x] Flavors `app.with.planly.dev` / `.staging` / prod; entry points `main_dev/staging/prod.dart`
- [x] Apps Android registrados nos três projetos; SHA-1 da chave de debug cadastrado (Google Sign-In)
- [x] `google-services.json` por flavor em `android/app/src/<flavor>/` (fora do git) lido pelo plugin `google-services`; `Firebase.initializeApp()` no bootstrap; verificado no emulador (dev)
- [x] Proteção contra exclusão ativada no Firestore de prod
- [ ] 👤 Budget alerts no console (Google Cloud Billing → Budgets) — exige conta de faturamento; fazer antes do Blaze
- [ ] 👤 Restringir as chaves de API (M6): console Google Cloud → APIs e serviços → Credenciais → chave "Android key (auto created by Firebase)" → restringir a aplicativos Android (`app.with.planly*` + SHA-1)
- [ ] Antes do release: cadastrar os SHA-1/SHA-256 da chave de upload e da assinatura do Play App Signing
- [ ] Verificar `staging` e `prod` no emulador (só o `dev` foi executado)

## Notas
- Sem `firebase_options.dart`: no Android o plugin google-services lê o JSON do flavor. Se um dia houver iOS/web, rodar `flutterfire configure` (arquivo também no `.gitignore`).
- Para regenerar o JSON: `firebase apps:sdkconfig ANDROID <appId> --project <id> --out android/app/src/<flavor>/google-services.json`.
- App IDs Firebase (não secretos): dev `1:186564572120:android:da3d6c145b8392abf078ad`, staging `1:342107778902:android:75e8a42557995e06ea30f7`, prod `1:387943331975:android:1b161a9082322302d72022`.
- O `.firebaserc` com aliases será criado na T-008.
