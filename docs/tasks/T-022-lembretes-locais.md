---
id: T-022
title: Lembretes (notificações locais)
status: done
plan: 0002
depends_on: [T-018]
area: app
parallel_ok: true
---

## Critérios de aceite
- [x] Notificação local agendada para tarefas com `schedule` e `notification.enabled` (`offsetMinutes` antes)
- [x] Permissão `POST_NOTIFICATIONS` (Android 13+) pedida no momento certo, com explicação; negada não quebra o app (ver "Permissão")
- [x] Alarmes exatos: decidir `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` vs. janela aproximada (política da Play) e documentar (ver "Decisão de alarmes")
- [x] Reagendar ao editar/concluir/excluir a tarefa e após reinício do aparelho
- [x] Timezone correto (UTC + IANA), inclusive mudança de fuso
- [x] Canais Android: "Lembretes", "Atividade da casa", "Conta e plano"
- [x] Só lembretes pessoais; eventos compartilhados são push (T-023)
- [x] Testes (unit do cálculo de horários) e roteiro manual (abaixo; a execução no aparelho depende de teste manual)

## Como funciona
`lib/features/reminders/{domain,data,application,presentation}`:
- `domain/reminder_plan.dart`: `computeReminderPlans` (puro) — tarefas pendentes, não excluídas, com `schedule`, `notification.enabled`, do usuário (`assignedTo == uid` ou `null`), com disparo (`scheduledAt - offsetMinutes`, UTC) no futuro. Id da notificação = FNV-1a 31 bits do id da tarefa (determinístico). `ReminderPayload` = `planly://task/<taskId>?f=<familyId>&h=<householdId>` (só ids).
- `domain/notification_gateway.dart`: `NotificationGateway` (abstração do plugin); `data/local_notification_gateway.dart`: impl com `flutter_local_notifications` 22.x.
- `application/reminder_reconciler.dart`: `ReminderReconciler` (gateway + `Clock` injetáveis, chamadas serializadas). Agenda novos/alterados (assinatura = instante|título|corpo|payload), cancela o que saiu do conjunto desejado, não reagenda o inalterado (idempotente) e, na primeira execução, cancela o que sobrou agendado no sistema de execuções anteriores.
- `application/reminder_providers.dart`: `reminderSyncProvider` OBSERVA o stream `watchScheduled` da casa ativa e reconcilia — cobre criar/editar/concluir/excluir/reatribuir sem tocar em `TaskActions`/repositories. Sem usuário ou com lembretes desligados (preferência local `reminders.enabled`, padrão ligado) cancela tudo (logout não deixa lembrete para trás). Sem contexto ativo: não mexe no agendado. Trocar de casa reconcilia com a nova casa.
- Inicialização: `lib/app/app.dart` (`PlanlyApp.build`) faz `ref.watch(reminderSyncProvider)` e `ref.watch(reminderNavigationProvider)` (`lib/app/reminder_navigation.dart`).
- Toque na notificação (app aberto e cold start via `getNotificationAppLaunchDetails`): espera `SessionPhase.ready`, ajusta a casa ativa (`activeContextProvider.selectHousehold`) se a tarefa for de outra casa e navega para `/home/task/:taskId`.
- Conteúdo: título = título da tarefa (máx. 80, espaços normalizados), corpo "Hoje às 19:00" / "Amanhã às 19:00" / "10/03 às 19:00" (no fuso do aparelho, relativo ao dia do disparo). Textos e nomes de canal via ARB (`lookupAppLocalizations(pt)`).
- Configurações: seção "Lembretes" (`presentation/reminders_settings_section.dart`): switch local, estado da permissão, botão "Permitir notificações" (com diálogo de explicação antes) e, após negar, "Abrir ajustes do sistema". Relê a permissão ao voltar dos ajustes.

## Decisão de alarmes
Agendamento **inexato permitido com o aparelho ocioso** (`AndroidScheduleMode.inexactAllowWhileIdle` → `setAndAllowWhileIdle`). **Sem** `SCHEDULE_EXACT_ALARM` nem `USE_EXACT_ALARM` (política da Play: reservadas a despertador/calendário; lembrete doméstico não precisa de precisão de segundo — pode atrasar alguns minutos com Doze). Evolução possível: toggle "alarme exato" em Configurações que peça `SCHEDULE_EXACT_ALARM` (`requestExactAlarmsPermission`) e troque para `exactAllowWhileIdle`, com declaração na Play Console.

