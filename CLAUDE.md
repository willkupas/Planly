# Planly

App mobile de tarefas domésticas compartilhadas ("casa digital"): tarefas, listas de compras, recorrência, lembretes, histórico e notificações entre membros de uma mesma casa.

- **Foco atual:** Android. iOS fica para depois (código Flutter deve continuar multiplataforma, mas não implementamos/testamos iOS agora).
- **Idioma inicial:** pt-BR.
- **Fonte original das decisões:** [docs/00-brainstorm/AnaliseInicial.md](docs/00-brainstorm/AnaliseInicial.md) (brainstorm — não é spec; specs vivem em `docs/specs/`).

## Metodologia: Spec-Driven

1. Nada é implementado sem spec ou task correspondente.
2. **Decisões de arquitetura/design** são registradas aqui (resumo) e em `docs/decisions/` (ADR com contexto e motivo). Mudou uma decisão → atualizar o CLAUDE.md e criar novo ADR marcando o anterior como *superseded*.
3. **Specs** em `docs/specs/` (modelo Firestore, security rules, telas/rotas/providers).
4. **Plans** em `docs/plans/NNNN-nome.md`: como atacar um conjunto de tasks (ordem, dependências, riscos).
5. **Tasks** em `docs/tasks/T-NNN-nome.md` (formato em [docs/tasks/README.md](docs/tasks/README.md)). Toda tarefa pendente deve existir como arquivo; status no frontmatter: `todo | in-progress | done | blocked`.
6. Ao concluir uma task: atualizar status, spec afetada e este arquivo se houve decisão nova.
7. Agentes/subagentes: usar quando houver várias tasks independentes (ex.: spec de rules + spec Flutter em paralelo). Cada agente recebe uma task, lê CLAUDE.md + spec relevante, e atualiza o status da task ao terminar. Tasks com dependência entre si rodam em sequência.

## Stack (decidido)

- **App:** Flutter + Dart, Material 3, arquitetura feature-oriented em camadas (presentation → application → domain → data), **Riverpod** (estado/DI), **GoRouter** (navegação).
- **Backend:** Firebase — Auth, Firestore, Cloud Functions 2nd gen, FCM, App Check, Crashlytics, Analytics, Remote Config.
- **Sem API própria no MVP.** Cloud Functions é a camada server-side (convites, recorrência, billing, notificações).
- **Ambientes Firebase:** `dev`, `staging`, `prod` separados; nunca desenvolver em prod. Usar Firebase Emulator Suite (Auth, Firestore, Functions).
- **CI/CD:** GitHub + GitHub Actions (analyze → test → build → emulator tests).

## Decisões de arquitetura (vitais)

- **Offline-first via Firestore persistent cache.** Não usar JSON como banco/sync local. Local extra (preferências, onboarding) só em SharedPreferences (ou Hive/Isar se necessário). Firestore é a fonte compartilhada de verdade.
- **Modelo: User → Family → (FamilyMember, Household) → Tasks/Lists/Activity.** (Supersede o brainstorm, onde a Casa era a unidade de cobrança.)
  - **Family** = unidade de **plano/cobrança** e de pessoas. Tem exatamente **um owner** (quem paga e é admin dela). Um usuário tem **no máximo 1 Family Free** (criada automaticamente no primeiro acesso) e **quantas Families pagas quiser** (cada uma com sua assinatura); pode ainda ser membro de Families alheias.
  - **Household** ("casa") = unidade de **compartilhamento de conteúdo** (tasks/lists/activity), pertence a uma Family.
  - Um usuário pode ser **convidado (guest/member)** em Families de outros owners, sem ser owner delas. Só é owner (pagamento) da que criou.
  - Nunca `User → Tasks` direto.
