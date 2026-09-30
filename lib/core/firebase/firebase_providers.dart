import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/firebase/callable_invoker.dart';
import 'package:planly/core/firebase/firestore_local_data_service.dart';
import 'package:planly/core/sync/local_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Região das Functions (imutável, igual ao Firestore; ver CLAUDE.md).
const functionsRegion = 'southamerica-east1';

/// Únicos pontos (com `features/*/data/`) que tocam os SDKs Firebase.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final functionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instanceFor(region: functionsRegion),
);

final callableInvokerProvider = Provider<CallableInvoker>(
  (ref) => firebaseCallableInvoker(ref.watch(functionsProvider)),
);

/// SharedPreferences carregado em `bootstrap()` e injetado via override (nos testes também).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider precisa de override'),
);

final localDataServiceProvider = Provider<LocalDataService>((ref) {
  return FirestoreLocalDataService(
    firestore: ref.watch(firestoreProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});