## Permissões/manifest/gradle (edições cirúrgicas)
- `AndroidManifest.xml`: `POST_NOTIFICATIONS` (também vem do plugin) e `RECEIVE_BOOT_COMPLETED`; receivers `ScheduledNotificationReceiver` e `ScheduledNotificationBootReceiver` (reagendam após reinício/atualização). `allowBackup=false` e `usesCleartextTraffic=false` mantidos.
- `build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` (exigido pelo plugin).
- Canais criados na inicialização do plugin: `reminders` (importância alta), `household_activity` e `account_plan` (padrão; usados por T-023).

## Timezone
`scheduledAt` é UTC: o agendamento usa o instante absoluto (`TZDateTime.from(utc, UTC)`), sem depender do fuso do aparelho → trocar de fuso não desloca o lembrete; só o texto do corpo muda (recalculado na próxima reconciliação). O IANA guardado na tarefa é o fuso de criação (data-model §8 #19).

## Limitações conhecidas (documentadas)
- Só há lembretes da casa ATIVA, e o stream só roda com o app em execução: tarefa alterada por outra pessoa enquanto o app está fechado só é reagendada ao abrir o app (o que já estava agendado continua valendo). Complemento no servidor é o push da T-023.
- `watchScheduled` tem limite de 100 tarefas agendadas por casa (limite das Rules).
- A permissão é pedida na tela de Configurações (com explicação). Não há pedido automático ao ativar o primeiro lembrete no formulário de tarefa (formulário pertence a T-018); evolução: disparar o mesmo diálogo ao salvar a primeira tarefa com notificação.
- Ícone da notificação = ícone do app (`@mipmap/ic_launcher`); ícone monocromático dedicado fica para o polimento de UI.
- Toque vindo de outra conta no mesmo aparelho: a tarefa simplesmente não é encontrada ("Tarefa não encontrada").

## Testes
- Automáticos (`test/reminders_test.dart`, gateway fake + `Clock` injetado): cálculo de offset/passado/fuso/atribuição/título/id, payload (ida e volta e inválidos), reconciliação (agenda, reagenda, cancela por concluir/excluir/reatribuir/desligar, passado, idempotência, reinício, falha do plugin, serialização), corpo em pt, integração com o app (agenda ao abrir, cancela ao concluir/excluir, toque abre a tarefa, payload inválido ignorado) e widget da seção de Configurações (permitido, negado com explicação, negado de novo -> ajustes).
- Build: `flutter build apk --debug --flavor dev -t lib/main_dev.dart` compila e o app abre no emulador `planly_pixel` sem crash.

## Roteiro manual (depende de aparelho/emulador; não automatizado)
1. Android 13+: instalar, entrar; Configurações > Lembretes mostra "Notificações bloqueadas" -> "Permitir notificações" -> ler a explicação -> Continuar -> aceitar no diálogo do sistema -> estado "permitidas".
2. Criar tarefa para daqui a ~5 min com "notificar 1 min antes" -> fechar o app (deslizar) -> a notificação chega por volta do horário (pode atrasar poucos minutos por ser inexato) com título da tarefa e "Hoje às HH:mm" -> tocar abre o detalhe da tarefa.
3. Concluir/excluir/editar o horário de uma tarefa com lembrete pendente (app aberto) -> a notificação antiga não dispara; a nova sim.
4. Reiniciar o aparelho/emulador com lembrete futuro -> ele ainda dispara (BOOT receiver).
5. Mudar o fuso do aparelho -> o lembrete dispara no mesmo instante absoluto.
6. Negar a permissão -> o app segue normal; Configurações mostra "Abrir ajustes do sistema" e, ao permitir lá e voltar, o estado atualiza.
7. Desligar o switch "Lembretes de tarefas" -> nada mais dispara; sair da conta -> nenhum lembrete fica agendado.
8. Toque com o app fechado (cold start) e com o app em segundo plano abrem `/home/task/:id`; tarefa de outra casa troca a casa ativa.
