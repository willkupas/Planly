import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('pt')];

  /// Nome do aplicativo
  ///
  /// In pt, this message translates to:
  /// **'Planly'**
  String get appName;

  /// No description provided for @homeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Início'**
  String get homeTitle;

  /// No description provided for @homeGreeting.
  ///
  /// In pt, this message translates to:
  /// **'Bom dia 👋'**
  String get homeGreeting;

  /// No description provided for @splashLoading.
  ///
  /// In pt, this message translates to:
  /// **'Carregando'**
  String get splashLoading;

  /// No description provided for @loginSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Tarefas da casa, em conjunto.'**
  String get loginSubtitle;

  /// No description provided for @loginWithGoogle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com Google'**
  String get loginWithGoogle;

  /// No description provided for @loginSigningIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrando…'**
  String get loginSigningIn;

  /// No description provided for @logout.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get logout;

  /// No description provided for @actionRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get actionCancel;

  /// No description provided for @actionOk.
  ///
  /// In pt, this message translates to:
  /// **'Entendi'**
  String get actionOk;

  /// No description provided for @actionCreate.
  ///
  /// In pt, this message translates to:
  /// **'Criar'**
  String get actionCreate;

  /// No description provided for @actionSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get actionSave;

  /// No description provided for @errorNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão. Verifique sua internet e tente de novo.'**
  String get errorNetwork;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In pt, this message translates to:
  /// **'Você não tem permissão para fazer isso.'**
  String get errorPermissionDenied;

  /// No description provided for @errorRequiresRecentLogin.
  ///
  /// In pt, this message translates to:
  /// **'Por segurança, entre novamente para continuar.'**
  String get errorRequiresRecentLogin;

  /// No description provided for @errorAccount.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível entrar com esta conta. Tente outra conta Google.'**
  String get errorAccount;

  /// No description provided for @errorConfiguration.
  ///
  /// In pt, this message translates to:
  /// **'O login não está configurado neste aparelho. Tente mais tarde.'**
  String get errorConfiguration;

  /// No description provided for @errorUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Algo deu errado. Tente de novo.'**
  String get errorUnknown;

  /// No description provided for @errorFamilyFrozen.
  ///
  /// In pt, this message translates to:
  /// **'A família está somente leitura (assinatura expirada). Não é possível fazer alterações.'**
  String get errorFamilyFrozen;

  /// No description provided for @errorFeatureNotInPlan.
  ///
  /// In pt, this message translates to:
  /// **'Este recurso não está incluído no plano atual.'**
  String get errorFeatureNotInPlan;

  /// No description provided for @errorPlanLimitMembers.
  ///
  /// In pt, this message translates to:
  /// **'O limite de pessoas do plano foi atingido.'**
  String get errorPlanLimitMembers;

  /// No description provided for @errorPlanLimitHouseholds.
  ///
  /// In pt, this message translates to:
  /// **'O limite de casas do plano foi atingido.'**
  String get errorPlanLimitHouseholds;

  /// No description provided for @errorOwnerHasMembers.
  ///
  /// In pt, this message translates to:
  /// **'Transfira a família para outra pessoa antes de continuar.'**
  String get errorOwnerHasMembers;

  /// No description provided for @errorLastHousehold.
  ///
  /// In pt, this message translates to:
  /// **'A família precisa ter pelo menos uma casa.'**
  String get errorLastHousehold;

  /// No description provided for @errorOwnerCannotLeave.
  ///
  /// In pt, this message translates to:
  /// **'O dono da família não pode sair. Transfira a família primeiro.'**
  String get errorOwnerCannotLeave;

  /// No description provided for @errorTransferPending.
  ///
  /// In pt, this message translates to:
  /// **'Já existe uma transferência pendente.'**
  String get errorTransferPending;

  /// No description provided for @errorBootstrapRequired.
  ///
  /// In pt, this message translates to:
  /// **'Conclua a configuração inicial da conta antes de continuar.'**
  String get errorBootstrapRequired;

  /// No description provided for @errorNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Não encontramos o item. Ele pode ter sido removido.'**
  String get errorNotFound;

  /// No description provided for @errorAlreadyMember.
  ///
  /// In pt, this message translates to:
  /// **'Você já faz parte desta família.'**
  String get errorAlreadyMember;

  /// No description provided for @errorExpired.
  ///
  /// In pt, this message translates to:
  /// **'Este pedido expirou.'**
  String get errorExpired;

  /// No description provided for @errorRateLimited.
  ///
  /// In pt, this message translates to:
  /// **'Muitas tentativas seguidas. Aguarde um pouco e tente de novo.'**
  String get errorRateLimited;

  /// No description provided for @offlineBanner.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão — alterações ficam salvas neste dispositivo'**
  String get offlineBanner;

  /// No description provided for @syncSavedLocally.
  ///
  /// In pt, this message translates to:
  /// **'Salvo neste dispositivo'**
  String get syncSavedLocally;

  /// No description provided for @syncSyncing.
  ///
  /// In pt, this message translates to:
  /// **'Sincronizando…'**
  String get syncSyncing;

  /// No description provided for @syncSynced.
  ///
  /// In pt, this message translates to:
  /// **'Sincronizado'**
  String get syncSynced;

  /// No description provided for @syncOffline.
  ///
  /// In pt, this message translates to:
  /// **'Offline'**
  String get syncOffline;

  /// No description provided for @navHome.
  ///
  /// In pt, this message translates to:
  /// **'Início'**
  String get navHome;

  /// No description provided for @navFamily.
  ///
  /// In pt, this message translates to:
  /// **'Família'**
  String get navFamily;

  /// No description provided for @bootstrapLoadingTitle.
  ///
  /// In pt, this message translates to:
  /// **'Preparando sua casa'**
  String get bootstrapLoadingTitle;

  /// No description provided for @bootstrapLoadingMessage.
  ///
  /// In pt, this message translates to:
  /// **'Estamos criando sua família e sua primeira casa.'**
  String get bootstrapLoadingMessage;

  /// No description provided for @bootstrapOfflineTitle.
  ///
  /// In pt, this message translates to:
  /// **'Precisa de internet'**
  String get bootstrapOfflineTitle;

  /// No description provided for @bootstrapOfflineMessage.
  ///
  /// In pt, this message translates to:
  /// **'Para o primeiro acesso é preciso estar conectado. Conecte-se e tente de novo.'**
  String get bootstrapOfflineMessage;

  /// No description provided for @bootstrapErrorTitle.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível preparar sua conta'**
  String get bootstrapErrorTitle;

  /// No description provided for @dashboardNoHouseholdTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma casa por aqui'**
  String get dashboardNoHouseholdTitle;

  /// No description provided for @dashboardNoHouseholdMessage.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não tem acesso a nenhuma casa desta família.'**
  String get dashboardNoHouseholdMessage;

  /// No description provided for @dashboardComingSoon.
  ///
  /// In pt, this message translates to:
  /// **'As tarefas compartilhadas chegam na próxima etapa do app.'**
  String get dashboardComingSoon;

  /// No description provided for @dashboardToday.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get dashboardToday;

  /// No description provided for @dashboardUpcoming.
  ///
  /// In pt, this message translates to:
  /// **'Próximas'**
  String get dashboardUpcoming;

  /// No description provided for @dashboardLists.
  ///
  /// In pt, this message translates to:
  /// **'Listas'**
  String get dashboardLists;

  /// No description provided for @dashboardSectionSoon.
  ///
  /// In pt, this message translates to:
  /// **'Em breve'**
  String get dashboardSectionSoon;

  /// No description provided for @familyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Família'**
  String get familyTitle;

  /// No description provided for @familyNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Não encontramos esta família.'**
  String get familyNotFound;

  /// No description provided for @familyPlanLabel.
  ///
  /// In pt, this message translates to:
  /// **'Plano'**
  String get familyPlanLabel;

  /// No description provided for @planFree.
  ///
  /// In pt, this message translates to:
  /// **'Grátis'**
  String get planFree;

  /// No description provided for @planFamily.
  ///
  /// In pt, this message translates to:
  /// **'Família'**
  String get planFamily;

  /// No description provided for @planFamilyPlus.
  ///
  /// In pt, this message translates to:
  /// **'Família+'**
  String get planFamilyPlus;

  /// No description provided for @familyUsageMembers.
  ///
  /// In pt, this message translates to:
  /// **'{count} de {max} pessoas'**
  String familyUsageMembers(int count, int max);

  /// No description provided for @familyUsageMembersNoLimit.
  ///
  /// In pt, this message translates to:
  /// **'{count} pessoas'**
  String familyUsageMembersNoLimit(int count);

  /// No description provided for @familyUsageHouseholds.
  ///
  /// In pt, this message translates to:
  /// **'{count} de {max} casas'**
  String familyUsageHouseholds(int count, int max);

  /// No description provided for @familyUsageHouseholdsUnlimited.
  ///
  /// In pt, this message translates to:
  /// **'{count} casas (sem limite)'**
  String familyUsageHouseholdsUnlimited(int count);

  /// No description provided for @familyUsageHouseholdsNoLimit.
  ///
  /// In pt, this message translates to:
  /// **'{count} casas'**
  String familyUsageHouseholdsNoLimit(int count);

  /// No description provided for @familySeePlans.
  ///
  /// In pt, this message translates to:
  /// **'Ver planos'**
  String get familySeePlans;

  /// No description provided for @upsellTitle.
  ///
  /// In pt, this message translates to:
  /// **'Recurso de plano pago'**
  String get upsellTitle;

  /// No description provided for @upsellInvitesMessage.
  ///
  /// In pt, this message translates to:
  /// **'No plano grátis a família é só sua. Com um plano pago você poderá convidar outras pessoas para compartilhar as tarefas.'**
  String get upsellInvitesMessage;

  /// No description provided for @upsellHouseholdsMessage.
  ///
  /// In pt, this message translates to:
  /// **'O plano grátis inclui uma casa. Com um plano pago você poderá criar mais casas.'**
  String get upsellHouseholdsMessage;

  /// No description provided for @frozenBanner.
  ///
  /// In pt, this message translates to:
  /// **'{days, plural, =0{Somente leitura — assinatura expirada. Exclusão hoje.} =1{Somente leitura — assinatura expirada. Exclusão em 1 dia.} other{Somente leitura — assinatura expirada. Exclusão em {days} dias.}}'**
  String frozenBanner(int days);

  /// No description provided for @frozenBannerNoDate.
  ///
  /// In pt, this message translates to:
  /// **'Somente leitura — assinatura expirada.'**
  String get frozenBannerNoDate;

  /// No description provided for @frozenBannerOwnerHint.
  ///
  /// In pt, this message translates to:
  /// **'Reassine ou transfira a família para voltar a editar.'**
  String get frozenBannerOwnerHint;

  /// No description provided for @frozenBannerMemberHint.
  ///
  /// In pt, this message translates to:
  /// **'Avise o dono da família para reativar o plano.'**
  String get frozenBannerMemberHint;

  /// No description provided for @membersTitle.
  ///
  /// In pt, this message translates to:
  /// **'Membros'**
  String get membersTitle;

  /// No description provided for @membersEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum membro encontrado.'**
  String get membersEmpty;

  /// No description provided for @roleOwner.
  ///
  /// In pt, this message translates to:
  /// **'Dono da família'**
  String get roleOwner;

  /// No description provided for @roleMember.
  ///
  /// In pt, this message translates to:
  /// **'Participante'**
  String get roleMember;

  /// No description provided for @memberNoName.
  ///
  /// In pt, this message translates to:
  /// **'Sem nome'**
  String get memberNoName;

  /// No description provided for @memberYou.
  ///
  /// In pt, this message translates to:
  /// **'{name} (você)'**
  String memberYou(String name);

  /// No description provided for @memberActions.
  ///
  /// In pt, this message translates to:
  /// **'Ações do membro'**
  String get memberActions;

  /// No description provided for @memberAccess.
  ///
  /// In pt, this message translates to:
  /// **'Acesso às casas'**
  String get memberAccess;

  /// No description provided for @memberAccessTitle.
  ///
  /// In pt, this message translates to:
  /// **'Acesso de {name}'**
  String memberAccessTitle(String name);

  /// No description provided for @accessNone.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum'**
  String get accessNone;

  /// No description provided for @accessMember.
  ///
  /// In pt, this message translates to:
  /// **'Participante'**
  String get accessMember;

  /// No description provided for @accessAdmin.
  ///
  /// In pt, this message translates to:
  /// **'Admin'**
  String get accessAdmin;

  /// No description provided for @memberRemove.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get memberRemove;

  /// No description provided for @memberRemoveTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover da família?'**
  String get memberRemoveTitle;

  /// No description provided for @memberRemoveMessage.
  ///
  /// In pt, this message translates to:
  /// **'{name} perde o acesso a todas as casas.'**
  String memberRemoveMessage(String name);

  /// No description provided for @memberRemoved.
  ///
  /// In pt, this message translates to:
  /// **'Membro removido.'**
  String get memberRemoved;

  /// No description provided for @leaveFamily.
  ///
  /// In pt, this message translates to:
  /// **'Sair da família'**
  String get leaveFamily;

  /// No description provided for @leaveFamilyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sair desta família?'**
  String get leaveFamilyTitle;

  /// No description provided for @leaveFamilyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Você perde o acesso às casas desta família. Para voltar, será preciso um novo convite.'**
  String get leaveFamilyMessage;

  /// No description provided for @inviteButton.
  ///
  /// In pt, this message translates to:
  /// **'Convidar pessoa'**
  String get inviteButton;

  /// No description provided for @inviteComingSoon.
  ///
  /// In pt, this message translates to:
  /// **'Os convites chegam na próxima etapa.'**
  String get inviteComingSoon;

  /// No description provided for @householdsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Casas'**
  String get householdsTitle;

  /// No description provided for @householdsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma casa disponível'**
  String get householdsEmpty;

  /// No description provided for @householdsEmptyMember.
  ///
  /// In pt, this message translates to:
  /// **'O dono da família ainda não liberou nenhuma casa para você.'**
  String get householdsEmptyMember;

  /// No description provided for @householdNew.
  ///
  /// In pt, this message translates to:
  /// **'Nova casa'**
  String get householdNew;

  /// No description provided for @householdNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome da casa'**
  String get householdNameLabel;

  /// No description provided for @householdCreated.
  ///
  /// In pt, this message translates to:
  /// **'Casa criada.'**
  String get householdCreated;

  /// No description provided for @householdRename.
  ///
  /// In pt, this message translates to:
  /// **'Renomear'**
  String get householdRename;

  /// No description provided for @householdActions.
  ///
  /// In pt, this message translates to:
  /// **'Ações da casa'**
  String get householdActions;

  /// No description provided for @householdDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get householdDelete;

  /// No description provided for @householdDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir casa?'**
  String get householdDeleteTitle;

  /// No description provided for @householdDeleteMessage.
  ///
  /// In pt, this message translates to:
  /// **'A casa \"{name}\" será excluída. Você pode pedir a restauração em até 30 dias.'**
  String householdDeleteMessage(String name);

  /// No description provided for @householdDeleted.
  ///
  /// In pt, this message translates to:
  /// **'Casa excluída.'**
  String get householdDeleted;

  /// No description provided for @householdAccessCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Sem pessoas vinculadas} =1{1 pessoa vinculada} other{{count} pessoas vinculadas}}'**
  String householdAccessCount(int count);

  /// No description provided for @switchFamilies.
  ///
  /// In pt, this message translates to:
  /// **'Famílias'**
  String get switchFamilies;

  /// No description provided for @switchHouseholds.
  ///
  /// In pt, this message translates to:
  /// **'Casas'**
  String get switchHouseholds;

  /// No description provided for @switchNoHouseholds.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma casa acessível nesta família.'**
  String get switchNoHouseholds;

  /// No description provided for @noAccessTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sem acesso a esta casa'**
  String get noAccessTitle;

  /// No description provided for @noAccessNoHousehold.
  ///
  /// In pt, this message translates to:
  /// **'O dono da família ainda não vinculou você a nenhuma casa. Peça a ele para liberar o acesso.'**
  String get noAccessNoHousehold;

  /// No description provided for @noAccessDeleting.
  ///
  /// In pt, this message translates to:
  /// **'Esta família está sendo excluída e não pode mais ser acessada.'**
  String get noAccessDeleting;

  /// No description provided for @noAccessSwitch.
  ///
  /// In pt, this message translates to:
  /// **'Trocar de família'**
  String get noAccessSwitch;

  /// No description provided for @settingsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get settingsTitle;

  /// No description provided for @settingsNoName.
  ///
  /// In pt, this message translates to:
  /// **'Sem nome'**
  String get settingsNoName;

  /// No description provided for @settingsLanguage.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguagePt.
  ///
  /// In pt, this message translates to:
  /// **'Português (Brasil)'**
  String get settingsLanguagePt;

  /// No description provided for @signOutPendingTitle.
  ///
  /// In pt, this message translates to:
  /// **'Alterações não sincronizadas'**
  String get signOutPendingTitle;

  /// No description provided for @signOutPendingMessage.
  ///
  /// In pt, this message translates to:
  /// **'Há alterações salvas só neste aparelho que ainda não foram enviadas. Se sair agora, elas serão perdidas.'**
  String get signOutPendingMessage;

  /// No description provided for @signOutAnyway.
  ///
  /// In pt, this message translates to:
  /// **'Sair mesmo assim'**
  String get signOutAnyway;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
