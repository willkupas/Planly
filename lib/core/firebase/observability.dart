import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:planly/app/flavor.dart';

/// Coleta de crashes e analytics só em builds de release de staging/prod.
/// Em debug e no flavor dev fica desligada (não polui o painel nem envia dados de teste).
bool _collectTelemetry(Flavor flavor) => !kDebugMode && flavor != Flavor.dev;

/// App Check: Play Integrity em release; provedor de debug em builds debug (o token de debug
/// aparece no logcat e deve ser cadastrado no console Firebase antes de ativar o enforcement).
/// Os emuladores ignoram App Check.
///
/// APK instalado na mão (fora da Play) não passa no Play Integrity. Para testar no próprio
/// aparelho, builds de dev/staging aceitam `--dart-define=APP_CHECK_DEBUG=true` (cada aparelho
/// gera seu token de debug, cadastrado no console). Nunca vale para o flavor prod.
Future<void> initAppCheck(Flavor flavor) {
  const forceDebug = bool.fromEnvironment('APP_CHECK_DEBUG');
  final useDebug = kDebugMode || (forceDebug && flavor != Flavor.prod);
  return FirebaseAppCheck.instance.activate(
    providerAndroid: useDebug
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );
}

/// Liga Crashlytics aos erros do Flutter e da plataforma. Nunca registrar dados pessoais
/// (e-mail, tokens, conteúdo de tarefas) em logs ou chaves customizadas.
Future<void> initCrashReporting(Flavor flavor) async {
  final enabled = _collectTelemetry(flavor);
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
  if (!enabled) return;

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

/// Analytics sem PII: nenhum e-mail/nome em propriedades ou parâmetros de evento.
Future<void> initAnalytics(Flavor flavor) {
  return FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(_collectTelemetry(flavor));
}
