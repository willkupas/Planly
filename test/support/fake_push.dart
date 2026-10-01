import 'dart:async';

import 'package:planly/features/notifications/domain/device_repository.dart';
import 'package:planly/features/notifications/domain/push_gateway.dart';

/// Firebase Messaging em memória.
class FakePushGateway implements PushGateway {
  String? currentToken = 'tok-1';
  var deleteTokenCalls = 0;
  Map<String, dynamic>? initial;

  final _refresh = StreamController<String>.broadcast();
  final _foreground = StreamController<Map<String, dynamic>>.broadcast();
  final _opened = StreamController<Map<String, dynamic>>.broadcast();

  void refreshToken(String t) {
    currentToken = t;
    _refresh.add(t);
  }

  void receive(Map<String, dynamic> data) => _foreground.add(data);

  void open(Map<String, dynamic> data) => _opened.add(data);

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get tokenRefreshes => _refresh.stream;

  @override
  Stream<Map<String, dynamic>> get foregroundMessages => _foreground.stream;

  @override
  Stream<Map<String, dynamic>> get openedMessages => _opened.stream;

  @override
  Future<Map<String, dynamic>?> initialMessage() async => initial;

  @override
  Future<void> deleteToken() async => deleteTokenCalls++;
}

/// Repositório de devices em memória: `uid/deviceId -> fcmToken`.
class FakeDeviceRepository implements DeviceRepository {
  final devices = <String, String>{};
  final registerCalls = <String>[];
  var removeCalls = 0;

  @override
  Future<void> register({
    required String uid,
    required String deviceId,
    required String fcmToken,
    String? locale,
    String? timezone,
  }) async {
    registerCalls.add(fcmToken);
    devices['$uid/$deviceId'] = fcmToken;
  }

  @override
  Future<void> remove({required String uid, required String deviceId}) async {
    removeCalls++;
    devices.remove('$uid/$deviceId');
  }
}
