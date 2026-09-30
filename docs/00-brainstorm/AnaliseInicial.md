# App de Tarefas Compartilhadas — Documento de Implementação

**Versão:** 1.0
**Plataformas:** Android / iOS
**Frontend:** Flutter
**Backend:** Firebase
**Arquitetura:** Offline-first + Cloud Sync
**Modelo de negócio:** Freemium / cobrança por participantes
**Idioma inicial:** Português-Brasil

---

# 1. Visão geral

O produto será um aplicativo mobile para organização de tarefas domésticas compartilhadas.

A ideia central é criar uma "casa digital", na qual pessoas pertencentes à mesma família/casa possam compartilhar:

* tarefas;
* listas de compras;
* listas gerais;
* tarefas recorrentes;
* lembretes;
* responsáveis;
* histórico de atividades;
* notificações;
* informações de conclusão.

Exemplo:

> João cria "Comprar leite".
>
> Maria recebe a tarefa.
>
> Maria compra o leite e marca como concluída.
>
> João recebe a atualização.
>
> O histórico registra que Maria concluiu a tarefa às 18:32.

Outro exemplo:

> Lista "Mercado".
>
> * Leite ✓
> * Café ✓
> * Arroz
> * Sabão
> * Papel higiênico
>
> Cada pessoa pode alterar a lista e todos os participantes recebem a atualização.

---

# 2. Objetivo do produto

O aplicativo deve ser:

1. simples;
2. rápido;
3. intuitivo;
4. extremamente fácil de usar;
5. funcional mesmo sem internet;
6. sincronizado automaticamente;
7. adequado para famílias;
8. multiplataforma;
9. barato de operar;
10. escalável.

A regra principal de UX deve ser:

> **Criar uma tarefa deve levar poucos segundos.**

Não devemos transformar uma tarefa doméstica simples em um formulário complexo.

---

# 3. Decisão arquitetural

## Stack recomendada

### Aplicativo

* Flutter
* Dart
* Material 3
* arquitetura Clean/Feature-oriented
* Riverpod para gerenciamento de estado
* GoRouter para navegação

### Firebase

* Firebase Authentication
* Cloud Firestore
* Firebase Cloud Messaging
* Cloud Functions 2nd Gen
* Firebase App Check
* Firebase Crashlytics
* Firebase Analytics
* Remote Config

O Firebase possui integração oficial com Flutter e oferece os principais serviços necessários para esse projeto.

---

# 4. Arquitetura geral

```text
                    ┌─────────────────────┐
                    │       Flutter       │
                    │      Android/iOS    │
                    └──────────┬──────────┘
                               │
                  ┌────────────┴────────────┐
                  │                         │
            Firebase Auth             Firestore SDK
                  │                         │
                  │                 Offline Persistence
                  │                         │
                  │                         ▼
                  │                  Cache local
                  │                         │
                  └────────────┬────────────┘
                               │
                         Internet
                               │
                    ┌──────────▼──────────┐
                    │      Firebase       │
                    │                     │
                    │ Authentication      │
                    │ Firestore            │
                    │ Cloud Functions      │
                    │ FCM                  │
                    │ App Check            │
                    │ Crashlytics          │
                    └─────────────────────┘
```

---

# 5. Offline-first

Esta é uma das decisões mais importantes do projeto.

## Não recomendo JSON como banco local principal

A ideia de armazenar os dados em JSON funciona conceitualmente, mas criaria diversos problemas:

* controle de concorrência;
* atualização parcial;
* corrupção do arquivo;
* busca;
* filtros;
* atualização de registros;
* sincronização;
* conflitos;
* migração de schema;
* múltiplos dispositivos.

O Firestore para Android/iOS já possui persistência offline e mantém uma cópia local dos dados utilizados pelo aplicativo. Alterações feitas offline são sincronizadas quando a conexão volta.

Portanto:

```text
Flutter
   ↓
Firestore SDK
   ↓
Cache persistente local
   ↓
Firestore Cloud
```

é preferível a:

```text
Flutter
   ↓
JSON
   ↓
Sistema próprio de sincronização
   ↓
Firebase
```

---

# 6. O que acontece sem internet

O comportamento esperado será:

```text
Usuário cria tarefa
       ↓
Firestore SDK
       ↓
Persistência local
       ↓
UI atualizada imediatamente
       ↓
Internet indisponível
       ↓
Alteração fica pendente
       ↓
Internet retorna
       ↓
Firestore sincroniza
       ↓
Outros dispositivos recebem atualização
```

Isso permite que o usuário continue usando o aplicativo normalmente.

Exemplo:

Às 14:00:

```text
Internet: OFF

João:
☑ Comprar leite

```

O aplicativo imediatamente mostra:

```text
✓ Comprar leite
```

Às 14:07:

```text
Internet: ON
```

A alteração é enviada automaticamente ao Firebase.

---

# 7. Um cuidado importante: conflitos

O Firestore possui comportamento de sincronização próprio e, para múltiplas alterações no mesmo documento, utiliza uma estratégia de "last write wins".

Para esse aplicativo isso é aceitável na maioria dos casos.

Porém, devemos evitar armazenar muita informação mutável dentro de um único documento.

Por exemplo, uma lista de mercado não deve ser:

```json
{
  "items": [
    {
      "name": "Leite",
      "completed": true
    },
    {
      "name": "Café",
      "completed": false
    }
  ]
}
```

Preferível:

```text
lists/{listId}
lists/{listId}/items/{itemId}
```

Assim, João pode marcar "Leite" enquanto Ana adiciona "Café", sem que os dois estejam necessariamente alterando o mesmo documento.

