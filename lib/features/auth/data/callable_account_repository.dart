import 'package:planly/core/firebase/callable_invoker.dart';
import 'package:planly/features/auth/domain/account_repository.dart';

class CallableAccountRepository implements AccountRepository {
  CallableAccountRepository({required CallableInvoker callable}) : _call = callable;

  final CallableInvoker _call;

  @override
  Future<void> deleteAccount() async {
    await _call('deleteAccount', const {});
  }
}