- **Autorização** = Firebase UID → membership na Family → role da família (`owner`/`member`) → acesso e role na casa (`admin`/`member`). Nunca por e-mail. Só o owner gerencia plano, participantes e casas da Family.
- **Sem coleções globais para o cliente** (ex.: `/tasks`); conteúdo sob `/families/{familyId}/households/{householdId}/...` (estrutura exata a fechar na T-002).
- **Evitar conflitos:** dados mutáveis em documentos separados (`lists/{id}/items/{id}`), nunca arrays mutáveis num único doc. Conflito = last-write-wins, aceitável.
- **Task Definition ≠ Task Occurrence** (recorrência gera ocorrências; definição permanece).
- **Timezone:** salvar `timezone` IANA (ex.: `America/Sao_Paulo`) + `scheduledAt` em UTC. Nunca só "08:00".
- **Notificações:** lembretes pessoais = local notification; eventos compartilhados = Cloud Function → FCM. Recorrência não depende só do aparelho (Cloud Scheduler/Functions gera ocorrência + FCM; agendamento local é complementar).
- **Cliente nunca é autoridade** sobre `maxMembers`, `subscriptionStatus`, `role`, `ownerId` — protegidos por Rules/Functions.
- **Billing:** `Subscription` + `Entitlement` por **Family**, validados no backend (Play Billing → Function → Firestore). Modelo interno usa `maxMembers` (preços podem mudar sem alterar app). Planos sugeridos: Free (1 pessoa), Família (até 4, R$ 29,90), Família+ (até 8, R$ 49,90) — decisão comercial ainda em aberto.
- **Convites:** código/link com expiração (24h), criado e aceito via Cloud Function; deep links depois.
- **Soft delete** (`deletedAt`) em objetos importantes; casa excluída fica 30 dias antes do hard delete.
- **Todo documento:** `createdAt`/`updatedAt` (server timestamp em eventos críticos); `schemaVersion` quando necessário; IDs gerados (nunca nome/e-mail/telefone).
- **Auth no Android (MVP):** somente Google Sign-In. Camada de auth deve ser abstraída (AuthRepository com provedores plugáveis) para adicionar e-mail/senha, Apple etc. depois sem refatorar.
- **Região:** Firestore/Functions em `southamerica-east1` (imutável após criar o projeto). Multi-região por usuário não é objetivo agora; revisar se houver tração fora do Brasil.
- **i18n desde o início:** todos os textos via ARB/`flutter_localizations`, pt-BR como padrão; nenhum texto fixo no código. Outros idiomas entram depois sem retrabalho.
- **Planos (por Family):** Free = só o owner (`maxMembers=1`), 1 casa, **sem convites**. Família = até 4 pessoas, até 3 casas. Família+ = até 8 pessoas, casas ilimitadas. Entitlement tem `maxMembers` e `maxHouseholds` (null = ilimitado). Só o owner (pagante) adiciona participantes e casas. Um usuário Free pode ser convidado em Families de terceiros (o Free limita só a Family dele). Limites aplicados no backend (Rules/Functions), não no cliente.
- **Acesso por casa:** membro da Family só acessa as casas às quais o owner o vinculou. O owner acessa todas. Rules checam vínculo à casa, não só à Family. Implementação: `access` (map uid→role) + `accessUids` (array) **no doc da casa**, escritos só por Function (permite query `array-contains` e 1 `get()` por checagem). Spec completo: [docs/specs/data-model.md](docs/specs/data-model.md).
- **Roles:** família `owner|member`; casa `admin|member` (admin edita conteúdo de qualquer autor e renomeia a casa; member cria, conclui e edita o próprio). Owner = admin implícito de todas as casas.
- **Activity** é escrita pelo cliente no mesmo batch da ação (offline ok, sem Blaze), append-only, Rules validam `actorId == auth.uid`.
- **Operações só-online (Functions):** criar família/casa, convites, membros, transferência. Conteúdo (tasks/lists/items/activity) é client-direct e funciona offline.
- **`invitations/{code}`** é a única coleção de topo legível pelo cliente (só pelo `createdBy`); aceitar é via Function callable.
- **Ao expirar:** se só existe o owner e ≤ 1 casa → downgrade automático para Free (não `frozen`). **Plano reduzido** com uso acima do novo limite → período de regularização (30 dias, modo restrito: só remover membros/casas) antes de `frozen`. Free: histórico de 7 dias. Timezone: tarefa guarda o fuso de criação; UI exibe no fuso do aparelho.
- **Cancelamento/saída do owner (fluxo):**
  - Cancelar a renovação **não congela na hora**: a Family segue ativa até o fim do período pago (+ grace/account hold da Play). Avisos ao owner e aos membros antes de expirar (ex.: 7 dias).
  - Ao expirar sem transferência, a Family vira `frozen`: **todo o conteúdo fica somente leitura** (Rules bloqueiam writes por `status`). Após **90 dias** em `frozen` sem transferência, a Family é excluída (com avisos prévios).
  - **Transferência = convite:** owner indica um membro → membro aceita e assina com a própria conta Google (Play não transfere assinatura entre contas) → backend valida a compra, muda o ownership e a Family sai de `frozen`.
  - Exclusão de conta do owner é bloqueada enquanto houver outros membros sem transferência; Family só com o owner é excluída junto.