---

# 8. Conceito de conta

Cada pessoa possui uma conta.

A conta é identificada pelo Firebase Authentication.

Podemos suportar inicialmente:

* Google;
* Apple;
* e-mail/senha.

Firebase Authentication possui suporte oficial a esses provedores no Flutter.

---

# 9. Conta não é a mesma coisa que família

Esse é um conceito importante.

Uma pessoa possui:

```text
User
```

Uma casa possui:

```text
Household
```

E uma relação entre os dois:

```text
HouseholdMember
```

Exemplo:

```text
User
├── João
├── Maria
└── Pedro

Household
└── Casa Silva

HouseholdMember
├── João → Casa Silva
├── Maria → Casa Silva
└── Pedro → Casa Silva
```

Isso permitirá futuramente que uma mesma pessoa participe de mais de uma casa.

Exemplo:

```text
João
├── Casa
└── Apartamento
```

---

# 10. Modelo de dados

Sugestão de estrutura:

```text
users
  {userId}

households
  {householdId}

households
  └── members
       {userId}

households
  └── tasks
       {taskId}

households
  └── lists
       {listId}

households
  └── lists
       └── items
            {itemId}

households
  └── activity
       {activityId}

users
  └── devices
       {deviceId}

subscriptions
  {subscriptionId}
```

---

# 11. User

```json
{
  "id": "uid_123",
  "displayName": "João Silva",
  "email": "joao@email.com",
  "photoUrl": "...",
  "createdAt": "...",
  "updatedAt": "..."
}
```

Não devemos confiar no cliente para definir informações sensíveis.

O `uid` deve vir do Firebase Authentication.

---

# 12. Household

```json
{
  "id": "house_123",
  "name": "Casa Silva",
  "ownerId": "uid_123",
  "createdAt": "...",
  "updatedAt": "...",
  "status": "active"
}
```

---

# 13. Household Member

```json
{
  "userId": "uid_456",
  "role": "member",
  "status": "active",
  "joinedAt": "...",
  "displayName": "Maria",
  "photoUrl": "..."
}
```

Roles:

```text
owner
admin
member
```

## Owner

Pode:

* alterar plano;
* adicionar/remover participantes;
* excluir a casa;
* alterar configurações.

## Admin

Pode:

* adicionar tarefas;
* alterar listas;
* convidar pessoas;
* gerenciar conteúdo.

## Member

Pode:

* criar tarefas;
* concluir tarefas;
* adicionar itens;
* editar conteúdo permitido.

---

# 14. Task

Uma tarefa deve ter uma estrutura flexível.

```json
{
  "id": "task_123",
  "title": "Tirar o lixo",
  "description": "",
  "createdBy": "uid_123",
  "assignedTo": "uid_456",

  "status": "pending",

  "schedule": {
    "type": "specific_datetime",
    "scheduledAt": "2026-09-30T19:00:00Z"
  },

  "recurrence": null,

  "notification": {
    "enabled": true,
    "type": "at_time"
  },

  "createdAt": "...",
  "updatedAt": "...",
  "completedAt": null,
  "completedBy": null
}
```

---

# 15. Tipos de agendamento

O aplicativo deve suportar:

### Imediata

```text
Comprar pão
```

Sem horário.

---

### Data específica

```text
30/09/2026
14:30
```

---

### Hoje

```text
Hoje às 19:00
```

---

### Relativa

```text
Em 30 minutos
```

---

### Recorrente

```text
A cada 30 minutos
```

ou:

```text
A cada 2 horas
```

ou:

```text
Todo dia às 08:00
```

ou:

```text
Toda segunda às 19:00
```

ou:

```text
Todo dia útil
```

---

# 16. Recorrência

Sugestão de modelo:

```json
{
  "type": "weekly",
  "interval": 1,
  "weekDays": [
    1,
    3,
    5
  ],
  "time": "19:00",
  "timezone": "America/Sao_Paulo"
}
```

Tipos:

```text
none
interval
daily
weekly
monthly
```

Para intervalos:

```json
{
  "type": "interval",
  "unit": "minute",
  "value": 30
}
```

---

# 17. Tarefa recorrente ≠ tarefa concluída

É importante separar:

```text
Task Definition
```

de:

```text
Task Occurrence
```

Exemplo:

```text
Regar plantas
Toda segunda, quarta e sexta
```

A definição permanece.

As ocorrências são:

```text
30/09  ✓
02/10  pending
04/10  pending
```

Isso facilita histórico, estatísticas e notificações.

---

# 18. Listas

Uma lista é um agrupador de tarefas menores.

Exemplo:

```text
Mercado

☑ Leite
☑ Café
☐ Arroz
☐ Sabão
☐ Papel higiênico
```

Estrutura:

```text
lists/{listId}

lists/{listId}/items/{itemId}
```

Lista:

```json
{
  "id": "list_123",
  "name": "Mercado",
  "type": "shopping",
  "createdBy": "uid_123",
  "createdAt": "...",
  "updatedAt": "..."
}
```

Item:

```json
{
  "id": "item_123",
  "name": "Leite",
  "completed": false,
  "completedBy": null,
  "completedAt": null,
  "createdBy": "uid_123",
  "createdAt": "..."
}
```

---

# 19. Histórico

Uma funcionalidade muito interessante é registrar eventos.

Exemplo:

```text
Maria concluiu "Comprar leite"
João adicionou "Café" à lista Mercado
Pedro criou "Lavar carro"
Maria alterou a data de "Tirar lixo"
```

