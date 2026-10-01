# APK de release para instalar na mão (sideload)

Para testar no celular real sem Play Store. Usa o flavor `dev` falando com o projeto Firebase **na nuvem**
(`planly-dev-d8533`), não com os emuladores. O testador só instala o APK e entra com a conta Google.

## Como funciona (decisões de 2026-10-01)
- **App Check não é exigido no `dev`** (`functions/src/config.ts`: `IS_DEV_CLOUD`). Motivo: APK fora da Play não passa no
  Play Integrity. Staging e prod exigem (M5). Proteção que continua no dev: login Google + Security Rules (66 testes).
  Antes de qualquer lançamento (T-029) o enforcement é validado em staging.
- **Plano de teste por lista de e-mails** (só dev/emulador): documento `_testers/{email em minúsculas}` com o campo
  `plan` (`family` ou `family_plus`). Ao entrar (bootstrapUser) com e-mail verificado pelo Google, a família nasce com
  o plano; quem já entrou como Free sobe no próximo login/abertura do app. Nunca rebaixa nem sobrepõe assinatura real.
  Prod ignora a lista; as Rules negam qualquer acesso do app a `_testers`.

## Cadastrar um testador (Console Firebase, projeto planly-dev)
Firestore Database → **Start collection** (primeira vez) ou abra `_testers` → **Add document**:
- **Document ID:** o e-mail da conta Google, em minúsculas (ex.: `fulano@gmail.com`)
- Campo `plan` (string): `family_plus` (8 pessoas, casas ilimitadas) ou `family` (4 pessoas, 3 casas)

Para tirar o plano de teste de alguém, apague o documento e (se ela já entrou) ajuste o plano da família no console.

## Uma vez só (já feito para este PC)
1. **Chave de assinatura local** (nunca vai para o git): `%USERPROFILE%\.planly\planly-sideload.jks` e
   `android/key.properties` (ignorado pelo git). Sem o `key.properties` o build cai na chave de debug.
   Faça backup do `.jks` e da senha: trocar de chave obriga a desinstalar o app (perde os dados locais).
2. **SHA-1 da chave** no app Android do Firebase (`firebase apps:android:sha:create <appId> <sha1>`) **e** na restrição da
   chave de API do Google Cloud (Credenciais → chave Android → Restrições de aplicativos). Sem isso, login Google/Firebase falham.

## Gerar o APK
```powershell
flutter build apk --release --flavor dev -t lib/main_dev.dart --dart-define=USE_CLOUD=true
```
Saída: `build/app/outputs/flutter-apk/app-dev-release.apk` (~60 MB). Instalar: enviar o arquivo ao celular e abrir
(permitir "instalar apps desconhecidos"), ou `adb install -r <apk>` com depuração USB. Atualizar = instalar por cima.

## Cuidados
- Distribua só para pessoas de confiança: o APK fala com o projeto `dev` (sem App Check).
- Release público (T-030): outro keystore (upload key da Play), flavor `prod`, Play Integrity e teste interno na Play.
