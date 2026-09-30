import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:planly/core/error/app_failure.dart';

/// Converte exceções de Firestore/Functions em `AppFailure`. Nunca repassa mensagens do SDK.
AppFailure mapFirebaseError(Object error) {
  if (error is AppFailure) return error;
  if (error is FirebaseFunctionsException) return _mapFunctions(error);
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => const PermissionDeniedFailure(),
      'unavailable' || 'network-request-failed' => const NetworkFailure(),
      'unauthenticated' => const AccountFailure(),
      _ => const UnknownFailure(),
    };
  }
  return const UnknownFailure();
}

AppFailure _mapFunctions(FirebaseFunctionsException e) {
  final reason = _reasonOf(e);
  if (reason != null) return BusinessFailure(reason);
  return switch (e.code) {
    'unavailable' || 'deadline-exceeded' || 'cancelled' => const NetworkFailure(),
    'unauthenticated' => const AccountFailure(),
    'permission-denied' => const PermissionDeniedFailure(),
    'resource-exhausted' => const BusinessFailure('RATE_LIMITED'),
    _ => const UnknownFailure(),
  };
}

/// O servidor envia `details: {reason}` (HttpsError). `invalid-argument` usa o nome do
/// campo como reason, mas isso é erro de programação, não de negócio: vira `UnknownFailure`.
String? _reasonOf(FirebaseFunctionsException e) {
  if (e.code == 'invalid-argument') return null;
  final details = e.details;
  if (details is Map) {
    final r = details['reason'];
    if (r is String && r.isNotEmpty) return r;
  }
  return null;
}