Estrutura:

```text
households/{householdId}/activity/{activityId}
```

Exemplo:

```json
{
  "type": "task_completed",
  "actorId": "uid_123",
  "targetId": "task_456",
  "targetType": "task",
  "createdAt": "..."
}
```

Isso alimenta a tela:

> **Atividade da casa**

---

# 20. Painel por usuário

A tela "Pessoas" pode apresentar:

```text
Você
8 tarefas concluídas

João
5 tarefas concluídas

Maria
7 tarefas concluídas
```

E:

```text
Esta semana

Você      ████████ 8
João      █████ 5
Maria     ███████ 7
```

Importante:

Essa funcionalidade deve ser apresentada como **histórico/atividade**, e não necessariamente como competição.

Posteriormente pode existir uma opção de gamificação, mas não deve ser obrigatória.

---

# 21. Convites

A família precisa de um mecanismo simples.

Sugestão:

```text
Criar casa
     ↓
"Adicionar pessoas"
     ↓
Gerar convite
     ↓
Link / código
     ↓
Outra pessoa abre
     ↓
Login
     ↓
Aceitar convite
     ↓
Entrou na casa
```

Exemplo:

```text
Código da casa:

ABCD-92XZ
```

Ou:

```text
https://app.exemplo.com/join/ABC123
```

O código deve ter expiração.

Exemplo:

```text
válido por 24 horas
```

---

# 22. Não usar e-mail como mecanismo de autorização

O e-mail serve para identificação.

Não devemos fazer:

```text
if email == "maria@gmail.com"
```

A autorização deve ser baseada em:

```text
Firebase UID
        ↓
Household Membership
        ↓
Role
```

---

# 23. Segurança

O Firestore deve ser protegido por Security Rules.

Conceito:

```text
Usuário autenticado
       ↓
Pertence ao household?
       ↓
SIM
       ↓
Pode acessar os dados daquela casa
```

Um usuário não deve conseguir simplesmente alterar:

```json
{
  "householdId": "outra-casa"
}
```

para acessar dados de outra família.

---

# 24. Firestore Security Rules

Conceito:

```text
isAuthenticated()
isMember(householdId)
isOwner(householdId)
isAdmin(householdId)
```

Exemplo conceitual:

```text
match /households/{householdId} {

    allow read:
        if isMember(householdId);

    allow write:
        if isMember(householdId);

}
```

Depois devemos criar regras específicas para:

* criação;
* edição;
* exclusão;
* membros;
* plano;
* convites;
* atividades.

---

# 25. App Check

O Firebase App Check deve ser ativado.

A ideia é dificultar chamadas indevidas aos recursos Firebase a partir de aplicações que não sejam o aplicativo legítimo.

Especialmente importante quando começarmos a ter:

* Cloud Functions;
* operações pagas;
* APIs;
* criação de convites;
* controle de assinatura.

Cloud Functions callable também pode receber automaticamente tokens de autenticação, FCM e App Check quando disponíveis.

---

# 26. Precisamos de uma API própria?

## Minha recomendação inicial: NÃO.

A primeira versão pode funcionar assim:

```text
Flutter
   │
   ├── Firebase Auth
   │
   ├── Firestore
   │
   ├── FCM
   │
   └── Cloud Functions
```

Não precisamos começar com:

```text
Flutter
   ↓
API .NET
   ↓
Firebase
```

Isso adicionaria:

* servidor;
* autenticação duplicada;
* deploy;
* logs;
* manutenção;
* custo;
* latência;
* código adicional.

---

# 27. Onde usar Cloud Functions

Cloud Functions será nosso backend server-side.

Exemplos:

```text
createHousehold
inviteMember
acceptInvite
removeMember
createSubscription
validateSubscription
sendNotification
processRecurringTask
cleanupExpiredInvites
```

Também pode executar tarefas agendadas.

Cloud Functions suporta execução por eventos, HTTPS e jobs agendados.

---

# 28. API futura

Caso o produto cresça, podemos introduzir:

```text
Flutter
   ↓
API Gateway
   ↓
Backend
   ↓
Firebase / Google Cloud
```

Isso faria sentido se posteriormente tivermos:

* painel administrativo;
* integrações;
* parceiros;
* web app;
* APIs públicas;
* billing complexo;
* relatórios;
* integrações externas.

Mas não deve ser requisito do MVP.

---

# 29. Notificações

Usaremos:

**Firebase Cloud Messaging (FCM)**

O FCM suporta Android e iOS e possui integração oficial com Flutter.

Exemplos:

```text
⏰ Tarefa chegando

"Tirar o lixo"
em 10 minutos
```

ou:

```text
🛒 Atualização da lista

Maria adicionou:
"Sabão em pó"
```

ou:

```text
✓ Tarefa concluída

João concluiu:
"Lavar o carro"
```

---

# 30. Notificações locais x push

Devemos separar dois tipos.

## Local Notification

Para:

```text
Lembrete pessoal no próprio aparelho
```

Exemplo:

```text
Em 30 minutos
```

Pode ser agendado localmente.

## Push Notification

Para:

```text
Eventos compartilhados
```

Exemplo:

```text
Maria concluiu uma tarefa
```

ou:

```text
João adicionou item na lista
```

Arquitetura:

```text
Tarefa pessoal
      ↓
Local Notification

Evento compartilhado
      ↓
Cloud Function
      ↓
FCM
      ↓
Outros dispositivos
```

---

# 31. Um detalhe importante sobre recorrência

Não devemos depender exclusivamente do telefone para executar uma recorrência.

Exemplo:

