# Segurança — requisitos do projeto

**Premissa:** o repositório GitHub deve ser tratado como **público**. Nada sensível entra nele, nunca.

## 1. Regra de ouro do commit
Antes de **todo** commit:
1. O hook `.githooks/pre-commit` roda `scripts/check-secrets.sh` (ativado por `git config core.hooksPath .githooks`; após clonar, rode esse comando uma vez).
2. Conferir `git status` e `git diff --cached`: só o que deve ir.
3. `--no-verify` só com justificativa escrita e revisão manual do diff.
4. Se um segredo vazar: **rotacionar primeiro** (revogar/trocar a credencial), só depois limpar o histórico. Apagar o commit não torna o segredo seguro.

## 2. O que NUNCA é versionado
`google-services.json`, `GoogleService-Info.plist`, `firebase_options*.dart`, keystores (`*.jks`, `*.keystore`), `key.properties`, `local.properties`, service accounts (`*service-account*.json`, `*firebase-adminsdk*.json`), `.env*`, chaves `*.pem/*.key/*.p12`, tokens, códigos de autorização OAuth, `purchaseToken`, dados de usuários reais. Tudo isso está no `.gitignore` e no scanner.
Configuração Firebase é regenerável: `flutterfire configure` / console. Segredos de Functions vão para **Secret Manager**; no CI, para **GitHub Actions Secrets**.

## 3. Requisitos mínimos (bloqueiam release)
| # | Requisito | Onde |
|---|---|---|
| M1 | Nenhum segredo no repositório nem no histórico | hook + CI (gitleaks) |
| M2 | Firestore Security Rules: negar por padrão, autorização por UID → membership → role; testadas no emulator | T-003, T-012 |
| M3 | Cliente nunca escreve campos de plano/role/ownership/limites | Rules + Functions |
| M4 | Operações sensíveis só em Cloud Functions, com validação de auth, papel e limites | T-005, T-013 |
| M5 | App Check ativo (Play Integrity) em staging/prod; Functions com `enforceAppCheck` | T-010 |
| M6 | Chaves de API do Firebase/Google Cloud restritas (pacote `app.with.planly*` + SHA-1) | T-007 |
| M7 | Ambientes isolados (dev/staging/prod); nunca testar em prod | T-007 |
| M8 | Assinatura validada no backend (Play Developer API); `purchaseToken` só como hash | Sprint 8 |
| M9 | Logs sem tokens, e-mail, senhas ou conteúdo de tarefas | todas as Functions |
| M10 | Release assinado com chave própria fora do repositório (Play App Signing) | Sprint 10 |
| M11 | Exclusão de conta e dados do usuário (LGPD) | T-005 §2.10 |
| M12 | Política de privacidade e termos publicados antes da Play Store | Sprint 10 |
| M13 | Dependências sem vulnerabilidades críticas conhecidas | CI (Dependabot) |

## 4. Requisitos recomendados
| # | Recomendação | Quando |
|---|---|---|
| R1 | Proteção do branch `main` (PR obrigatório, CI verde) e secret scanning + push protection do GitHub ativos | T-016 / T-009 |
| R2 | Dependabot (pub, npm, gradle, actions) e `flutter pub outdated`/`npm audit` no CI | T-009 |
| R3 | Verificação em duas etapas nas contas Google, GitHub e Play Console; conta Firebase com papéis mínimos (IAM) | agora |
| R4 | Budget alerts e alertas de anomalia de uso (abuso = custo) | T-007 |
| R5 | Rate limit nas Functions sensíveis (convites, bootstrap) | T-005 |
| R6 | Ofuscação do release (`--obfuscate --split-debug-info`) e símbolos fora do repo | Sprint 10 |
| R7 | Play Integrity para detectar app adulterado/root nas operações críticas | Sprint 9 |
| R8 | Rotação periódica de service accounts; uma por ambiente, com menor privilégio | Sprint 8 |
| R9 | Testes automatizados de negação das Rules no CI a cada PR | T-012 |
| R10 | Revisão de segurança (`/security-review`) antes de cada release | Sprint 9–10 |
| R11 | Sem `debuggable`/cleartext/backup habilitados no release (`allowBackup=false`, network security config) | T-016 |
| R12 | Armazenar só dados não sensíveis no aparelho (SharedPreferences); nada de token em texto claro | contínuo |

## 5. Observação sobre `google-services.json`
Não é segredo criptográfico, mas identifica o projeto e contém a chave de API do app. Por isso: **fora do git** e chave **restrita** por pacote + SHA-1 (M6). Cada dev/CI gera o seu.