- **applicationId Android:** `app.with.planly` (empresa WITH; imutável após publicar). Flavors: `app.with.planly.dev` / `.staging` / prod sem sufixo.
- **Segurança:** Security Rules por membership/role, App Check ativo. Exemplo do brainstorm (`write: if isMember`) é só conceitual — rules reais devem ser granulares (criação/edição/exclusão/membros/plano/convites/atividade).
- **Logs:** Functions registram function/userId/householdId/operation/result/error; nunca tokens, senhas ou dados sensíveis.
- **Custo:** budget alert, listeners mínimos, queries com limite, paginação no histórico, debounce em edição de texto.

## Ambiente local (Windows)

- Flutter em `C:\dev\flutter`; Android SDK em `%LOCALAPPDATA%\Android\Sdk` (NDK 28.2 instalado à mão); emulador AVD `planly_pixel` (Android 16 com Google Play).
- Firebase CLI via wrapper `C:\dev\tools\bin\firebase.cmd` (força Node 22 e o JDK do Android Studio; o Node padrão da máquina é o 26, não suportado pelo firebase-tools).
- O `sdkmanager` novo não entende `;` nos nomes de pacote: usar `android sdk install "ndk/28.2.13676358"` (caminhos com `/`).
- Rodar no emulador: `flutter run -d emulator-5554`. Build: `flutter build apk --debug`.

## Princípios de UX

- Criar tarefa em poucos segundos; **80% dos casos em uma tela**, avançado em "Mais opções" (horário, responsável, recorrência, notificação).
- Tarefa rápida: `+` → texto → ✓ (`status=pending`, `schedule=null`, `assignedTo=currentUser`).
- Toda tela trata: Loading / Empty / Success / Error / Offline. Nunca bloquear usuário offline.
- Indicador de sync visível (Salvo neste dispositivo → Sincronizando → Sincronizado).
- "Pessoas/Atividade" é histórico, não competição (gamificação só opcional, futuro).

## Escopo

**MVP:** auth (Google), family + casa (criação automática da Family Free, convite/membros/casas para plano pago), tarefas (CRUD, concluir, atribuir, data/hora), listas + itens, offline, notificações (lembrete + evento compartilhado), histórico básico.
**Fase 2:** recorrência, intervalos, estatísticas, filtros, calendário, categorias, prioridades, anexos, comentários.
**Fase 3:** gamificação, widgets, assistentes de voz, web app, iOS.
**Fora do MVP:** backend .NET, API Gateway, SQL, microserviços, Redis, filas próprias, chat, fotos, web app.

## Riscos principais

Sincronização + recorrência + billing + permissões. Teste crítico automatizado e manual: A online / B offline cria tarefa → B volta online → A recebe.

## Estrutura de pastas

```
CLAUDE.md
docs/
  00-brainstorm/   material bruto (AnaliseInicial.md)
  decisions/       ADRs
  specs/           data-model, security-rules, flutter-app
  plans/           NNNN-nome.md
  tasks/           T-NNN-nome.md + README (formato)
lib/               (a criar) app/ core/ features/{auth,household,tasks,lists,activity,notifications,subscription}/{data,domain,presentation} shared/
functions/         (a criar) Cloud Functions
firebase/          (a criar) rules, indexes, emulator config
```

## Convenções

- Commits pequenos, por task, referenciando o ID (`T-003: ...`).
- Código Flutter: telas não conhecem Firestore; acesso via Repository → provider Riverpod.
- Testes: unit (domínio/recorrência/datas), widget (criar/concluir tarefa, listas), integration (login → casa → tarefa → concluir; offline → online).

## Status

Ver `docs/tasks/` e o plan ativo em `docs/plans/`. Plan atual: [0001-fundacao-android](docs/plans/0001-fundacao-android.md).
