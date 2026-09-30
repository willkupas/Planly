import 'dart:async';

import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/auth/domain/account_repository.dart';

/// `deleteAccount` em memória: falhas em ordem (uma por chamada) e, opcionalmente, um gate.
class FakeAccountRepository implements AccountRepository {
  final failures = <AppFailure>[];
  Completer<void>? gate;
  int deleteCalls = 0;

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    await gate?.future;
    if (failures.isNotEmpty) throw failures.removeAt(0);
  }
}
