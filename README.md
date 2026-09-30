# Planly

Aplicativo Android de **tarefas domésticas compartilhadas**: uma "casa digital" onde a família divide tarefas, listas de compras, lembretes e histórico, com funcionamento **offline** e sincronização automática.

> **Regra de UX do produto:** criar uma tarefa deve levar poucos segundos (`+` → texto → ✓).

## Estado atual

| Área | Situação |
|---|---|
| Login com Google, Family/casas/membros, convites | Implementado e testado |
| Tarefas, listas e itens, atividade | Implementado e testado |
| Offline e sincronização, lembretes locais | Implementado e testado (falta roteiro manual em aparelho) |
| Exclusão de conta (LGPD) | Implementado e testado |
| Push (FCM), jobs agendados | Planejado — exige plano Blaze do Firebase |
| Assinatura (Play Billing) e publicação | Planejado |

O andamento detalhado está em [docs/tasks/PASSO-A-PASSO.md](docs/tasks/PASSO-A-PASSO.md).

## Como o projeto é organizado (spec-driven)

Nada é implementado sem spec ou task. A documentação é parte do produto:

| Onde | O quê |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Decisões de arquitetura, regras de trabalho, convenções e segurança (leitura obrigatória) |
| [docs/specs/](docs/specs) | Modelo de dados, Security Rules, app Flutter e Cloud Functions |
| [docs/decisions/](docs/decisions) | ADRs (decisões e motivos) |
| [docs/plans/](docs/plans) | Planos de execução (0001 fundação · 0002 conteúdo · 0003 conta, assinatura e publicação) |
| [docs/tasks/](docs/tasks) | Uma task por arquivo (`T-NNN`) e o quadro [PASSO-A-PASSO](docs/tasks/PASSO-A-PASSO.md) |
| [docs/testing/](docs/testing) | Como rodar os testes de integração e os roteiros manuais |
| [docs/security.md](docs/security.md) | Requisitos de segurança mínimos e recomendados |
| [docs/00-brainstorm/](docs/00-brainstorm) | Material bruto inicial (não é spec) |

## Stack

- **App:** Flutter (Dart), Material 3, Riverpod, GoRouter, i18n por ARB (pt-BR).
- **Backend:** Firebase — Authentication, Cloud Firestore (cache offline), Cloud Functions 2ª geração (TypeScript, Node 22), FCM, App Check, Crashlytics, Analytics.
- **Região:** `southamerica-east1`. **Sem API própria** no MVP.
- **Modelo:** `User → Family (plano/cobrança) → Household (casa) → tarefas, listas, atividade`. A Family tem um owner (quem paga); membros só veem as casas às quais foram vinculados.

## Ambientes e flavors

| Flavor | `applicationId` | Projeto Firebase | Entry point |
|---|---|---|---|
| `dev` | `app.with.planly.dev` | `planly-dev-d8533` (**usa emuladores locais**) | `lib/main_dev.dart` |
| `staging` | `app.with.planly.staging` | `planly-staging` | `lib/main_staging.dart` |
| `prod` | `app.with.planly` | `planly-prod-be861` | `lib/main_prod.dart` |

Nunca desenvolva contra o projeto de produção.

## Pré-requisitos (Windows)

- Flutter SDK (stable) e Android Studio com Android SDK, NDK e um emulador com Google Play (AVD com Play Services, para o login com Google).
- **Node.js 22** e **JDK 21+** (o do Android Studio serve) e o **Firebase CLI**.
  > O `firebase-tools` não suporta Node 26. Use Node 22 (ex.: via `nvm`) para o CLI e para as Functions.
- Git. O passo a passo do ambiente que usamos está em [CLAUDE.md](CLAUDE.md#ambiente-local-windows).

## Começando

```bash
# 1) dependências e traduções
flutter pub get
flutter gen-l10n
npm --prefix functions install

# 2) configuração do Firebase (NÃO versionada): baixe o google-services.json de cada flavor
#    do console do Firebase para android/app/src/<flavor>/google-services.json
#    (ou: firebase apps:sdkconfig ANDROID <appId> --project <id> --out <caminho>)

# 3) hook de segurança (uma vez por clone)
git config core.hooksPath .githooks
```

### Rodar o app (flavor dev + emuladores)

```bash
# terminal 1 — emuladores Firebase (Auth, Firestore, Functions)
npm --prefix functions run build
firebase emulators:start --only auth,firestore,functions --project planly-dev-d8533

# terminal 2 — app no emulador Android
flutter run --flavor dev -t lib/main_dev.dart
```

Em celular físico: `adb reverse tcp:9099 tcp:9099` (idem `8080` e `5001`) ou `--dart-define=EMULATOR_HOST=<ip-do-pc>`.

## Testes

| O quê | Comando |
|---|---|
| Análise estática | `flutter analyze` |
| App (unit + widget) | `flutter test` |
| Functions (unit) | `npm --prefix functions run test:unit` |
| Functions (integração, com emuladores) | `npm --prefix functions run test:integration` |
| Security Rules (65 testes) | veja [docs/tasks/T-012](docs/tasks/T-012-implementar-security-rules.md) |
| App ↔ emuladores (ponta a ponta) | [docs/testing/integracao-emulador.md](docs/testing/integracao-emulador.md) |
| Dois clientes offline | [docs/testing/offline-dois-clientes.md](docs/testing/offline-dois-clientes.md) |

O `firebase` precisa estar no PATH ao rodar os testes de integração.

## Segurança — leia antes de contribuir

- Este repositório deve ser tratado como **público**. Nunca versione segredos, chaves, tokens, keystores, service accounts, `google-services.json`, `firebase_options*.dart` nem arquivos `.env`.
- Um hook de pré-commit (`scripts/check-secrets.sh`) bloqueia segredos conhecidos. Não use `--no-verify` sem justificativa. Se algo vazar, **rotacione a credencial primeiro**.
- Autorização sempre por UID → membership → role; nunca por e-mail. O cliente nunca é autoridade sobre plano, papéis ou limites (Rules e Functions).
- Detalhes e checklist: [docs/security.md](docs/security.md).

## Convenções

- Commits pequenos, por task, com o ID (`T-014: …`).
- Telas nunca importam SDKs do Firebase: acesso por Repository → provider Riverpod (há teste de arquitetura).
- Toda query ao Firestore tem `limit` (as Rules negam sem ele).
- Textos apenas via ARB (`lib/l10n/`), nenhum texto fixo no código.

## Licença

Projeto privado de WITH. Todos os direitos reservados.
