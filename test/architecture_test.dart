import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spec flutter-app §3: SDKs Firebase/Google só em `features/*/data/` e `core/firebase/`.
void main() {
  test('nenhum import de SDK de backend fora de data/ e core/firebase/', () {
    final forbidden = RegExp(
      r'''import\s+['"]package:(firebase_auth|cloud_firestore|cloud_functions|google_sign_in)/''',
    );
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      if (path.contains('/data/') || path.contains('lib/core/firebase/')) continue;
      if (forbidden.hasMatch(f.readAsStringSync())) offenders.add(path);
    }
    expect(offenders, isEmpty);
  });
}
