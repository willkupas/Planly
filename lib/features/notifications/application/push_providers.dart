import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/core/time/device_timezone.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/notifications/application/push_texts.dart';
import 'package:planly/features/notifications/data/firebase_push_gateway.dart';
import 'package:planly/features/notifications/data/firestore_device_repository.dart';
import 'package:planly/features/notifications/domain/device_repository.dart';
import 'package:planly/features/notifications/domain/push_event.dart';
import 'package:planly/features/notifications/domain/push_gateway.dart';
import 'package:planly/features/reminders/application/reminder_providers.dart';

const pushDeviceIdKey = 'push.deviceId';

/// Firebase Messaging (testes sobrescrevem com um fake).
final pushGatewayProvider = Provider<PushGateway>((ref) => FirebasePushGateway());

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => FirestoreDeviceRepository(firestore: ref.watch(firestoreProvider)),
);

final pushTextsProvider = Provider<PushTexts>((ref) => L10nPushTexts());

/// Id de instalação (gerado uma vez, só neste aparelho): é o `deviceId` do doc em `devices`.
final deviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final existing = prefs.getString(pushDeviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final rnd = Random.secure();
  final id = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  unawaited(prefs.setString(pushDeviceIdKey, id));
  return id;
});

/// Mantém `users/{uid}/devices/{deviceId}` com o token FCM atual enquanto há sessão: registra
/// no login e a cada `onTokenRefresh`. Falhas (offline, Rules) são silenciosas e tentadas de
/// novo no próximo login/refresh; nunca bloqueiam a UI. Nada do token é logado.
final pushSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  final gateway = ref.watch(pushGatewayProvider);
  final devices = ref.watch(deviceRepositoryProvider);
  final deviceId = ref.watch(deviceIdProvider);
  final readTimezone = ref.read(deviceTimezoneProvider);

  Future<void> register(String token) async {
    try {
      final tz = await readTimezone();
      final tag = PlatformDispatcher.instance.locale.toLanguageTag();
      await devices.register(
        uid: uid,
        deviceId: deviceId,
        fcmToken: token,
        locale: tag.length <= 10 ? tag : null,
        timezone: tz,
      );
    } catch (e) {
      debugPrint('Push: falha ao registrar o aparelho');
    }
  }

  StreamSubscription<String>? refreshSub;
  try {
    refreshSub = gateway.tokenRefreshes.listen(register, onError: (Object e) {
      debugPrint('Push: erro no refresh de token');
    });
    unawaited(() async {
      final token = await gateway.token();
      if (token != null && token.isNotEmpty) await register(token);
    }().catchError((Object e) {
      debugPrint('Push: token indisponível');
    }));
  } catch (e) {
    debugPrint('Push: Firebase Messaging indisponível');
  }
  ref.onDispose(() => refreshSub?.cancel());
});

/// Remove o registro deste aparelho (logout): apaga o doc em `devices` (com limite de tempo,
/// pois offline a escrita ficaria pendente) e invalida o token FCM. Melhor-esforço.
Future<void> unregisterDevice(Ref ref, {required String? uid, bool removeDoc = true}) async {
  if (uid != null && removeDoc) {
    try {
      await ref
          .read(deviceRepositoryProvider)
          .remove(uid: uid, deviceId: ref.read(deviceIdProvider))
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Push: não foi possível remover o aparelho agora');
    }
  }
  try {
    await ref.read(pushGatewayProvider).deleteToken();
  } catch (e) {
    debugPrint('Push: não foi possível invalidar o token');
  }
}

/// Mensagens recebidas com o app aberto viram notificação local (o FCM não mostra mensagens
/// só de dados em primeiro plano). Em segundo plano/encerrado, o handler de `bootstrap` cuida.
final pushForegroundProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  final gateway = ref.watch(pushGatewayProvider);
  final local = ref.watch(notificationGatewayProvider);
  final texts = ref.watch(pushTextsProvider);
  final channels = ref.watch(reminderTextsProvider).channels;

  StreamSubscription<Map<String, dynamic>>? sub;
  try {
    sub = gateway.foregroundMessages.listen((data) async {
      final event = PushEvent.fromData(data);
      if (event == null) return;
      try {
        await local.init(channels);
        await showPushEvent(local, texts, event);
      } catch (e) {
        debugPrint('Push: falha ao mostrar a notificação');
      }
    });
  } catch (e) {
    debugPrint('Push: Firebase Messaging indisponível');
  }
  ref.onDispose(() => sub?.cancel());
});

/// Toque numa notificação de atividade aguardando navegação (consumido por
/// `pushNavigationProvider`, que espera a sessão ficar pronta).
class PushOpenRequestNotifier extends Notifier<PushEvent?> {
  @override
  PushEvent? build() => null;

  void request(PushEvent event) => state = event;

  void clear() => state = null;
}

final pushOpenRequestProvider =
    NotifierProvider<PushOpenRequestNotifier, PushEvent?>(PushOpenRequestNotifier.new);

/// Liga os toques (notificação local, mensagem aberta e cold start) ao [pushOpenRequestProvider].
final pushTapProvider = Provider<void>((ref) {
  final local = ref.watch(notificationGatewayProvider);
  final push = ref.watch(pushGatewayProvider);
  final channels = ref.watch(reminderTextsProvider).channels;
  final notifier = ref.read(pushOpenRequestProvider.notifier);

  void fromPayload(String? raw) {
    final e = PushEvent.parse(raw);
    if (e != null) notifier.request(e);
  }

  void fromData(Map<String, dynamic>? data) {
    final e = data == null ? null : PushEvent.fromData(data);
    if (e != null) notifier.request(e);
  }

  final subs = <StreamSubscription<Object?>>[];
  subs.add(local.taps.listen(fromPayload));
  try {
    subs.add(push.openedMessages.listen(fromData));
  } catch (e) {
    debugPrint('Push: Firebase Messaging indisponível');
  }
  unawaited(() async {
    try {
      await local.init(channels);
      fromPayload(await local.launchPayload());
      fromData(await push.initialMessage());
    } catch (e) {
      debugPrint('Push: falha ao ler abertura por notificação');
    }
  }());
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });
});
