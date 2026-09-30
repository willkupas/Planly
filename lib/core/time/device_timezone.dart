import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Timezone IANA do aparelho (ex.: `America/Sao_Paulo`) ou `null` se indisponível.
typedef DeviceTimezoneReader = Future<String?> Function();

Future<String?> _readDeviceTimezone() async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    final id = info.identifier;
    return id.isEmpty ? null : id;
  } catch (e) {
    debugPrint('Timezone do aparelho indisponível');
    return null;
  }
}

final deviceTimezoneProvider = Provider<DeviceTimezoneReader>((ref) => _readDeviceTimezone);
