// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Planly';

  @override
  String writeFailureBannerTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alterações não foram sincronizadas',
      one: '1 alteração não foi sincronizada',
    );
    return '$_temp0';
  }

  @override
  String get writeFailureBannerView => 'Ver';

  @override
  String get writeFailureSheetTitle => 'Alterações não sincronizadas';

  @override
  String get writeFailureSheetExplain =>
      'O servidor recusou estas alterações e elas foram desfeitas neste dispositivo. Refaça se ainda fizer sentido.';

  @override
  String get writeFailureDismiss => 'Descartar';

  @override
  String get writeFailureDismissAll => 'Descartar tudo';

  @override
  String writeKindTaskCreate(String title) {
    return 'Criar tarefa “$title”';
  }

  @override
  String writeKindTaskUpdate(String title) {
    return 'Editar tarefa “$title”';
  }

  @override
  String writeKindTaskComplete(String title) {
    return 'Concluir tarefa “$title”';
  }

  @override
  String writeKindTaskReopen(String title) {
    return 'Reabrir tarefa “$title”';
  }

  @override
  String writeKindTaskDelete(String title) {
    return 'Excluir tarefa “$title”';
  }

  @override
  String writeKindListCreate(String title) {
    return 'Criar lista “$title”';
  }

  @override
  String writeKindListRename(String title) {
    return 'Renomear lista para “$title”';
  }

  @override
  String writeKindListDelete(String title) {
    return 'Excluir lista “$title”';
  }

  @override
  String writeKindItemAdd(String title) {
    return 'Adicionar item “$title”';
  }

  @override
  String writeKindItemComplete(String title) {
    return 'Marcar item “$title”';
  }

  @override
  String writeKindItemRename(String title) {
    return 'Renomear item para “$title”';
  }

  @override
  String writeKindItemDelete(String title) {
    return 'Excluir item “$title”';
  }

  @override
  String get writeKindItemReorder => 'Reordenar itens';

  @override
  String get taskFab => 'Nova tarefa';

  @override
  String get taskQuickAddTitle => 'Nova tarefa';

  @override
  String get taskQuickAddHint => 'O que precisa ser feito?';

  @override
  String get taskQuickAddSubmit => 'Adicionar tarefa';

  @override
  String get taskMoreOptions => 'Mais opções';

  @override
  String get taskLessOptions => 'Menos opções';

  @override
  String get taskTitleLabel => 'Título';

  @override
  String get taskDescriptionLabel => 'Descrição (opcional)';

  @override
  String get taskDateLabel => 'Data e hora';

  @override
  String get taskNoDate => 'Sem data';

  @override
  String get taskClearDate => 'Remover data';

  @override
  String taskScheduleAt(DateTime date, DateTime time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$dateString às $timeString';
  }

  @override
  String taskDetailDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get taskAssigneeLabel => 'Responsável';

  @override
  String get taskAssigneeAnyone => 'Qualquer pessoa';

  @override
  String get taskNotifyLabel => 'Avisar';

  @override
  String get taskNotifyNeedsDate => 'Defina uma data para receber o aviso.';

  @override
  String get taskNotifyAtTime => 'Na hora';

  @override
  String taskNotifyMinutesBefore(int minutes) {
    return '$minutes min antes';
  }

  @override
  String get taskNotifyHourBefore => '1 hora antes';

  @override
  String get taskNotifyDayBefore => '1 dia antes';

  @override
  String get taskSectionUnscheduled => 'Sem data';

  @override
  String get taskSectionDone => 'Concluídas recentes';

  @override
  String get taskOverdue => 'Atrasada';

  @override
  String get taskFilterAll => 'Todas';

  @override
  String get taskFilterMine => 'Minhas';

  @override
  String get taskEmptyTitle => 'Nenhuma tarefa por aqui';

  @override
  String get taskEmptyMessage => 'Adicione a primeira tarefa da casa.';

  @override
  String get taskEmptyMine => 'Nenhuma tarefa sua por enquanto.';

  @override
  String get taskPendingSync => 'Aguardando sincronização';

  @override
  String taskMarkDone(String title) {
    return 'Concluir $title';
  }

  @override
  String taskMarkPending(String title) {
    return 'Reabrir $title';
  }

  @override
  String get taskDetailTitle => 'Tarefa';

  @override
  String get taskNotFoundTitle => 'Tarefa não encontrada';

  @override
  String get taskNotFoundMessage => 'Ela pode ter sido excluída.';

  @override
  String get taskSave => 'Salvar alterações';

  @override
  String get taskSaved => 'Alterações salvas.';

  @override
  String get taskComplete => 'Concluir tarefa';

  @override
  String get taskReopen => 'Reabrir tarefa';

  @override
  String get taskDelete => 'Excluir tarefa';

  @override
  String get taskDeleteTitle => 'Excluir tarefa?';

  @override
  String get taskDeleteMessage =>
      'A tarefa deixa de aparecer para todos da casa.';

  @override
  String get taskDeleted => 'Tarefa excluída.';

  @override
  String taskCreatedBy(String name) {
    return 'Criada por $name';
  }

  @override
  String taskCompletedBy(String name) {
    return 'Concluída por $name';
  }

  @override
  String get taskReadOnly => 'Você pode ver esta tarefa, mas não editá-la.';

  @override
  String get taskFrozenReadOnly =>
      'Família somente leitura: não é possível alterar tarefas.';

  @override
  String get homeTitle => 'Início';

  @override
  String get remindersSectionTitle => 'Lembretes';

  @override
  String get remindersSwitchTitle => 'Lembretes de tarefas';

  @override
  String get remindersSwitchSubtitle =>
      'Avisa neste aparelho antes do horário das suas tarefas';

  @override
  String get remindersPermissionGranted => 'Notificações permitidas';

  @override
  String get remindersPermissionDenied => 'Notificações bloqueadas';

  @override
  String get remindersPermissionDeniedHelp =>
      'Sem a permissão, os lembretes não aparecem. Você pode permitir nos ajustes do sistema.';

  @override
  String get remindersPermissionAllow => 'Permitir notificações';

  @override
  String get remindersPermissionOpenSettings => 'Abrir ajustes do sistema';

  @override
  String get remindersPermissionExplainTitle => 'Permitir notificações?';

  @override
  String get remindersPermissionExplainMessage =>
      'O Planly usa notificações só para lembrar das suas tarefas no horário combinado. O conteúdo aparece apenas neste aparelho.';

  @override
  String get remindersPermissionNotNow => 'Agora não';

  @override
  String get remindersPermissionContinue => 'Continuar';

  @override
  String get remindersPermissionStillDenied =>
      'As notificações continuam bloqueadas. Abra os ajustes do sistema para permitir.';

  @override
  String get channelRemindersName => 'Lembretes';

  @override
  String get channelRemindersDescription =>
      'Avisos das suas tarefas com horário';

  @override
  String get channelActivityName => 'Atividade da casa';

  @override
  String get channelActivityDescription =>
      'Novidades das tarefas e listas compartilhadas';

  @override
  String get channelAccountName => 'Conta e plano';

  @override
  String get channelAccountDescription =>
      'Avisos sobre sua conta, família e plano';

  @override
  String reminderBodyToday(String time) {
    return 'Hoje às $time';
  }

  @override
  String reminderBodyTomorrow(String time) {
    return 'Amanhã às $time';
  }

  @override
  String reminderBodyDate(String date, String time) {
    return '$date às $time';
  }

  @override
  String get homeGreeting => 'Bom dia 👋';

  @override
  String get splashLoading => 'Carregando';

  @override
  String get loginSubtitle => 'Tarefas da casa, em conjunto.';

  @override
  String get loginWithGoogle => 'Entrar com Google';

  @override
  String get loginSigningIn => 'Entrando…';

  @override
  String get logout => 'Sair';

  @override
  String get actionRetry => 'Tentar de novo';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionOk => 'Entendi';

  @override
  String get actionCreate => 'Criar';

  @override
  String get actionSave => 'Salvar';

  @override
  String get errorNetwork =>
      'Sem conexão. Verifique sua internet e tente de novo.';

  @override
  String get errorPermissionDenied => 'Você não tem permissão para fazer isso.';

  @override
  String get errorRequiresRecentLogin =>
      'Por segurança, entre novamente para continuar.';

  @override
  String get errorAccount =>
      'Não foi possível entrar com esta conta. Tente outra conta Google.';

  @override
  String get errorConfiguration =>
      'O login não está configurado neste aparelho. Tente mais tarde.';

  @override
  String get errorUnknown => 'Algo deu errado. Tente de novo.';

  @override
  String get navLists => 'Listas';

  @override
  String get listsTitle => 'Listas';

  @override
  String get listsEmptyTitle => 'Nenhuma lista ainda';

  @override
  String get listsEmptyMessage =>
      'Crie uma lista de compras, ou qualquer outra, para compartilhar com a casa.';

  @override
  String get listsCreateAction => 'Nova lista';

  @override
  String get listsCreateTitle => 'Nova lista';

  @override
  String get listsNameLabel => 'Nome da lista';

  @override
  String get listsTypeLabel => 'Tipo';

  @override
  String get listsTypeShopping => 'Compras';

  @override
  String get listsTypeGeneral => 'Geral';

  @override
  String get listsRenameTitle => 'Renomear lista';

  @override
  String get listsDeleteTitle => 'Excluir lista?';

  @override
  String listsDeleteMessage(String name) {
    return 'A lista \"$name\" será excluída para todas as pessoas da casa.';
  }

  @override
  String listsPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pendentes',
      one: '1 pendente',
      zero: 'Nada pendente',
    );
    return '$_temp0';
  }

  @override
  String get listsMenuRename => 'Renomear';

  @override
  String get listsMenuDelete => 'Excluir';

  @override
  String get listsNotFound => 'Esta lista não existe mais.';

  @override
  String get itemsEmptyTitle => 'Lista vazia';

  @override
  String get itemsEmptyMessage => 'Adicione o primeiro item no campo abaixo.';

  @override
  String get itemAddHint => 'Adicionar item';

  @override
  String get itemAddAction => 'Adicionar';

  @override
  String get itemEditTitle => 'Editar item';

  @override
  String get itemNameLabel => 'Nome do item';

  @override
  String get itemDeleteTooltip => 'Excluir item';

  @override
  String get itemReorderTooltip => 'Arrastar para reordenar';

  @override
  String get itemPendingSync => 'Aguardando sincronizar';

  @override
  String itemsDoneSection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count concluídos',
      one: '1 concluído',
    );
    return '$_temp0';
  }

  @override
  String get errorFamilyFrozen =>
      'A família está somente leitura (assinatura expirada). Não é possível fazer alterações.';

  @override
  String get errorFeatureNotInPlan =>
      'Este recurso não está incluído no plano atual.';

  @override
  String get errorPlanLimitMembers =>
      'O limite de pessoas do plano foi atingido.';

  @override
  String get errorPlanLimitHouseholds =>
      'O limite de casas do plano foi atingido.';

  @override
  String get errorOwnerHasMembers =>
      'Transfira a família para outra pessoa antes de continuar.';

  @override
  String get errorLastHousehold => 'A família precisa ter pelo menos uma casa.';

  @override
  String get errorOwnerCannotLeave =>
      'O dono da família não pode sair. Transfira a família primeiro.';

  @override
  String get errorTransferPending => 'Já existe uma transferência pendente.';

  @override
  String get errorBootstrapRequired =>
      'Conclua a configuração inicial da conta antes de continuar.';

  @override
  String get errorNotFound =>
      'Não encontramos o item. Ele pode ter sido removido.';

  @override
  String get errorAlreadyMember => 'Você já faz parte desta família.';

  @override
  String get errorExpired => 'Este pedido expirou.';

  @override
  String get errorRateLimited =>
      'Muitas tentativas seguidas. Aguarde um pouco e tente de novo.';

  @override
  String get offlineBanner =>
      'Sem conexão — alterações ficam salvas neste dispositivo';

  @override
  String get syncSavedLocally => 'Salvo neste dispositivo';

  @override
  String get syncSyncing => 'Sincronizando…';

  @override
  String get syncSynced => 'Sincronizado';

  @override
  String get syncOffline => 'Offline';

  @override
  String get navHome => 'Início';

  @override
  String get navFamily => 'Família';

  @override
  String get bootstrapLoadingTitle => 'Preparando sua casa';

  @override
  String get bootstrapLoadingMessage =>
      'Estamos criando sua família e sua primeira casa.';

  @override
  String get bootstrapOfflineTitle => 'Precisa de internet';

  @override
  String get bootstrapOfflineMessage =>
      'Para o primeiro acesso é preciso estar conectado. Conecte-se e tente de novo.';

  @override
  String get bootstrapErrorTitle => 'Não foi possível preparar sua conta';

  @override
  String get dashboardNoHouseholdTitle => 'Nenhuma casa por aqui';

  @override
  String get dashboardNoHouseholdMessage =>
      'Você ainda não tem acesso a nenhuma casa desta família.';

  @override
  String get dashboardComingSoon =>
      'As tarefas compartilhadas chegam na próxima etapa do app.';

  @override
  String get dashboardToday => 'Hoje';

  @override
  String get dashboardUpcoming => 'Próximas';

  @override
  String get dashboardLists => 'Listas';

  @override
  String get dashboardListsOpen => 'Abrir suas listas';

  @override
  String get navActivity => 'Atividade';

  @override
  String get activityTitle => 'Atividade';

  @override
  String get activityEmptyTitle => 'Nada por aqui ainda';

  @override
  String get activityEmptyMessage =>
      'Quando alguém criar ou concluir tarefas e itens, o histórico aparece aqui.';

  @override
  String get activityEmptyFilteredMessage =>
      'Nenhuma atividade desta pessoa no período.';

  @override
  String get activityFilterAll => 'Todos';

  @override
  String get activityFilterLabel => 'Filtrar por pessoa';

  @override
  String get activityYou => 'Você';

  @override
  String get activitySomeone => 'Alguém';

  @override
  String get activityPersonFallback => 'Pessoa';

  @override
  String get activityDayToday => 'Hoje';

  @override
  String get activityDayYesterday => 'Ontem';

  @override
  String activityDayDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String activityTime(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$timeString';
  }

  @override
  String get activityLoadMore => 'Carregar mais';

  @override
  String get activityLoadingMore => 'Carregando…';

  @override
  String get activityLoadMoreFailed =>
      'Não foi possível carregar mais. Tente de novo.';

  @override
  String get activityFreeNote =>
      'No plano Grátis você vê só os últimos 7 dias. Assine um plano para ver todo o histórico.';

  @override
  String activityEventTaskCreated(String actor, String title) {
    return '$actor criou a tarefa \"$title\"';
  }

  @override
  String activityEventTaskAssigned(String actor, String title) {
    return '$actor atribuiu a tarefa \"$title\"';
  }

  @override
  String activityEventTaskCompleted(String actor, String title) {
    return '$actor concluiu \"$title\"';
  }

  @override
  String activityEventTaskReopened(String actor, String title) {
    return '$actor reabriu \"$title\"';
  }

  @override
  String activityEventTaskUpdated(String actor, String title) {
    return '$actor editou a tarefa \"$title\"';
  }

  @override
  String activityEventTaskDeleted(String actor, String title) {
    return '$actor excluiu a tarefa \"$title\"';
  }

  @override
  String activityEventListCreated(String actor, String title) {
    return '$actor criou a lista \"$title\"';
  }

  @override
  String activityEventListDeleted(String actor, String title) {
    return '$actor excluiu a lista \"$title\"';
  }

  @override
  String activityEventItemAdded(String actor, String title) {
    return '$actor adicionou \"$title\" à lista';
  }

  @override
  String activityEventItemCompleted(String actor, String title) {
    return '$actor concluiu o item \"$title\"';
  }

  @override
  String activityEventItemDeleted(String actor, String title) {
    return '$actor removeu \"$title\" da lista';
  }

  @override
  String activityEventMemberJoined(String actor) {
    return '$actor entrou na casa';
  }

  @override
  String activityEventMemberLeft(String actor) {
    return '$actor saiu da casa';
  }

  @override
  String activityEventHouseholdCreated(String actor, String title) {
    return '$actor criou a casa \"$title\"';
  }

  @override
  String activityEventUnknown(String actor) {
    return '$actor fez uma alteração';
  }

  @override
  String get dashboardSectionSoon => 'Em breve';

  @override
  String get familyTitle => 'Família';

  @override
  String get familyNotFound => 'Não encontramos esta família.';

  @override
  String get familyPlanLabel => 'Plano';

  @override
  String get planFree => 'Grátis';

  @override
  String get planFamily => 'Família';

  @override
  String get planFamilyPlus => 'Família+';

  @override
  String familyUsageMembers(int count, int max) {
    return '$count de $max pessoas';
  }

  @override
  String familyUsageMembersNoLimit(int count) {
    return '$count pessoas';
  }

  @override
  String familyUsageHouseholds(int count, int max) {
    return '$count de $max casas';
  }

  @override
  String familyUsageHouseholdsUnlimited(int count) {
    return '$count casas (sem limite)';
  }

  @override
  String familyUsageHouseholdsNoLimit(int count) {
    return '$count casas';
  }

  @override
  String get familySeePlans => 'Ver planos';

  @override
  String get upsellTitle => 'Recurso de plano pago';

  @override
  String get upsellInvitesMessage =>
      'No plano grátis a família é só sua. Com um plano pago você poderá convidar outras pessoas para compartilhar as tarefas.';

  @override
  String get upsellHouseholdsMessage =>
      'O plano grátis inclui uma casa. Com um plano pago você poderá criar mais casas.';

  @override
  String frozenBanner(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Somente leitura — assinatura expirada. Exclusão em $days dias.',
      one: 'Somente leitura — assinatura expirada. Exclusão em 1 dia.',
      zero: 'Somente leitura — assinatura expirada. Exclusão hoje.',
    );
    return '$_temp0';
  }

  @override
  String get frozenBannerNoDate => 'Somente leitura — assinatura expirada.';

  @override
  String get frozenBannerOwnerHint =>
      'Reassine ou transfira a família para voltar a editar.';

  @override
  String get frozenBannerMemberHint =>
      'Avise o dono da família para reativar o plano.';

  @override
  String get membersTitle => 'Membros';

  @override
  String get membersEmpty => 'Nenhum membro encontrado.';

  @override
  String get roleOwner => 'Dono da família';

  @override
  String get roleMember => 'Participante';

  @override
  String get memberNoName => 'Sem nome';

  @override
  String memberYou(String name) {
    return '$name (você)';
  }

  @override
  String get memberActions => 'Ações do membro';

  @override
  String get memberAccess => 'Acesso às casas';

  @override
  String memberAccessTitle(String name) {
    return 'Acesso de $name';
  }

  @override
  String get accessNone => 'Nenhum';

  @override
  String get accessMember => 'Participante';

  @override
  String get accessAdmin => 'Admin';

  @override
  String get memberRemove => 'Remover';

  @override
  String get memberRemoveTitle => 'Remover da família?';

  @override
  String memberRemoveMessage(String name) {
    return '$name perde o acesso a todas as casas.';
  }

  @override
  String get memberRemoved => 'Membro removido.';

  @override
  String get leaveFamily => 'Sair da família';

  @override
  String get leaveFamilyTitle => 'Sair desta família?';

  @override
  String get leaveFamilyMessage =>
      'Você perde o acesso às casas desta família. Para voltar, será preciso um novo convite.';

  @override
  String get inviteButton => 'Convidar pessoa';

  @override
  String get householdsTitle => 'Casas';

  @override
  String get householdsEmpty => 'Nenhuma casa disponível';

  @override
  String get householdsEmptyMember =>
      'O dono da família ainda não liberou nenhuma casa para você.';

  @override
  String get householdNew => 'Nova casa';

  @override
  String get householdNameLabel => 'Nome da casa';

  @override
  String get householdCreated => 'Casa criada.';

  @override
  String get householdRename => 'Renomear';

  @override
  String get householdActions => 'Ações da casa';

  @override
  String get householdDelete => 'Excluir';

  @override
  String get householdDeleteTitle => 'Excluir casa?';

  @override
  String householdDeleteMessage(String name) {
    return 'A casa \"$name\" será excluída. Você pode pedir a restauração em até 30 dias.';
  }

  @override
  String get householdDeleted => 'Casa excluída.';

  @override
  String householdAccessCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas vinculadas',
      one: '1 pessoa vinculada',
      zero: 'Sem pessoas vinculadas',
    );
    return '$_temp0';
  }

  @override
  String get switchFamilies => 'Famílias';

  @override
  String get switchHouseholds => 'Casas';

  @override
  String get switchNoHouseholds => 'Nenhuma casa acessível nesta família.';

  @override
  String get noAccessTitle => 'Sem acesso a esta casa';

  @override
  String get noAccessNoHousehold =>
      'O dono da família ainda não vinculou você a nenhuma casa. Peça a ele para liberar o acesso.';

  @override
  String get noAccessDeleting =>
      'Esta família está sendo excluída e não pode mais ser acessada.';

  @override
  String get noAccessSwitch => 'Trocar de família';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsNoName => 'Sem nome';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguagePt => 'Português (Brasil)';

  @override
  String get signOutPendingTitle => 'Alterações não sincronizadas';

  @override
  String get signOutPendingMessage =>
      'Há alterações salvas só neste aparelho que ainda não foram enviadas. Se sair agora, elas serão perdidas.';

  @override
  String get signOutAnyway => 'Sair mesmo assim';

  @override
  String get errorInviteInvalid =>
      'Código inválido ou expirado. Confira e tente de novo, ou peça um novo convite.';

  @override
  String get errorJoinPlanLimit =>
      'Esta família atingiu o limite de pessoas. Fale com quem convidou.';

  @override
  String get inviteTitle => 'Convidar pessoa';

  @override
  String get inviteIntro =>
      'Escolha as casas e o papel da pessoa em cada uma. O código vale por 24 horas.';

  @override
  String get inviteHouseholdsLabel => 'Casas';

  @override
  String get inviteNoHouseholds => 'Crie uma casa antes de convidar alguém.';

  @override
  String get inviteGenerate => 'Gerar convite';

  @override
  String get inviteSelectAtLeastOne => 'Escolha pelo menos uma casa.';

  @override
  String get inviteCodeLabel => 'Código do convite';

  @override
  String inviteValidUntil(String when) {
    return 'Válido por 24 horas (até $when).';
  }

  @override
  String get inviteCopy => 'Copiar código';

  @override
  String get inviteCopied => 'Código copiado.';

  @override
  String get inviteShare => 'Compartilhar';

  @override
  String get inviteShareSubject => 'Convite do Planly';

  @override
  String inviteShareMessage(String code, String link) {
    return 'Entre na minha família no Planly! Código de convite: $code (vale por 24 horas). $link';
  }

  @override
  String get inviteAnother => 'Novo convite';

  @override
  String get inviteSentList => 'Convites enviados';

  @override
  String get invitationsEmpty => 'Nenhum convite enviado';

  @override
  String get invitationsEmptyMessage =>
      'Os convites que você criar aparecem aqui.';

  @override
  String get invitationStatusPending => 'Pendente';

  @override
  String get invitationStatusAccepted => 'Aceito';

  @override
  String get invitationStatusExpired => 'Expirado';

  @override
  String get invitationStatusRevoked => 'Revogado';

  @override
  String invitationPendingSubtitle(String when) {
    return 'Pendente · vale até $when';
  }

  @override
  String get invitationDetailTitle => 'Convite pendente';

  @override
  String get invitationRevoke => 'Revogar convite';

  @override
  String get invitationRevokeTitle => 'Revogar convite?';

  @override
  String get invitationRevokeMessage =>
      'Quem ainda não usou o código não poderá mais entrar na família com ele.';

  @override
  String get invitationRevoked => 'Convite revogado.';

  @override
  String invitationRoleIn(String household, String role) {
    return '$household: $role';
  }

  @override
  String get joinHaveCode => 'Tenho um código de convite';

  @override
  String get joinTitle => 'Entrar com código';

  @override
  String get joinIntro =>
      'Digite o código que você recebeu para entrar numa família.';

  @override
  String get joinCodeLabel => 'Código do convite';

  @override
  String get joinButton => 'Entrar na família';

  @override
  String get joinSuccess => 'Você entrou na família.';
}