```text
Todo dia às 08:00
```

Se o usuário:

* desligar o celular;
* remover o app da memória;
* restringir notificações;
* ficar vários dias offline;

o sistema local pode falhar em alguns cenários.

Portanto:

```text
Recurring Task
        ↓
Cloud Scheduler / Cloud Functions
        ↓
gera ocorrência
        ↓
FCM
```

E o dispositivo também pode manter um agendamento local como mecanismo complementar.

---

# 32. Fuso horário

Nunca salvar apenas:

```text
08:00
```

para eventos absolutos.

Salvar:

```text
timezone:
America/Sao_Paulo
```

e, quando necessário:

```text
scheduledAt:
UTC timestamp
```

O aplicativo deve converter para o timezone local do usuário.

---

# 33. Sincronização

O Firestore deve ser a fonte compartilhada de verdade.

Modelo:

```text
                 Firestore
                     ▲
                     │
              sincronização
                     │
       ┌─────────────┴─────────────┐
       │                           │
    Celular A                   Celular B
       │                           │
    cache local                 cache local
```

Não precisamos desenvolver manualmente:

```text
JSON export
JSON import
sync queue
retry queue
```

para a primeira versão.

---

# 34. Quando usar armazenamento local adicional

Ainda pode ser útil ter armazenamento local para:

* preferências;
* onboarding;
* filtros;
* configurações;
* rascunhos;
* estado temporário;
* cache de UI.

Podemos usar:

```text
SharedPreferences
```

ou:

```text
Hive / Isar
```

dependendo da necessidade.

Mas o estado compartilhado deve continuar sendo Firestore.

---

# 35. Estrutura Flutter

Sugestão:

```text
lib/

  app/
    app.dart
    router.dart
    theme.dart

  core/
    constants/
    errors/
    utils/
    services/

  features/

    auth/
      data/
      domain/
      presentation/

    household/
      data/
      domain/
      presentation/

    tasks/
      data/
      domain/
      presentation/

    lists/
      data/
      domain/
      presentation/

    activity/
      data/
      domain/
      presentation/

    notifications/
      data/
      domain/
      services/

    subscription/
      data/
      domain/
      presentation/

  shared/
    widgets/
    models/
```

---

# 36. Arquitetura interna

Sugestão:

```text
Presentation
     ↓
Application
     ↓
Domain
     ↓
Data
     ↓
Firebase
```

Exemplo:

```text
TaskPage
   ↓
TaskController
   ↓
TaskRepository
   ↓
Firestore
```

O Flutter não deve conhecer detalhes de Firestore em todas as telas.

---

# 37. Gerenciamento de estado

Recomendo:

**Riverpod**

Porque permite:

* dependency injection;
* estados reativos;
* testes;
* streams;
* fácil integração com repositories;
* separação entre UI e lógica.

Exemplo conceitual:

```dart
final tasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchTasks();
});
```

A tela simplesmente observa:

```text
tasksProvider
```

---

# 38. Fluxo inicial

## Primeiro acesso

```text
Splash
 ↓
Login
 ↓
Google / Apple
 ↓
Perfil
 ↓
Criar ou entrar em uma casa
```

---

# 39. Criar casa

Tela:

```text
Como quer chamar sua casa?

[ Casa Silva              ]

[ Criar casa ]
```

Depois:

```text
Sua casa foi criada!

Adicione sua família
```

---

# 40. Dashboard

Tela principal:

```text
Bom dia, João 👋

Hoje

4 tarefas
2 listas

──────────────────

Próximas tarefas

○ Tirar o lixo
  Hoje · 19:00

○ Regar plantas
  Em 30 min

✓ Lavar louça
  Concluída

──────────────────

Listas

🛒 Mercado
5/8 itens

──────────────────

＋ Adicionar tarefa
```

---

# 41. Criar tarefa

A UX deve ser muito rápida.

Primeiro campo:

```text
O que precisa fazer?

[ Comprar pão                     ]
```

Depois:

```text
Quando?

[ Agora ]
[ Hoje ]
[ Escolher data ]
[ Repetir ]
```

Depois:

```text
Quem?

[ Eu ]
[ João ]
[ Maria ]
[ Qualquer pessoa ]
```

E:

```text
🔔 Notificar
```

---

# 42. Tarefa rápida

Deve existir um modo ainda mais simples.

Usuário toca:

```text
+
```

Digite:

```text
Comprar leite
```

Pressiona:

```text
✓
```

Pronto.

A tarefa é criada como:

```text
status = pending
schedule = null
assignedTo = currentUser
```

---

# 43. Lista de compras

Fluxo:

```text
Nova lista
 ↓
Mercado
 ↓
Adicionar item
 ↓
Leite
Café
Arroz
Sabão
```

Cada item pode ser concluído independentemente.

---

# 44. Compartilhamento

A lista possui:

```text
Participantes

✓ João
✓ Maria
✓ Pedro
```

Todos conseguem ver a lista em tempo real.

---

# 45. Atividade

Tela:

```text
Atividade

Hoje

09:32
Maria concluiu
"Lavar louça"

09:18
João adicionou
"Leite" ao Mercado

08:43
Pedro criou
"Tirar o lixo"
```

---

# 46. Licenciamento

Aqui existe uma questão importante.

Eu **não criaria uma licença por usuário isoladamente**.

Criaria:

```text
Household Subscription
```

A casa possui um plano.

Exemplo:

```text
FREE
1 participante
```

ou:

```text
FAMILY
N participantes
```

Se quiser manter exatamente sua ideia:

