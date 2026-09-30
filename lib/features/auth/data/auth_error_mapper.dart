import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:planly/core/error/app_failure.dart';

/// Converte exceções de SDK em `AppFailure` (sem vazar mensagens técnicas para a UI).
AppFailure mapAuthError(Object error) {
  if (error is AppFailure) return error;
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted =>
        const CancelledFailure(),
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        const ConfigurationFailure(),
      GoogleSignInExceptionCode.uiUnavailable ||
      GoogleSignInExceptionCode.userMismatch ||
      GoogleSignInExceptionCode.unknownError =>
        const UnknownFailure(),
    };
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'network-request-failed' || 'too-many-requests' => const NetworkFailure(),
      'requires-recent-login' => const RequiresRecentLoginFailure(),
      'user-disabled' ||
      'invalid-credential' ||
      'account-exists-with-different-credential' ||
      'user-not-found' ||
      'user-mismatch' ||
      'user-token-expired' =>
        const AccountFailure(),
      'operation-not-allowed' || 'app-not-authorized' => const ConfigurationFailure(),
      _ => const UnknownFailure(),
    };
  }
  return const UnknownFailure();
}
