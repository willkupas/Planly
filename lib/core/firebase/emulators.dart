import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Host dos emuladores vistos do app. `10.0.2.2` é o PC hospedeiro a partir do emulador Android.
/// Em celular físico use `adb reverse` (127.0.0.1) ou o IP do PC:
///   flutter run --flavor dev -t lib/main_dev.dart --dart-define=EMULATOR_HOST=192.168.0.10
const _emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

/// Portas definidas em firebase.json.
const _authPort = 9099;
const _firestorePort = 8080;
const _functionsPort = 5001;

/// Aponta Auth, Firestore e Functions para o Emulator Suite. Só o flavor dev chama isto,
/// e deve rodar antes de qualquer uso desses serviços.
Future<void> connectToFirebaseEmulators() async {
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestorePort);
  FirebaseFunctions.instanceFor(region: 'southamerica-east1')
      .useFunctionsEmulator(_emulatorHost, _functionsPort);
}