```text
1 pessoa
R$ 0

2 pessoas
R$ 20/mês

3 pessoas
R$ 30/mês

4 pessoas
R$ 40/mês
```

etc.

Porém, do ponto de vista de produto, eu recomendo considerar uma cobrança por **faixa de família**, pois cobrar exatamente R$ 10 por usuário pode criar uma experiência comercial um pouco artificial.

Por exemplo:

```text
Grátis
1 pessoa

Família
até 4 pessoas
R$ 29,90/mês

Família+
até 8 pessoas
R$ 49,90/mês
```

Isso é uma decisão comercial, não uma exigência técnica.

---

# 47. Billing

Aqui existe um ponto crítico.

Se a assinatura desbloqueia recursos digitais dentro do aplicativo, precisamos considerar as regras de cobrança das lojas.

Na App Store brasileira existem comissões específicas para compras de bens/serviços digitais, e o tratamento depende do programa/forma de cobrança.

No Google Play também existem estruturas de taxas e programas diferentes, inclusive mudanças recentes de taxas por região.

Portanto, não devemos construir o billing assumindo simplesmente:

```text
R$ 30 recebidos
=
R$ 30 no seu caixa
```

A modelagem financeira deve considerar:

```text
Preço bruto
-
comissão da loja
-
impostos
-
taxas
=
receita líquida
```

---

# 48. Modelo recomendado de assinatura

O backend deve possuir:

```text
Subscription
```

com:

```json
{
  "householdId": "house_123",
  "plan": "family",
  "maxMembers": 4,
  "status": "active",
  "provider": "apple",
  "externalId": "...",
  "expiresAt": "...",
  "createdAt": "...",
  "updatedAt": "..."
}
```

O aplicativo nunca deve ser a autoridade final sobre:

```text
"esta conta está paga"
```

Essa informação deve ser validada no backend.

---

# 49. Licença

Uma abstração útil:

```text
Entitlement
```

Exemplo:

```json
{
  "householdId": "house_123",
  "maxMembers": 4,
  "features": {
    "sharedTasks": true,
    "lists": true,
    "history": true,
    "recurringTasks": true
  }
}
```

Assim, futuramente podemos criar:

```text
Free
Family
Family+
Business
```

sem reescrever o aplicativo.

---

# 50. O usuário gratuito

Seu requisito:

> Uma pessoa não terá custo.

É perfeitamente compatível com o modelo.

Por exemplo:

```text
Free
1 usuário
```

O usuário pode:

* criar tarefas;
* criar listas;
* utilizar offline;
* receber notificações;
* armazenar dados localmente;
* utilizar sua conta Firebase.

Quando quiser adicionar outra pessoa:

```text
"Adicionar Maria"
```

o aplicativo informa:

```text
Sua casa passará a ter 2 participantes.

Plano necessário:
R$ XX/mês
```

---

# 51. "Os dados ficam apenas local / Google / Apple"

Aqui existe uma correção conceitual importante.

O Google/Apple login **não deve ser tratado como armazenamento dos dados da aplicação**.

Google e Apple fornecem identidade/autenticação.

Não devemos depender de:

```text
Google Account
```

como banco de dados da aplicação.

Para compartilhar dados entre pessoas, precisamos de um backend.

Portanto:

```text
Google/Apple
    ↓
Identidade

Firebase
    ↓
Dados compartilhados

Firestore cache
    ↓
Dados offline
```

---

# 52. Privacidade

O sistema deve seguir o princípio:

> Cada usuário só acessa as casas das quais participa.

Não devemos disponibilizar uma coleção global como:

```text
/tasks
```

para o cliente.

Preferível:

```text
/households/{householdId}/tasks/{taskId}
```

Isso também simplifica as regras de segurança.

---

# 53. Exclusão de conta

Precisamos implementar:

```text
Excluir minha conta
```

Fluxo:

```text
Usuário solicita exclusão
        ↓
Validação
        ↓
Excluir / anonimizar dados pessoais
        ↓
Tratar casas pertencentes ao usuário
        ↓
Tratar assinaturas
        ↓
Excluir Firebase Auth
```

Deve existir uma política clara para casas cujo proprietário sai.

---

# 54. Exclusão de casa

Somente owner:

```text
Configurações
 ↓
Excluir casa
 ↓
Confirmar
```

Preferencialmente:

```text
soft delete
```

durante determinado período.

Exemplo:

```text
30 dias
```

Depois:

```text
hard delete
```

Isso reduz o risco de perda acidental.

---

# 55. Observabilidade

Instalar desde o começo:

### Crashlytics

Para:

* crashes;
* exceptions;
* problemas de produção.

### Analytics

Eventos como:

```text
app_open
login
house_created
invite_created
invite_accepted
task_created
task_completed
list_created
item_completed
subscription_started
subscription_cancelled
```

### Logs

Cloud Functions deve registrar:

```text
function
userId
householdId
operation
result
error
```

Nunca registrar:

* tokens;
* senhas;
* dados sensíveis;
* informações desnecessárias.

---

# 56. Firebase Pricing

O Firebase possui franquias gratuitas para vários serviços.

Atualmente, a página de preços informa, por exemplo, para Firestore Standard:

* até 1 GiB armazenado sem custo;
* até 50 mil leituras/dia;
* até 20 mil escritas/dia;
* até 20 mil exclusões/dia;
* até 10 GiB/mês de egress.

Cloud Functions também possui franquias gratuitas de uso.

Para um aplicativo de tarefas domésticas, isso significa que o custo de infraestrutura inicialmente tende a ser pequeno em relação à receita das assinaturas.

