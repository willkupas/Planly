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
  String get homeTitle => 'Início';

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
  String get inviteComingSoon => 'Os convites chegam na próxima etapa.';

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
}
