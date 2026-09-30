import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/app/reminder_navigation.dart';
import 'package:planly/app/router/app_router.dart';
import 'package:planly/features/reminders/application/reminder_providers.dart';
import 'package:planly/core/theme/app_theme.dart';
import 'package:planly/l10n/app_localizations.dart';

class PlanlyApp extends ConsumerWidget {
  const PlanlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lembretes (T-022): reconciliação das notificações locais e abertura por toque.
    ref.watch(reminderSyncProvider);
    ref.watch(reminderNavigationProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // pt-BR é o idioma inicial; outros idiomas entram adicionando ARBs.
      locale: const Locale('pt'),
    );
  }
}