Mas não devemos tratar "Firebase grátis" como garantia de custo zero.

O consumo precisa ser monitorado.

---

# 57. Controle de custos

Devemos configurar:

```text
Firebase Budget Alert
```

e monitorar:

```text
Firestore Reads
Firestore Writes
Firestore Storage
Functions Invocations
Network
FCM
```

Além disso:

* evitar listeners desnecessários;
* evitar consultas sem limite;
* evitar documentos enormes;
* usar paginação no histórico;
* manter listas e itens separados;
* evitar escrever a cada alteração de texto;
* fazer debounce em operações de edição.

---

# 58. Exemplo de custo lógico

Imagine:

```text
10.000 famílias
3 usuários/família
```

Teríamos:

```text
30.000 usuários
```

Mas isso não significa:

```text
30.000 servidores
```

O Firebase escala conforme o uso.

O custo será determinado principalmente por:

```text
leituras
escritas
armazenamento
egress
Functions
```

e não simplesmente pela quantidade de usuários.

---

# 59. Monetização

Sugestão inicial:

## Free

```text
1 pessoa
Tarefas
Listas
Offline
Notificações
Histórico básico
```

## Family

```text
Até 4 pessoas
Tudo do Free
Compartilhamento
Histórico completo
Recorrência
```

## Family+

```text
Até 8 pessoas
Tudo anterior
Mais recursos futuros
```

Isso cria um caminho natural para monetização.

---

# 60. MVP

Não recomendo tentar lançar tudo inicialmente.

O MVP deve ter:

### Autenticação

* Google
* Apple

### Casa

* criar casa;
* entrar em casa;
* convite;
* membros.

### Tarefas

* criar;
* editar;
* excluir;
* concluir;
* atribuir;
* data/hora.

### Listas

* criar;
* adicionar item;
* concluir item;
* compartilhar.

### Offline

* leitura offline;
* criação offline;
* conclusão offline;
* sincronização.

### Notificações

* lembrete;
* evento compartilhado.

### Histórico

* tarefa criada;
* tarefa concluída;
* item adicionado;
* item concluído.

---

# 61. Fase 2

Depois:

* tarefas recorrentes;
* intervalos;
* estatísticas;
* filtros;
* calendário;
* categorias;
* prioridades;
* etiquetas;
* anexos;
* comentários;
* emojis;
* favoritos.

---

# 62. Fase 3

Depois:

* gamificação;
* pontos;
* desafios;
* recompensas;
* integração com calendário;
* widgets Android/iOS;
* Siri;
* Google Assistant;
* Apple Shortcuts;
* comandos por voz;
* web app.

---

# 63. Gamificação

Uma ideia interessante:

```text
Casa
⭐ 124 pontos esta semana
```

Porém, não devemos transformar a experiência em uma competição obrigatória.

Pode existir:

```text
Atividade
```

como padrão.

E futuramente:

```text
Modo competição
```

como opção da família.

---

# 64. Widget

Uma funcionalidade de alto valor futuramente:

Android/iOS widget:

```text
Hoje

○ Tirar lixo
○ Comprar leite
✓ Lavar louça

+ Nova tarefa
```

Isso reduz drasticamente o número de passos para usar o app.

---

# 65. Deep links

Precisamos suportar links como:

```text
app://house/join/ABC123
```

e futuramente:

```text
https://app.exemplo.com/join/ABC123
```

Isso facilita convites.

---

# 66. Estados da aplicação

Cada tela deve possuir:

```text
Loading
Empty
Success
Error
Offline
```

Exemplo:

```text
Sem internet

Você está offline.
Suas alterações serão sincronizadas quando a conexão voltar.
```

Não devemos bloquear o usuário.

---

# 67. UX offline

Um pequeno indicador:

```text
● Sincronizado
```

ou:

```text
↻ Sincronizando...
```

ou:

```text
⚠ Offline
```

Isso cria confiança.

---

# 68. Sincronização visual

Exemplo:

```text
✓ Salvo
```

Depois:

```text
☁ Sincronizado
```

Se offline:

```text
📱 Salvo neste dispositivo
```

Quando retornar:

```text
☁ Sincronizando...
```

Depois:

```text
✓ Sincronizado
```

---

# 69. Estrutura de projeto Firebase

Recomendo separar ambientes:

```text
Firebase Project
│
├── casa-dev
│
├── casa-staging
│
└── casa-prod
```

Nunca desenvolver diretamente no projeto de produção.

---

# 70. CI/CD

Usar:

```text
GitHub
+
GitHub Actions
```

Pipeline:

```text
Pull Request
    ↓
Flutter Analyze
    ↓
Flutter Test
    ↓
Build
    ↓
Firebase Emulator Tests
    ↓
Merge
    ↓
Staging
    ↓
Release
```

---

# 71. Firebase Emulator Suite

Durante desenvolvimento:

```text
Firebase Auth Emulator
Firestore Emulator
Functions Emulator
```

Isso permite testar sem alterar produção.

---

# 72. Testes

Devemos possuir:

### Unit Tests

Para:

* regras de recorrência;
* cálculo de datas;
* domínio;
* validações.

### Widget Tests

Para:

* criação de tarefa;
* conclusão;
* listas.

### Integration Tests

Para:

```text
login
→ criar casa
→ criar tarefa
→ concluir
```

E especialmente:

```text
offline
→ criar tarefa
→ online
→ verificar sincronização
```

---

# 73. Teste crítico

O cenário mais importante:

### Dispositivo A

```text
online
```

### Dispositivo B

```text
offline
```

B:

