import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';

void main() {
  test('reason REQUIRES_RECENT_LOGIN do servidor vira RequiresRecentLoginFailure', () {
    final e = FirebaseFunctionsException(
      message: 'x',
      code: 'unauthenticated',
      details: {'reason': 'REQUIRES_RECENT_LOGIN'},
    );
    expect(mapFirebaseError(e), isA<RequiresRecentLoginFailure>());
  });

  test('OWNER_HAS_MEMBERS continua BusinessFailure', () {
    final e = FirebaseFunctionsException(
      message: 'x',
      code: 'failed-precondition',
      details: {'reason': 'OWNER_HAS_MEMBERS'},
    );
    expect(mapFirebaseError(e), const BusinessFailure('OWNER_HAS_MEMBERS'));
  });
}
