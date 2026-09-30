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

  /// No description provided for @writeFailureBannerTitle.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 alteração não foi sincronizada} other{{count} alterações não foram sincronizadas}}'**
  String writeFailureBannerTitle(int count);

  /// No description provided for @writeFailureBannerView.
  ///
  /// In pt, this message translates to:
  /// **'Ver'**
  String get writeFailureBannerView;

  /// No description provided for @writeFailureSheetTitle.
  ///
  /// In pt, this message translates to:
  /// **'Alterações não sincronizadas'**
  String get writeFailureSheetTitle;

  /// No description provided for @writeFailureSheetExplain.
  ///
  /// In pt, this message translates to:
  /// **'O servidor recusou estas alterações e elas foram desfeitas neste dispositivo. Refaça se ainda fizer sentido.'**
  String get writeFailureSheetExplain;

  /// No description provided for @writeFailureDismiss.
  ///
  /// In pt, this message translates to:
  /// **'Descartar'**
  String get writeFailureDismiss;

  /// No description provided for @writeFailureDismissAll.
  ///
  /// In pt, this message translates to:
  /// **'Descartar tudo'**
  String get writeFailureDismissAll;

  /// No description provided for @writeKindTaskCreate.
  ///
  /// In pt, this message translates to:
  /// **'Criar tarefa “{title}”'**
  String writeKindTaskCreate(String title);

  /// No description provided for @writeKindTaskUpdate.
  ///
  /// In pt, this message translates to:
  /// **'Editar tarefa “{title}”'**
  String writeKindTaskUpdate(String title);

  /// No description provided for @writeKindTaskComplete.
  ///
  /// In pt, this message translates to:
  /// **'Concluir tarefa “{title}”'**
  String writeKindTaskComplete(String title);

  /// No description provided for @writeKindTaskReopen.
  ///
  /// In pt, this message translates to:
  /// **'Reabrir tarefa “{title}”'**
  String writeKindTaskReopen(String title);

  /// No description provided for @writeKindTaskDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir tarefa “{title}”'**
  String writeKindTaskDelete(String title);

  /// No description provided for @writeKindListCreate.
  ///
  /// In pt, this message translates to:
  /// **'Criar lista “{title}”'**
  String writeKindListCreate(String title);

  /// No description provided for @writeKindListRename.
  ///
  /// In pt, this message translates to:
  /// **'Renomear lista para “{title}”'**
  String writeKindListRename(String title);

  /// No description provided for @writeKindListDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir lista “{title}”'**
  String writeKindListDelete(String title);

  /// No description provided for @writeKindItemAdd.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar item “{title}”'**
  String writeKindItemAdd(String title);

  /// No description provided for @writeKindItemComplete.
  ///
  /// In pt, this message translates to:
  /// **'Marcar item “{title}”'**
  String writeKindItemComplete(String title);

  /// No description provided for @writeKindItemRename.
  ///
  /// In pt, this message translates to:
  /// **'Renomear item para “{title}”'**
  String writeKindItemRename(String title);

  /// No description provided for @writeKindItemDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir item “{title}”'**
  String writeKindItemDelete(String title);

  /// No description provided for @writeKindItemReorder.
  ///
  /// In pt, this message translates to:
  /// **'Reordenar itens'**
  String get writeKindItemReorder;

  /// No description provided for @taskFab.
  ///
  /// In pt, this message translates to:
  /// **'Nova tarefa'**
  String get taskFab;

  /// No description provided for @taskQuickAddTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nova tarefa'**
  String get taskQuickAddTitle;

  /// No description provided for @taskQuickAddHint.
  ///
  /// In pt, this message translates to:
  /// **'O que precisa ser feito?'**
  String get taskQuickAddHint;

  /// No description provided for @taskQuickAddSubmit.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar tarefa'**
  String get taskQuickAddSubmit;

  /// No description provided for @taskMoreOptions.
  ///
  /// In pt, this message translates to:
  /// **'Mais opções'**
  String get taskMoreOptions;

  /// No description provided for @taskLessOptions.
  ///
  /// In pt, this message translates to:
  /// **'Menos opções'**
  String get taskLessOptions;

  /// No description provided for @taskTitleLabel.
  ///
  /// In pt, this message translates to:
  /// **'Título'**
  String get taskTitleLabel;

  /// No description provided for @taskDescriptionLabel.
  ///
  /// In pt, this message translates to:
  /// **'Descrição (opcional)'**
  String get taskDescriptionLabel;

  /// No description provided for @taskDateLabel.
  ///
  /// In pt, this message translates to:
  /// **'Data e hora'**
  String get taskDateLabel;

  /// No description provided for @taskNoDate.
  ///
  /// In pt, this message translates to:
  /// **'Sem data'**
  String get taskNoDate;

  /// No description provided for @taskClearDate.
  ///
  /// In pt, this message translates to:
  /// **'Remover data'**
  String get taskClearDate;

  /// No description provided for @taskScheduleAt.
  ///
  /// In pt, this message translates to:
  /// **'{date} às {time}'**
  String taskScheduleAt(DateTime date, DateTime time);

  /// No description provided for @taskDetailDate.
  ///
  /// In pt, this message translates to:
  /// **'{date}'**
  String taskDetailDate(DateTime date);

  /// No description provided for @taskAssigneeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Responsável'**
  String get taskAssigneeLabel;

  /// No description provided for @taskAssigneeAnyone.
  ///
  /// In pt, this message translates to:
  /// **'Qualquer pessoa'**
  String get taskAssigneeAnyone;

  /// No description provided for @taskNotifyLabel.
  ///
  /// In pt, this message translates to:
  /// **'Avisar'**
  String get taskNotifyLabel;

  /// No description provided for @taskNotifyNeedsDate.
  ///
  /// In pt, this message translates to:
  /// **'Defina uma data para receber o aviso.'**
  String get taskNotifyNeedsDate;

  /// No description provided for @taskNotifyAtTime.
  ///
  /// In pt, this message translates to:
  /// **'Na hora'**
  String get taskNotifyAtTime;

  /// No description provided for @taskNotifyMinutesBefore.
  ///
  /// In pt, this message translates to:
  /// **'{minutes} min antes'**
  String taskNotifyMinutesBefore(int minutes);

  /// No description provided for @taskNotifyHourBefore.
  ///
  /// In pt, this message translates to:
  /// **'1 hora antes'**
  String get taskNotifyHourBefore;

  /// No description provided for @taskNotifyDayBefore.
  ///
  /// In pt, this message translates to:
  /// **'1 dia antes'**
  String get taskNotifyDayBefore;

  /// No description provided for @taskSectionUnscheduled.
  ///
  /// In pt, this message translates to:
  /// **'Sem data'**
  String get taskSectionUnscheduled;

  /// No description provided for @taskSectionDone.
  ///
  /// In pt, this message translates to:
  /// **'Concluídas recentes'**
  String get taskSectionDone;

  /// No description provided for @taskOverdue.
  ///
  /// In pt, this message translates to:
  /// **'Atrasada'**
  String get taskOverdue;

  /// No description provided for @taskFilterAll.
  ///
  /// In pt, this message translates to:
  /// **'Todas'**
  String get taskFilterAll;

  /// No description provided for @taskFilterMine.
  ///
  /// In pt, this message translates to:
  /// **'Minhas'**
  String get taskFilterMine;

  /// No description provided for @taskEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma tarefa por aqui'**
  String get taskEmptyTitle;

  /// No description provided for @taskEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Adicione a primeira tarefa da casa.'**
  String get taskEmptyMessage;

  /// No description provided for @taskEmptyMine.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma tarefa sua por enquanto.'**
  String get taskEmptyMine;

  /// No description provided for @taskPendingSync.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando sincronização'**
  String get taskPendingSync;

  /// No description provided for @taskMarkDone.
  ///
  /// In pt, this message translates to:
  /// **'Concluir {title}'**
  String taskMarkDone(String title);

  /// No description provided for @taskMarkPending.
  ///
  /// In pt, this message translates to:
  /// **'Reabrir {title}'**
  String taskMarkPending(String title);

  /// No description provided for @taskDetailTitle.
  ///
  /// In pt, this message translates to:
  /// **'Tarefa'**
  String get taskDetailTitle;

  /// No description provided for @taskNotFoundTitle.
  ///
  /// In pt, this message translates to:
  /// **'Tarefa não encontrada'**
  String get taskNotFoundTitle;

  /// No description provided for @taskNotFoundMessage.
  ///
  /// In pt, this message translates to:
  /// **'Ela pode ter sido excluída.'**
  String get taskNotFoundMessage;

  /// No description provided for @taskSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar alterações'**
  String get taskSave;

  /// No description provided for @taskSaved.
  ///
  /// In pt, this message translates to:
  /// **'Alterações salvas.'**
  String get taskSaved;

  /// No description provided for @taskComplete.
  ///
  /// In pt, this message translates to:
  /// **'Concluir tarefa'**
  String get taskComplete;

  /// No description provided for @taskReopen.
  ///
  /// In pt, this message translates to:
  /// **'Reabrir tarefa'**
  String get taskReopen;

  /// No description provided for @taskDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir tarefa'**
  String get taskDelete;

  /// No description provided for @taskDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir tarefa?'**
  String get taskDeleteTitle;

  /// No description provided for @taskDeleteMessage.
  ///
  /// In pt, this message translates to:
  /// **'A tarefa deixa de aparecer para todos da casa.'**
  String get taskDeleteMessage;

  /// No description provided for @taskDeleted.
  ///
  /// In pt, this message translates to:
  /// **'Tarefa excluída.'**
  String get taskDeleted;

  /// No description provided for @taskCreatedBy.
  ///
  /// In pt, this message translates to:
  /// **'Criada por {name}'**
  String taskCreatedBy(String name);

  /// No description provided for @taskCompletedBy.
  ///
  /// In pt, this message translates to:
  /// **'Concluída por {name}'**
  String taskCompletedBy(String name);

  /// No description provided for @taskReadOnly.
  ///
  /// In pt, this message translates to:
  /// **'Você pode ver esta tarefa, mas não editá-la.'**
  String get taskReadOnly;

  /// No description provided for @taskFrozenReadOnly.
  ///
  /// In pt, this message translates to:
  /// **'Família somente leitura: não é possível alterar tarefas.'**
  String get taskFrozenReadOnly;

  /// No description provided for @homeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Início'**
  String get homeTitle;

  /// No description provided for @deleteAccountEntry.
  ///
  /// In pt, this message translates to:
  /// **'Excluir conta'**
  String get deleteAccountEntry;

  /// No description provided for @deleteAccountEntrySubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Apagar sua conta e seus dados'**
  String get deleteAccountEntrySubtitle;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir conta'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountIntro.
  ///
  /// In pt, this message translates to:
  /// **'Excluir sua conta é definitivo e não pode ser desfeito.'**
  String get deleteAccountIntro;

  /// No description provided for @deleteAccountWhatDeletedTitle.
  ///
  /// In pt, this message translates to:
  /// **'O que será apagado'**
  String get deleteAccountWhatDeletedTitle;

  /// No description provided for @deleteAccountWhatDeletedAccount.
  ///
  /// In pt, this message translates to:
  /// **'Sua conta e seus dados pessoais (perfil, dispositivos e preferências).'**
  String get deleteAccountWhatDeletedAccount;

  /// No description provided for @deleteAccountWhatDeletedFamilies.
  ///
  /// In pt, this message translates to:
  /// **'As famílias que só você integra, com suas casas, tarefas, listas e histórico.'**
  String get deleteAccountWhatDeletedFamilies;

  /// No description provided for @deleteAccountWhatDeletedFamiliesNamed.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{A família \"{names}\", que só você integra, com suas casas, tarefas, listas e histórico.} other{As famílias que só você integra ({names}), com suas casas, tarefas, listas e histórico.}}'**
  String deleteAccountWhatDeletedFamiliesNamed(int count, String names);

  /// No description provided for @deleteAccountWhatStaysTitle.
  ///
  /// In pt, this message translates to:
  /// **'O que permanece'**
  String get deleteAccountWhatStaysTitle;

  /// No description provided for @deleteAccountWhatStays.
  ///
  /// In pt, this message translates to:
  /// **'O conteúdo de famílias de outras pessoas continua lá, mas sem o seu nome: você sai dessas famílias e suas ações no histórico ficam anônimas.'**
  String get deleteAccountWhatStays;

  /// No description provided for @deleteAccountWhatStaysNamed.
  ///
  /// In pt, this message translates to:
  /// **'Você sai de: {names}. O conteúdo dessas famílias continua, sem o seu nome.'**
  String deleteAccountWhatStaysNamed(String names);

  /// No description provided for @deleteAccountSubscriptionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Você tem uma assinatura ativa'**
  String get deleteAccountSubscriptionTitle;

  /// No description provided for @deleteAccountSubscriptionMessage.
  ///
  /// In pt, this message translates to:
  /// **'Excluir a conta não cancela a assinatura. Cancele a renovação na Google Play antes de continuar, para não ser cobrado de novo.'**
  String get deleteAccountSubscriptionMessage;

  /// No description provided for @deleteAccountManageSubscription.
  ///
  /// In pt, this message translates to:
  /// **'Gerenciar assinatura'**
  String get deleteAccountManageSubscription;

  /// No description provided for @deleteAccountManageSubscriptionHelpTitle.
  ///
  /// In pt, this message translates to:
  /// **'Como cancelar na Google Play'**
  String get deleteAccountManageSubscriptionHelpTitle;

  /// No description provided for @deleteAccountManageSubscriptionHelp.
  ///
  /// In pt, this message translates to:
  /// **'Abra a Google Play, toque na foto do seu perfil, em Pagamentos e assinaturas, depois em Assinaturas, escolha o Planly e toque em Cancelar assinatura.'**
  String get deleteAccountManageSubscriptionHelp;

  /// No description provided for @deleteAccountBlockedTitle.
  ///
  /// In pt, this message translates to:
  /// **'Não é possível excluir agora'**
  String get deleteAccountBlockedTitle;

  /// No description provided for @deleteAccountBlockedMessage.
  ///
  /// In pt, this message translates to:
  /// **'Você é o dono de uma família com outros participantes. Ainda não é possível transferir a família para outra pessoa: transfira ou remova os participantes antes de excluir a conta.'**
  String get deleteAccountBlockedMessage;

  /// No description provided for @deleteAccountBlockedFamilies.
  ///
  /// In pt, this message translates to:
  /// **'Famílias com participantes: {names}.'**
  String deleteAccountBlockedFamilies(String names);

  /// No description provided for @deleteAccountGoToMembers.
  ///
  /// In pt, this message translates to:
  /// **'Ir para Membros'**
  String get deleteAccountGoToMembers;

  /// No description provided for @deleteAccountOffline.
  ///
  /// In pt, this message translates to:
  /// **'Você está sem conexão. Para excluir a conta é preciso estar online.'**
  String get deleteAccountOffline;

  /// No description provided for @deleteAccountConfirmWord.
  ///
  /// In pt, this message translates to:
  /// **'EXCLUIR'**
  String get deleteAccountConfirmWord;

  /// No description provided for @deleteAccountConfirmLabel.
  ///
  /// In pt, this message translates to:
  /// **'Digite {word} para confirmar'**
  String deleteAccountConfirmLabel(String word);

  /// No description provided for @deleteAccountButton.
  ///
  /// In pt, this message translates to:
  /// **'Excluir minha conta'**
  String get deleteAccountButton;

  /// No description provided for @deleteAccountWorking.
  ///
  /// In pt, this message translates to:
  /// **'Excluindo sua conta…'**
  String get deleteAccountWorking;

  /// No description provided for @deleteAccountReauthTitle.
  ///
  /// In pt, this message translates to:
  /// **'Confirme que é você'**
  String get deleteAccountReauthTitle;

  /// No description provided for @deleteAccountReauthMessage.
  ///
  /// In pt, this message translates to:
  /// **'Por segurança, entre novamente com sua conta Google para concluir a exclusão.'**
  String get deleteAccountReauthMessage;

  /// No description provided for @deleteAccountReauthButton.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar com Google'**
  String get deleteAccountReauthButton;

  /// No description provided for @deleteAccountLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível verificar suas famílias. Tente de novo em instantes.'**
  String get deleteAccountLoadError;

  /// No description provided for @remindersSectionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Lembretes'**
  String get remindersSectionTitle;

  /// No description provided for @remindersSwitchTitle.
  ///
  /// In pt, this message translates to:
  /// **'Lembretes de tarefas'**
  String get remindersSwitchTitle;

  /// No description provided for @remindersSwitchSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Avisa neste aparelho antes do horário das suas tarefas'**
  String get remindersSwitchSubtitle;

  /// No description provided for @remindersPermissionGranted.
  ///
  /// In pt, this message translates to:
  /// **'Notificações permitidas'**
  String get remindersPermissionGranted;

  /// No description provided for @remindersPermissionDenied.
  ///
  /// In pt, this message translates to:
  /// **'Notificações bloqueadas'**
  String get remindersPermissionDenied;

  /// No description provided for @remindersPermissionDeniedHelp.
  ///
  /// In pt, this message translates to:
  /// **'Sem a permissão, os lembretes não aparecem. Você pode permitir nos ajustes do sistema.'**
  String get remindersPermissionDeniedHelp;

  /// No description provided for @remindersPermissionAllow.
  ///
  /// In pt, this message translates to:
  /// **'Permitir notificações'**
  String get remindersPermissionAllow;

  /// No description provided for @remindersPermissionOpenSettings.
  ///
  /// In pt, this message translates to:
  /// **'Abrir ajustes do sistema'**
  String get remindersPermissionOpenSettings;

  /// No description provided for @remindersPermissionExplainTitle.
  ///
  /// In pt, this message translates to:
  /// **'Permitir notificações?'**
  String get remindersPermissionExplainTitle;

  /// No description provided for @remindersPermissionExplainMessage.
  ///
  /// In pt, this message translates to:
  /// **'O Planly usa notificações só para lembrar das suas tarefas no horário combinado. O conteúdo aparece apenas neste aparelho.'**
  String get remindersPermissionExplainMessage;

  /// No description provided for @remindersPermissionNotNow.
  ///
  /// In pt, this message translates to:
  /// **'Agora não'**
  String get remindersPermissionNotNow;

  /// No description provided for @remindersPermissionContinue.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get remindersPermissionContinue;

  /// No description provided for @remindersPermissionStillDenied.
  ///
  /// In pt, this message translates to:
  /// **'As notificações continuam bloqueadas. Abra os ajustes do sistema para permitir.'**
  String get remindersPermissionStillDenied;

  /// No description provided for @channelRemindersName.
  ///
  /// In pt, this message translates to:
  /// **'Lembretes'**
  String get channelRemindersName;

  /// No description provided for @channelRemindersDescription.
  ///
  /// In pt, this message translates to:
  /// **'Avisos das suas tarefas com horário'**
  String get channelRemindersDescription;

  /// No description provided for @channelActivityName.
  ///
  /// In pt, this message translates to:
  /// **'Atividade da casa'**
  String get channelActivityName;

  /// No description provided for @channelActivityDescription.
  ///
  /// In pt, this message translates to:
  /// **'Novidades das tarefas e listas compartilhadas'**
  String get channelActivityDescription;

  /// No description provided for @channelAccountName.
  ///
  /// In pt, this message translates to:
  /// **'Conta e plano'**
  String get channelAccountName;

  /// No description provided for @channelAccountDescription.
  ///
  /// In pt, this message translates to:
  /// **'Avisos sobre sua conta, família e plano'**
  String get channelAccountDescription;

  /// No description provided for @reminderBodyToday.
  ///
  /// In pt, this message translates to:
  /// **'Hoje às {time}'**
  String reminderBodyToday(String time);

  /// No description provided for @reminderBodyTomorrow.
  ///
  /// In pt, this message translates to:
  /// **'Amanhã às {time}'**
  String reminderBodyTomorrow(String time);

  /// No description provided for @reminderBodyDate.
  ///
  /// In pt, this message translates to:
  /// **'{date} às {time}'**
  String reminderBodyDate(String date, String time);

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

  /// No description provided for @navLists.
  ///
  /// In pt, this message translates to:
  /// **'Listas'**
  String get navLists;

  /// No description provided for @listsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Listas'**
  String get listsTitle;

  /// No description provided for @listsEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma lista ainda'**
  String get listsEmptyTitle;

  /// No description provided for @listsEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Crie uma lista de compras, ou qualquer outra, para compartilhar com a casa.'**
  String get listsEmptyMessage;

  /// No description provided for @listsCreateAction.
  ///
  /// In pt, this message translates to:
  /// **'Nova lista'**
  String get listsCreateAction;

  /// No description provided for @listsCreateTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nova lista'**
  String get listsCreateTitle;

  /// No description provided for @listsNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome da lista'**
  String get listsNameLabel;

  /// No description provided for @listsTypeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get listsTypeLabel;

  /// No description provided for @listsTypeShopping.
  ///
  /// In pt, this message translates to:
  /// **'Compras'**
  String get listsTypeShopping;

  /// No description provided for @listsTypeGeneral.
  ///
  /// In pt, this message translates to:
  /// **'Geral'**
  String get listsTypeGeneral;

  /// No description provided for @listsRenameTitle.
  ///
  /// In pt, this message translates to:
  /// **'Renomear lista'**
  String get listsRenameTitle;

  /// No description provided for @listsDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir lista?'**
  String get listsDeleteTitle;

  /// No description provided for @listsDeleteMessage.
  ///
  /// In pt, this message translates to:
  /// **'A lista \"{name}\" será excluída para todas as pessoas da casa.'**
  String listsDeleteMessage(String name);

  /// No description provided for @listsPendingCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Nada pendente} =1{1 pendente} other{{count} pendentes}}'**
  String listsPendingCount(int count);

  /// No description provided for @listsMenuRename.
  ///
  /// In pt, this message translates to:
  /// **'Renomear'**
  String get listsMenuRename;

  /// No description provided for @listsMenuDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get listsMenuDelete;

  /// No description provided for @listsNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Esta lista não existe mais.'**
  String get listsNotFound;

  /// No description provided for @itemsEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Lista vazia'**
  String get itemsEmptyTitle;

  /// No description provided for @itemsEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Adicione o primeiro item no campo abaixo.'**
  String get itemsEmptyMessage;

  /// No description provided for @itemAddHint.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar item'**
  String get itemAddHint;

  /// No description provided for @itemAddAction.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar'**
  String get itemAddAction;

  /// No description provided for @itemEditTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar item'**
  String get itemEditTitle;

  /// No description provided for @itemNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome do item'**
  String get itemNameLabel;

  /// No description provided for @itemDeleteTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Excluir item'**
  String get itemDeleteTooltip;

  /// No description provided for @itemReorderTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Arrastar para reordenar'**
  String get itemReorderTooltip;

  /// No description provided for @itemPendingSync.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando sincronizar'**
  String get itemPendingSync;

  /// No description provided for @itemsDoneSection.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 concluído} other{{count} concluídos}}'**
  String itemsDoneSection(int count);

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

  /// No description provided for @dashboardListsOpen.
  ///
  /// In pt, this message translates to:
  /// **'Abrir suas listas'**
  String get dashboardListsOpen;

  /// No description provided for @navActivity.
  ///
  /// In pt, this message translates to:
  /// **'Atividade'**
  String get navActivity;

  /// No description provided for @activityTitle.
  ///
  /// In pt, this message translates to:
  /// **'Atividade'**
  String get activityTitle;

  /// No description provided for @activityEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nada por aqui ainda'**
  String get activityEmptyTitle;

  /// No description provided for @activityEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Quando alguém criar ou concluir tarefas e itens, o histórico aparece aqui.'**
  String get activityEmptyMessage;

  /// No description provided for @activityEmptyFilteredMessage.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma atividade desta pessoa no período.'**
  String get activityEmptyFilteredMessage;

  /// No description provided for @activityFilterAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get activityFilterAll;

  /// No description provided for @activityFilterLabel.
  ///
  /// In pt, this message translates to:
  /// **'Filtrar por pessoa'**
  String get activityFilterLabel;

  /// No description provided for @activityYou.
  ///
  /// In pt, this message translates to:
  /// **'Você'**
  String get activityYou;

  /// No description provided for @activitySomeone.
  ///
  /// In pt, this message translates to:
  /// **'Alguém'**
  String get activitySomeone;

  /// No description provided for @activityPersonFallback.
  ///
  /// In pt, this message translates to:
  /// **'Pessoa'**
  String get activityPersonFallback;

  /// No description provided for @activityDayToday.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get activityDayToday;

  /// No description provided for @activityDayYesterday.
  ///
  /// In pt, this message translates to:
  /// **'Ontem'**
  String get activityDayYesterday;

  /// No description provided for @activityDayDate.
  ///
  /// In pt, this message translates to:
  /// **'{date}'**
  String activityDayDate(DateTime date);

  /// No description provided for @activityTime.
  ///
  /// In pt, this message translates to:
  /// **'{time}'**
  String activityTime(DateTime time);

  /// No description provided for @activityLoadMore.
  ///
  /// In pt, this message translates to:
  /// **'Carregar mais'**
  String get activityLoadMore;

  /// No description provided for @activityLoadingMore.
  ///
  /// In pt, this message translates to:
  /// **'Carregando…'**
  String get activityLoadingMore;

  /// No description provided for @activityLoadMoreFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar mais. Tente de novo.'**
  String get activityLoadMoreFailed;

  /// No description provided for @activityFreeNote.
  ///
  /// In pt, this message translates to:
  /// **'No plano Grátis você vê só os últimos 7 dias. Assine um plano para ver todo o histórico.'**
  String get activityFreeNote;

  /// No description provided for @activityEventTaskCreated.
  ///
  /// In pt, this message translates to:
  /// **'{actor} criou a tarefa \"{title}\"'**
  String activityEventTaskCreated(String actor, String title);

  /// No description provided for @activityEventTaskAssigned.
  ///
  /// In pt, this message translates to:
  /// **'{actor} atribuiu a tarefa \"{title}\"'**
  String activityEventTaskAssigned(String actor, String title);

  /// No description provided for @activityEventTaskCompleted.
  ///
  /// In pt, this message translates to:
  /// **'{actor} concluiu \"{title}\"'**
  String activityEventTaskCompleted(String actor, String title);

  /// No description provided for @activityEventTaskReopened.
  ///
  /// In pt, this message translates to:
  /// **'{actor} reabriu \"{title}\"'**
  String activityEventTaskReopened(String actor, String title);

  /// No description provided for @activityEventTaskUpdated.
  ///
  /// In pt, this message translates to:
  /// **'{actor} editou a tarefa \"{title}\"'**
  String activityEventTaskUpdated(String actor, String title);

  /// No description provided for @activityEventTaskDeleted.
  ///
  /// In pt, this message translates to:
  /// **'{actor} excluiu a tarefa \"{title}\"'**
  String activityEventTaskDeleted(String actor, String title);

  /// No description provided for @activityEventListCreated.
  ///
  /// In pt, this message translates to:
  /// **'{actor} criou a lista \"{title}\"'**
  String activityEventListCreated(String actor, String title);

  /// No description provided for @activityEventListDeleted.
  ///
  /// In pt, this message translates to:
  /// **'{actor} excluiu a lista \"{title}\"'**
  String activityEventListDeleted(String actor, String title);

  /// No description provided for @activityEventItemAdded.
  ///
  /// In pt, this message translates to:
  /// **'{actor} adicionou \"{title}\" à lista'**
  String activityEventItemAdded(String actor, String title);

  /// No description provided for @activityEventItemCompleted.
  ///
  /// In pt, this message translates to:
  /// **'{actor} concluiu o item \"{title}\"'**
  String activityEventItemCompleted(String actor, String title);

  /// No description provided for @activityEventItemDeleted.
  ///
  /// In pt, this message translates to:
  /// **'{actor} removeu \"{title}\" da lista'**
  String activityEventItemDeleted(String actor, String title);

  /// No description provided for @activityEventMemberJoined.
  ///
  /// In pt, this message translates to:
  /// **'{actor} entrou na casa'**
  String activityEventMemberJoined(String actor);

  /// No description provided for @activityEventMemberLeft.
  ///
  /// In pt, this message translates to:
  /// **'{actor} saiu da casa'**
  String activityEventMemberLeft(String actor);

  /// No description provided for @activityEventHouseholdCreated.
  ///
  /// In pt, this message translates to:
  /// **'{actor} criou a casa \"{title}\"'**
  String activityEventHouseholdCreated(String actor, String title);

  /// No description provided for @activityEventUnknown.
  ///
  /// In pt, this message translates to:
  /// **'{actor} fez uma alteração'**
  String activityEventUnknown(String actor);

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

  /// No description provided for @errorInviteInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Código inválido ou expirado. Confira e tente de novo, ou peça um novo convite.'**
  String get errorInviteInvalid;

  /// No description provided for @errorJoinPlanLimit.
  ///
  /// In pt, this message translates to:
  /// **'Esta família atingiu o limite de pessoas. Fale com quem convidou.'**
  String get errorJoinPlanLimit;

  /// No description provided for @inviteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Convidar pessoa'**
  String get inviteTitle;

  /// No description provided for @inviteIntro.
  ///
  /// In pt, this message translates to:
  /// **'Escolha as casas e o papel da pessoa em cada uma. O código vale por 24 horas.'**
  String get inviteIntro;

  /// No description provided for @inviteHouseholdsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Casas'**
  String get inviteHouseholdsLabel;

  /// No description provided for @inviteNoHouseholds.
  ///
  /// In pt, this message translates to:
  /// **'Crie uma casa antes de convidar alguém.'**
  String get inviteNoHouseholds;

  /// No description provided for @inviteGenerate.
  ///
  /// In pt, this message translates to:
  /// **'Gerar convite'**
  String get inviteGenerate;

  /// No description provided for @inviteSelectAtLeastOne.
  ///
  /// In pt, this message translates to:
  /// **'Escolha pelo menos uma casa.'**
  String get inviteSelectAtLeastOne;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Código do convite'**
  String get inviteCodeLabel;

  /// No description provided for @inviteValidUntil.
  ///
  /// In pt, this message translates to:
  /// **'Válido por 24 horas (até {when}).'**
  String inviteValidUntil(String when);

  /// No description provided for @inviteCopy.
  ///
  /// In pt, this message translates to:
  /// **'Copiar código'**
  String get inviteCopy;

  /// No description provided for @inviteCopied.
  ///
  /// In pt, this message translates to:
  /// **'Código copiado.'**
  String get inviteCopied;

  /// No description provided for @inviteShare.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar'**
  String get inviteShare;

  /// No description provided for @inviteShareSubject.
  ///
  /// In pt, this message translates to:
  /// **'Convite do Planly'**
  String get inviteShareSubject;

  /// No description provided for @inviteShareMessage.
  ///
  /// In pt, this message translates to:
  /// **'Entre na minha família no Planly! Código de convite: {code} (vale por 24 horas). {link}'**
  String inviteShareMessage(String code, String link);

  /// No description provided for @inviteAnother.
  ///
  /// In pt, this message translates to:
  /// **'Novo convite'**
  String get inviteAnother;

  /// No description provided for @inviteSentList.
  ///
  /// In pt, this message translates to:
  /// **'Convites enviados'**
  String get inviteSentList;

  /// No description provided for @invitationsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum convite enviado'**
  String get invitationsEmpty;

  /// No description provided for @invitationsEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Os convites que você criar aparecem aqui.'**
  String get invitationsEmptyMessage;

  /// No description provided for @invitationStatusPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendente'**
  String get invitationStatusPending;

  /// No description provided for @invitationStatusAccepted.
  ///
  /// In pt, this message translates to:
  /// **'Aceito'**
  String get invitationStatusAccepted;

  /// No description provided for @invitationStatusExpired.
  ///
  /// In pt, this message translates to:
  /// **'Expirado'**
  String get invitationStatusExpired;

  /// No description provided for @invitationStatusRevoked.
  ///
  /// In pt, this message translates to:
  /// **'Revogado'**
  String get invitationStatusRevoked;

  /// No description provided for @invitationPendingSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Pendente · vale até {when}'**
  String invitationPendingSubtitle(String when);

  /// No description provided for @invitationDetailTitle.
  ///
  /// In pt, this message translates to:
  /// **'Convite pendente'**
  String get invitationDetailTitle;

  /// No description provided for @invitationRevoke.
  ///
  /// In pt, this message translates to:
  /// **'Revogar convite'**
  String get invitationRevoke;

  /// No description provided for @invitationRevokeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Revogar convite?'**
  String get invitationRevokeTitle;

  /// No description provided for @invitationRevokeMessage.
  ///
  /// In pt, this message translates to:
  /// **'Quem ainda não usou o código não poderá mais entrar na família com ele.'**
  String get invitationRevokeMessage;

  /// No description provided for @invitationRevoked.
  ///
  /// In pt, this message translates to:
  /// **'Convite revogado.'**
  String get invitationRevoked;

  /// No description provided for @invitationRoleIn.
  ///
  /// In pt, this message translates to:
  /// **'{household}: {role}'**
  String invitationRoleIn(String household, String role);

  /// No description provided for @joinHaveCode.
  ///
  /// In pt, this message translates to:
  /// **'Tenho um código de convite'**
  String get joinHaveCode;

  /// No description provided for @joinTitle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com código'**
  String get joinTitle;

  /// No description provided for @joinIntro.
  ///
  /// In pt, this message translates to:
  /// **'Digite o código que você recebeu para entrar numa família.'**
  String get joinIntro;

  /// No description provided for @joinCodeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Código do convite'**
  String get joinCodeLabel;

  /// No description provided for @joinButton.
  ///
  /// In pt, this message translates to:
  /// **'Entrar na família'**
  String get joinButton;

  /// No description provided for @joinSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Você entrou na família.'**
  String get joinSuccess;
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