```text
cria tarefa
```

A:

```text
continua usando app
```

B:

```text
volta online
```

A deve receber:

```text
nova tarefa
```

Esse teste deve ser automatizado e manual.

---

# 74. Segurança contra manipulação

Nunca confiar no aplicativo para:

```text
maxMembers
subscriptionStatus
role
ownerId
```

Por exemplo, não permitir:

```text
Flutter → Firestore

maxMembers = 999
```

O cliente pode ser manipulado.

Essas informações devem ser protegidas pelas Rules/Functions.

---

# 75. Billing separado do Firestore

O aplicativo não deve simplesmente consultar:

```text
subscription.active
```

e acreditar cegamente no valor enviado pelo usuário.

Fluxo:

```text
App Store / Google Play
       ↓
evento de compra
       ↓
backend
       ↓
validação
       ↓
entitlement
       ↓
Firestore
```

---

# 76. Estrutura de domínio

Classes principais:

```text
User
Household
HouseholdMember

Task
TaskOccurrence

TaskList
TaskListItem

ActivityEvent

Invitation

Subscription
Entitlement

Device
Notification
```

---

# 77. IDs

Usar IDs únicos.

Exemplo:

```text
house_abc123
task_xyz789
```

Ou IDs gerados pelo Firestore.

Nunca utilizar:

```text
nome
email
telefone
```

como ID de documento.

---

# 78. Timestamps

Todos os registros importantes devem possuir:

```text
createdAt
updatedAt
```

Quando relevante:

```text
completedAt
deletedAt
expiresAt
```

Preferir timestamp do servidor para eventos críticos.

---

# 79. Soft delete

Para objetos importantes:

```json
{
  "deletedAt": null
}
```

Em vez de excluir imediatamente.

Isso facilita:

* sincronização;
* auditoria;
* recuperação;
* resolução de conflitos.

Depois podemos ter um processo de limpeza.

---

# 80. Versionamento de dados

Os documentos devem possuir:

```text
schemaVersion
```

quando houver necessidade.

Exemplo:

```json
{
  "schemaVersion": 2
}
```

Isso facilita evolução do aplicativo.

---

# 81. Roadmap técnico

## Sprint 1

Infraestrutura:

* Flutter;
* Firebase;
* Auth;
* Firestore;
* arquitetura;
* CI/CD.

## Sprint 2

Conta e casa:

* login;
* perfil;
* criar casa;
* convite;
* membros.

## Sprint 3

Tarefas:

* CRUD;
* conclusão;
* responsável;
* datas.

## Sprint 4

Listas:

* listas;
* itens;
* compartilhamento.

## Sprint 5

Offline:

* cenários offline;
* sincronização;
* conflitos;
* indicadores.

## Sprint 6

Notificações:

* FCM;
* local notifications;
* lembretes.

## Sprint 7

Histórico:

* activity;
* estatísticas;
* pessoas.

## Sprint 8

Billing:

* planos;
* assinatura;
* entitlement;
* validação.

## Sprint 9

Qualidade:

* Crashlytics;
* Analytics;
* testes;
* performance.

## Sprint 10

Store:

* Play Store;
* App Store;
* screenshots;
* política de privacidade;
* termos;
* publicação.

---

# 82. Ordem de desenvolvimento recomendada

Eu faria exatamente nesta ordem:

```text
1. Projeto Flutter
       ↓
2. Firebase
       ↓
3. Authentication
       ↓
4. Household
       ↓
5. Firestore Rules
       ↓
6. Tasks
       ↓
7. Lists
       ↓
8. Offline
       ↓
9. Notifications
       ↓
10. Activity
       ↓
11. Subscription
       ↓
12. Analytics
       ↓
13. Crashlytics
       ↓
14. Store
```

---

# 83. O que eu NÃO faria no MVP

Evitaria inicialmente:

* backend .NET;
* Kubernetes;
* API Gateway;
* banco SQL;
* microserviços;
* Redis;
* filas próprias;
* servidor dedicado;
* sincronização JSON própria;
* sistema de permissões extremamente complexo;
* gamificação;
* chat;
* fotos;
* web app.

Tudo isso pode vir depois.

---

# 84. Arquitetura final recomendada

```text
                         ┌─────────────────────┐
                         │       App Store     │
                         └──────────┬──────────┘
                                    │
                         ┌──────────▼──────────┐
                         │       Flutter       │
                         │     Android/iOS     │
                         └──────────┬──────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
              ▼                     ▼                     ▼
        Firebase Auth          Firestore                FCM
              │                     │                     │
              │              Offline Cache               │
              │                     │                     │
              └──────────────┬──────┴─────────────────────┘
                             │
                       Cloud Functions
                             │
                ┌────────────┼─────────────┐
                │            │             │
                ▼            ▼             ▼
             Billing      Scheduler     Invitations
                │            │             │
                └────────────┴─────────────┘
                             │
                    Subscription /
                      Entitlement
```

---

# 85. Decisão final sobre JSON

### Minha recomendação:

**Não usar JSON como banco local.**

Usar:

```text
Firestore Offline Persistence
```

e, se posteriormente houver necessidade de dados locais específicos:

```text
Isar / Hive
```

para esses casos.

O JSON pode continuar existindo para:

* exportação;
* backup;
* debug;
* importação;
* migração.

Mas não como mecanismo principal de sincronização.

---

# 86. Decisão final sobre API

### MVP:

```text
SEM API própria
```

Utilizar:

```text
Firebase Auth
Firestore
Cloud Functions
FCM
App Check
Crashlytics
Analytics
```

