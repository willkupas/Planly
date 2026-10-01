import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:planly/features/notifications/domain/push_gateway.dart';

/// Implementação com `firebase_messaging` (Android).
class FirebasePushGateway implements PushGateway {
  FirebaseMessaging get _m => FirebaseMessaging.instance;

  @override
  Future<String?> token() => _m.getToken();

  @override
  Stream<String> get tokenRefreshes => _m.onTokenRefresh;

  @override
  Stream<Map<String, dynamic>> get foregroundMessages => FirebaseMessaging.onMessage.map((m) => m.data);

  @override
  Stream<Map<String, dynamic>> get openedMessages => FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  @override
  Future<Map<String, dynamic>?> initialMessage() async => (await _m.getInitialMessage())?.data;

  @override
  Future<void> deleteToken() => _m.deleteToken();
}
