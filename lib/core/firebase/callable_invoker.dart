import 'package:cloud_functions/cloud_functions.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';

/// Chama uma callable e devolve o mapa de dados (o envelope `{ok: true, ...}` do servidor).
/// Lança `AppFailure` (nunca exceção de SDK). Injetável para testar repositories sem
/// plataforma.
typedef CallableInvoker = Future<Map<String, dynamic>> Function(String name, Map<String, Object?> data);

CallableInvoker firebaseCallableInvoker(FirebaseFunctions functions) {
  return (name, data) async {
    try {
      final result = await functions.httpsCallable(name).call<Object?>(data);
      final out = result.data;
      return out is Map ? Map<String, dynamic>.from(out) : <String, dynamic>{};
    } catch (e) {
      throw mapFirebaseError(e);
    }
  };
}