### Futuro:

Se o produto crescer:

```text
Flutter
 ↓
API
 ↓
Backend
 ↓
Firebase / Google Cloud
```

---

# 87. Decisão final sobre armazenamento

### Local

```text
Firestore persistent cache
```

### Nuvem

```text
Cloud Firestore
```

### Identidade

```text
Firebase Authentication
```

### Google/Apple

```text
Provedores de autenticação
```

e não armazenamento primário.

---

# 88. Decisão final sobre família

O núcleo do produto deve ser:

```text
User
   ↓
Household
   ↓
Members
   ↓
Tasks / Lists / Activity
```

Não:

```text
User
 ↓
Tasks
```

A "Casa" deve ser a unidade de compartilhamento.

---

# 89. Decisão final sobre cobrança

A cobrança deve ser associada à:

```text
Household
```

e não diretamente a uma pessoa.

Exemplo:

```text
Casa Silva
├── João
├── Maria
└── Pedro

Subscription
└── Family / 3 seats
```

Isso torna o modelo muito mais fácil de administrar.

---

# 90. Arquitetura de negócio

```text
                    USER
                     │
                     ▼
                 HOUSEHOLD
                     │
          ┌──────────┼──────────┐
          │          │          │
          ▼          ▼          ▼
        USERS       TASKS      LISTS
          │          │          │
          │          │          └── ITEMS
          │          │
          │          └── OCCURRENCES
          │
          └── ACTIVITY

HOUSEHOLD
    │
    ▼
SUBSCRIPTION
    │
    ▼
ENTITLEMENT
```

Essa estrutura deixa o produto preparado para crescer.

---

# 91. MVP comercial sugerido

Eu começaria com:

```text
CASA

Grátis
1 pessoa

────────────────

Família
até 4 pessoas
R$ 29,90/mês

────────────────

Família+
até 8 pessoas
R$ 49,90/mês
```

Mas manteria internamente o modelo:

```text
maxMembers
```

em vez de codificar:

```text
R$ 10 × membros
```

Isso permite alterar preços sem alterar o aplicativo.

Se a estratégia comercial definida posteriormente for exatamente R$ 10 por participante adicional, o backend pode simplesmente implementar essa regra.

---

# 92. Principal risco técnico

O maior risco do projeto não é Flutter.

Também não é Firebase.

É:

> **sincronização + recorrência + billing + permissões.**

Esses quatro pontos precisam ser projetados corretamente.

Especialmente:

```text
offline
   +
duas pessoas editando
   +
recorrência
   +
notificação
```

deve ser testado cuidadosamente.

---

# 93. Principal risco de produto

O aplicativo não pode ficar complexo demais.

O usuário doméstico não quer configurar:

```text
Task
Schedule
Recurrence
Notification
Priority
Category
Assignee
Tags
```

para simplesmente:

> "Comprar leite."

Por isso, a UI deve esconder complexidade.

Exemplo:

```text
Comprar leite

[✓ Criar]
```

Depois, se quiser:

```text
⌄ Mais opções
```

com:

* horário;
* responsável;
* recorrência;
* notificação.

---

# 94. Princípio de UX

A regra deve ser:

> **80% das tarefas devem poder ser criadas em uma única tela e em poucos segundos.**

E:

> **20% das funcionalidades avançadas ficam escondidas em "Mais opções".**

Isso mantém o aplicativo simples sem sacrificar recursos.

---

# 95. Resultado esperado

A arquitetura proposta entrega:

```text
Flutter
      +
Firebase
      +
Offline-first
      +
Households
      +
Tasks
      +
Lists
      +
Notifications
      +
Activity
      +
Subscriptions
```

sem a necessidade de administrar servidores próprios no início.

É uma arquitetura adequada para validar o produto rapidamente e, ao mesmo tempo, permite evoluir para dezenas de milhares ou mais usuários sem precisar reescrever o núcleo da aplicação.

---

# 96. Próximo passo recomendado

A partir deste documento, a próxima etapa deve ser transformar a especificação em três artefatos técnicos:

### 1. ERD / modelo Firestore

Definir exatamente:

```text
collections
documents
fields
indexes
relationships
```

### 2. Security Rules

Definir exatamente:

```text
quem pode ler
quem pode criar
quem pode editar
quem pode excluir
```

### 3. Especificação Flutter

Definir:

```text
telas
rotas
providers
repositories
models
services
controllers
```

Depois disso, podemos partir diretamente para a criação do projeto Flutter e implementação do MVP.

---

# 97. Conclusão

A arquitetura que eu adotaria para o produto é:

**Flutter + Firebase + Firestore Offline + Firebase Auth + Cloud Functions + FCM.**

A mudança mais importante em relação à ideia inicial é abandonar o JSON como mecanismo principal de persistência/sincronização.

O Firestore já resolve uma parte significativa desse problema no Android/iOS, incluindo cache persistente e sincronização posterior.

Também não criaria uma API própria inicialmente. Cloud Functions pode funcionar como a camada server-side para operações que não devem ser executadas diretamente pelo cliente, como convites, recorrência, billing e notificações.

O conceito central do sistema seria:

```text
             USER
               │
               ▼
           HOUSEHOLD
               │
       ┌───────┼────────┐
       ▼       ▼        ▼
     TASKS    LISTS   ACTIVITY
       │       │
       ▼       ▼
  RECURRENCE ITEMS

               │
               ▼
         SUBSCRIPTION
               │
               ▼
          ENTITLEMENT
```

Isso cria uma base bastante sólida para transformar o protótipo visual que fizemos em um produto real.
