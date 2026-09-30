---
id: T-010
title: App Check, Crashlytics e Analytics
status: in-progress
plan: 0001
depends_on: [T-007]
area: app
parallel_ok: true
---

## Critérios de aceite — feito
- [x] App Check ativado no bootstrap: Play Integrity em release; provedor de debug em builds debug (`lib/core/firebase/observability.dart`). Emuladores ignoram App Check
- [x] Crashlytics ligado a `FlutterError.onError` e `PlatformDispatcher.onError`; plugin Gradle de símbolos aplicado
- [x] Analytics inicializado; coleta de crashes/analytics **desligada em debug e no flavor dev**, ligada só em release de staging/prod
- [x] Nenhum dado sensível em logs/eventos (regra registrada no código); sem propriedades de usuário com e-mail/nome
- [x] Verificado no emulador: app abre sem crash e o App Check gera o token de debug (token nunca vai para git/chat)

## Pendente — depende de ações no console (👤) ou de builds de release
- [ ] 👤 **Enforcement do App Check**: no console Firebase → App Check, registrar cada app Android com **Play Integrity** (exige o SHA-256 da assinatura de release / Play App Signing) e só então ativar enforcement em Firestore e Functions. Até lá **não ativar** (quebraria o app). Hoje as Rules negam tudo, então não há exposição
- [ ] 👤 Registrar o **token de debug** de cada desenvolvedor/emulador no console (App Check → Apps → menu → Gerenciar tokens de debug) quando o enforcement for ligado; o token aparece no logcat (`DebugAppCheckProvider`)
- [ ] 👤 Ativar a **Play Integrity API** no projeto Google Cloud de staging/prod
- [ ] Functions com `enforceAppCheck: true` (cloud-functions.md §1): entra com a T-013, mas só é efetivo após o item de enforcement
- [ ] Eventos de analytics do produto (`house_created`, `task_created` …) entram junto das features, sem PII
- [ ] Testar Crashlytics em release (forçar um crash de teste em staging) na fase de qualidade (Sprint 9)

## Notas
- Sem enforcement, App Check apenas emite tokens; a proteção real começa ao ligar o enforcement.
- Analytics do Firebase/Google Analytics: confirmar textos na política de privacidade (M12).
