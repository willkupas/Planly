# APK de release para instalar na mão (sideload)

Para testar no celular real sem Play Store. Usa o flavor `dev` falando com o projeto Firebase **na nuvem**
(`planly-dev-d8533`), não com os emuladores.

## Uma vez só
1. **Chave de assinatura local** (nunca vai para o git): `%USERPROFILE%\.planly\planly-sideload.jks` e
   `android/key.properties` (ignorado pelo git) apontando para ela. Sem o `key.properties`, o build cai na chave de debug.
   Faça backup do `.jks` e da senha: trocar de chave obriga a desinstalar o app e perder os dados locais.
2. **SHA-1 da chave** cadastrado no app Android do projeto Firebase (sem isso o login Google falha com
   `DEVELOPER_ERROR`): `firebase apps:android:sha:create <appId> <sha1>`. Para ver o SHA-1:
   `keytool -list -v -keystore <jks> -alias planly`.
3. **App Check:** a Play Integrity não valida APK instalado fora da Play. O build usa o provedor de debug
   (`--dart-define=APP_CHECK_DEBUG=true`, ignorado no flavor prod). No primeiro uso o aparelho gera um token; cadastre-o
   em Console Firebase → App Check → Apps → app Android → ⋮ → Manage debug tokens (leia no logcat com
   `adb logcat -d | Select-String "debug token"` com o celular em modo depuração USB, ou veja o erro de rede).

## Gerar o APK
```powershell
flutter build apk --release --flavor dev -t lib/main_dev.dart --dart-define=USE_CLOUD=true --dart-define=APP_CHECK_DEBUG=true
```
Saída: `build/app/outputs/flutter-apk/app-dev-release.apk` (~60 MB). Instalar: copiar para o celular e abrir
(permitir "instalar apps desconhecidos"), ou com o celular em depuração USB:
`adb install -r build/app/outputs/flutter-apk/app-dev-release.apk`. Atualizar = instalar por cima (mesma chave).

## Cuidados
- Não compartilhe o APK fora de pessoas de confiança: ele fala com o projeto `dev` e usa o provedor de debug do App Check.
- Release público (T-030) usa outro keystore (upload key da Play), flavor `prod` e Play Integrity.
